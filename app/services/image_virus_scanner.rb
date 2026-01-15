require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class ImageVirusScanner
  class ScanFailedError < StandardError; end
  class VirusDetectedError < StandardError; end

  CLOUDMERSIVE_HOST = 'api.cloudmersive.com'
  CLOUDMERSIVE_ENDPOINT = '/virus/scan/file'

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    Rails.logger.info("[VIRUS_SCAN] Starting virus scan for file: #{@file_path}")
    ApplicationLogger.log_info(
      "Virus scan initiated",
      category: "security",
      data: {
        file_path: @file_path,
        file_size: File.exist?(@file_path) ? File.size(@file_path) : "N/A",
        environment: Rails.env
      }
    )

    # Skip virus scanning in development unless explicitly enabled
    unless Rails.env.production? || ENV['ENABLE_VIRUS_SCAN'] == 'true'
      Rails.logger.info("[VIRUS_SCAN] Skipping virus scan in #{Rails.env} environment")
      ApplicationLogger.log_info(
        "Virus scan skipped - development mode",
        category: "security",
        data: { environment: Rails.env, enable_scan: ENV['ENABLE_VIRUS_SCAN'] }
      )
      return true
    end

    # Verify API key is configured
    unless ENV['CLOUDMERSIVE_API_KEY'].present?
      error_msg = "CLOUDMERSIVE_API_KEY not configured"
      Rails.logger.error("[VIRUS_SCAN] #{error_msg}")
      ApplicationLogger.log_error(
        StandardError.new(error_msg),
        context: { component: "virus_scan", error_type: "configuration_error" }
      )
      Sentry.capture_message("Cloudmersive API key not configured")
      raise ScanFailedError, "Virus scanning service not configured"
    end

    Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
      category: "virus_scan",
      message: "Starting Cloudmersive virus scan",
      data: { file_path: @file_path, file_exists: File.exist?(@file_path) }
    ))

    begin
      Rails.logger.info("[VIRUS_SCAN] Scanning file: #{@file_path} (#{File.size(@file_path)} bytes)")

      # Make HTTP request to Cloudmersive API
      result = make_api_request

      Rails.logger.info("[VIRUS_SCAN] Scan result: CleanResult=#{result['CleanResult']}, VirusesFound=#{result['FoundViruses']&.count || 0}")
      
      ApplicationLogger.log_info(
        "Virus scan completed",
        category: "security",
        data: {
          file_path: @file_path,
          clean_result: result['CleanResult'],
          viruses_found: result['FoundViruses']&.count || 0,
          scan_duration_ms: (Time.current.to_f * 1000).to_i - (@scan_start_time || Time.current.to_f * 1000).to_i
        }
      )

      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
        category: "virus_scan",
        message: "Cloudmersive scan completed",
        data: {
          clean_result: result['CleanResult'],
          viruses_found: result['FoundViruses']&.count || 0
        }
      ))

      # Check if file is clean
      if result['CleanResult'] == true
        Rails.logger.info("[VIRUS_SCAN] File is clean")
        true
      else
        # Virus detected
        virus_names = result['FoundViruses']&.map { |v| v['VirusName'] }&.join(", ") || "Unknown"
        error_msg = "Virus detected: #{virus_names}"

        Rails.logger.warn("[VIRUS_SCAN] #{error_msg}")

        Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
          category: "virus_scan",
          message: "Virus detected",
          level: "warning",
          data: { virus_names: virus_names }
        ))

        raise VirusDetectedError, error_msg
      end

    rescue VirusDetectedError
      raise # Re-raise virus detection errors
    rescue StandardError => e
      Rails.logger.error("[VIRUS_SCAN] Unexpected error: #{e.message}")
      Rails.logger.error("[VIRUS_SCAN] Backtrace: #{e.backtrace.first(5).join("\n")}")

      Sentry.capture_exception(e) do |scope|
        scope.set_tags(
          component: "virus_scanner",
          error_type: "scan_error"
        )
        scope.set_context("scan_details", {
          file_path: @file_path,
          file_exists: File.exist?(@file_path),
          file_size: File.exist?(@file_path) ? File.size(@file_path) : nil
        })
      end

      raise ScanFailedError, "Virus scan failed: #{e.message}"
    end
  end

  private

  def make_api_request
    @scan_start_time = (Time.current.to_f * 1000).to_i
    uri = URI.parse("https://#{CLOUDMERSIVE_HOST}#{CLOUDMERSIVE_ENDPOINT}")

    Rails.logger.info("[VIRUS_SCAN] Calling API: POST #{uri}")
    ApplicationLogger.log_info(
      "Cloudmersive API request started",
      category: "security",
      data: {
        api_endpoint: uri.to_s,
        file_size: File.size(@file_path),
        filename: File.basename(@file_path)
      }
    )

    # Create multipart form data
    boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
    file_content = File.binread(@file_path)
    filename = File.basename(@file_path)

    body = []
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"inputFile\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: application/octet-stream\r\n\r\n"
    body << file_content
    body << "\r\n--#{boundary}--\r\n"
    body = body.join

    # Make HTTP request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request['Apikey'] = ENV['CLOUDMERSIVE_API_KEY']
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = body

    response = http.request(request)
    
    duration_ms = (Time.current.to_f * 1000).to_i - @scan_start_time
    Rails.logger.info("[VIRUS_SCAN] API Response: #{response.code} #{response.message} (#{duration_ms}ms)")
    
    ApplicationLogger.log_info(
      "Cloudmersive API response received",
      category: "security",
      data: {
        status_code: response.code,
        duration_ms: duration_ms,
        response_length: response.body&.length || 0
      }
    )

    unless response.is_a?(Net::HTTPSuccess)
      error_msg = "API returned #{response.code}: #{response.body}"
      ApplicationLogger.log_error(
        StandardError.new(error_msg),
        context: {
          component: "virus_scan",
          error_type: "api_error", 
          status_code: response.code,
          response_body: response.body[0..500]
        }
      )
      raise error_msg
    end

    begin
      result = JSON.parse(response.body)
      ApplicationLogger.log_info(
        "API response parsed successfully",
        category: "security",
        data: { clean_result: result['CleanResult'] }
      )
      result
    rescue JSON::ParserError => e
      ApplicationLogger.log_error(
        e,
        context: {
          component: "virus_scan",
          error_type: "json_parse_error",
          response_body: response.body[0..500]
        }
      )
      raise e
    end
  end
end
