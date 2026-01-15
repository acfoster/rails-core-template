class TemporaryImageStorage
  class InvalidImageError < StandardError; end

  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif].freeze
  MAX_FILE_SIZE = 10.megabytes
  # Use /tmp for Docker compatibility (already configured in Dockerfile)
  TEMP_DIR = Pathname.new(ENV.fetch("TMPDIR", "/tmp")).join("uploaded_images")
  TTL_MINUTES = 30

  def initialize(uploaded_file)
    @uploaded_file = uploaded_file
    @temp_file_path = nil
  end

  def store
    Rails.logger.info("[IMAGE_STORAGE] Starting image storage process")
    ApplicationLogger.log_info(
      "Image storage initiated",
      category: "file_upload",
      data: {
        content_type: @uploaded_file.content_type,
        size: @uploaded_file.size,
        original_filename: @uploaded_file.original_filename
      }
    )
    
    validate_file!
    create_temp_directory

    Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
      category: "image_storage",
      message: "Creating temp directory",
      data: {
        temp_dir: TEMP_DIR.to_s,
        temp_dir_exists: TEMP_DIR.exist?,
        tmpdir_env: ENV["TMPDIR"]
      }
    ))

    # Generate unique filename with timestamp for TTL tracking
    timestamp = Time.current.to_i
    filename = "#{timestamp}_#{SecureRandom.hex(8)}#{File.extname(@uploaded_file.original_filename)}"
    @temp_file_path = TEMP_DIR.join(filename)

    # Copy uploaded file to temporary storage
    File.open(@temp_file_path, "wb") do |file|
      file.write(@uploaded_file.read)
    end

    log_event("image_uploaded", "Stored temporarily at #{@temp_file_path}")

    Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
      category: "image_storage",
      message: "Image stored successfully",
      data: {
        path: @temp_file_path.to_s,
        size: @uploaded_file.size,
        file_exists: File.exist?(@temp_file_path)
      }
    ))

    {
      path: @temp_file_path.to_s,
      content_type: @uploaded_file.content_type,
      original_filename: @uploaded_file.original_filename,
      size: @uploaded_file.size
    }
  rescue StandardError => e
    cleanup! if @temp_file_path && File.exist?(@temp_file_path)

    Sentry.capture_exception(e) do |scope|
      scope.set_tags(component: "image_storage", error_type: "storage_failed")
      scope.set_context("storage", {
        temp_dir: TEMP_DIR.to_s,
        temp_dir_exists: TEMP_DIR.exist?,
        temp_file_path: @temp_file_path&.to_s,
        tmpdir_env: ENV["TMPDIR"],
        file_content_type: @uploaded_file&.content_type,
        file_size: @uploaded_file&.size
      })
    end

    raise InvalidImageError, "Failed to store image: #{e.message}"
  end

  def self.cleanup_expired!
    Rails.logger.info("[IMAGE_STORAGE] Starting cleanup of expired files")
    ApplicationLogger.log_info(
      "Image cleanup started",
      category: "maintenance",
      data: { temp_dir: TEMP_DIR.to_s, ttl_minutes: TTL_MINUTES }
    )
    
    return unless TEMP_DIR.exist?

    cutoff_time = TTL_MINUTES.minutes.ago.to_i
    deleted_count = 0

    Dir.glob(TEMP_DIR.join("*")).each do |file_path|
      filename = File.basename(file_path)

      # Extract timestamp from filename (format: timestamp_hexhash.ext)
      timestamp_match = filename.match(/^(\d+)_/)
      next unless timestamp_match

      file_timestamp = timestamp_match[1].to_i

      if file_timestamp < cutoff_time
        File.delete(file_path)
        deleted_count += 1
        Rails.logger.info("[IMAGE_CLEANUP] Deleted expired temp file: #{file_path}")
      end
    rescue StandardError => e
      Rails.logger.error("[IMAGE_CLEANUP] Failed to delete #{file_path}: #{e.message}")
    end

    Rails.logger.info("[IMAGE_CLEANUP] Cleanup complete - deleted #{deleted_count} expired files")
    deleted_count
  end

  def cleanup!
    return unless @temp_file_path && File.exist?(@temp_file_path)

    File.delete(@temp_file_path)
    log_event("image_deleted", "Cleaned up temp file")
    true
  rescue StandardError => e
    Rails.logger.error("[IMAGE_STORAGE] Failed to cleanup #{@temp_file_path}: #{e.message}")
    false
  end

  private

  def validate_file!
    raise InvalidImageError, "No file provided" if @uploaded_file.nil?

    # Validate content type
    unless ALLOWED_CONTENT_TYPES.include?(@uploaded_file.content_type)
      raise InvalidImageError, "Invalid file type. Allowed: JPG, PNG, GIF"
    end

    # Validate file size
    if @uploaded_file.size > MAX_FILE_SIZE
      raise InvalidImageError, "File size exceeds #{MAX_FILE_SIZE / 1.megabyte}MB limit"
    end

    # Basic file validation
    if @uploaded_file.size.zero?
      raise InvalidImageError, "Uploaded file is empty"
    end
  end

  def create_temp_directory
    FileUtils.mkdir_p(TEMP_DIR) unless TEMP_DIR.exist?
  end

  def log_event(event, message)
    Rails.logger.info("[IMAGE_STORAGE] #{event}: #{message}")
  end
end
