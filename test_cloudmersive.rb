#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudmersive-virus-scan-api-client'
require 'cgi'

# Ruby 3.0+ compatibility fix
unless URI.respond_to?(:encode)
  module URI
    def self.encode(str)
      CGI.escape(str)
    end
  end
end

# Configure
CloudmersiveVirusScanApiClient.configure do |config|
  config.api_key['Apikey'] = 'c6896c4d-40a3-4c26-8c8b-c153c65cbbce'
  config.host = 'api.cloudmersive.com'
  config.scheme = 'https'
  config.debugging = true
end

puts "Configuration:"
puts "  Host: #{CloudmersiveVirusScanApiClient.configure.host}"
puts "  Scheme: #{CloudmersiveVirusScanApiClient.configure.scheme}"
puts "  Base URL: #{CloudmersiveVirusScanApiClient.configure.base_url}"

# Create a test file
test_file_path = '/tmp/test_scan.txt'
File.write(test_file_path, "This is a test file for virus scanning.\n")

puts "\nTest file created: #{test_file_path}"
puts "File size: #{File.size(test_file_path)} bytes"

# Test the API
begin
  api_instance = CloudmersiveVirusScanApiClient::ScanApi.new
  input_file = File.open(test_file_path, 'rb')

  puts "\nCalling Cloudmersive API..."
  result = api_instance.scan_file(input_file)

  input_file.close

  puts "\nResult:"
  puts "  Clean: #{result.clean_result}"
  puts "  Viruses Found: #{result.found_viruses&.count || 0}"

  if result.clean_result
    puts "\n✅ SUCCESS: File is clean!"
  else
    puts "\n❌ VIRUS DETECTED: #{result.found_viruses&.map(&:virus_name)&.join(', ')}"
  end

rescue => e
  puts "\n❌ ERROR: #{e.class}: #{e.message}"
  puts "\nBacktrace:"
  puts e.backtrace.first(10).join("\n")
end

# Cleanup
File.delete(test_file_path) if File.exist?(test_file_path)
