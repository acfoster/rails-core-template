class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer
  
  # Retry on connection errors with backoff
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :exponentially_longer, attempts: 3
  
  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError do |job, error|
    ApplicationLogger.log_error(
      error,
      context: {
        component: "background_job",
        error_type: "deserialization_error",
        job_class: job.class.name,
        job_arguments: job.arguments.inspect
      }
    )
  end
  
  # Global error handling for all jobs
  rescue_from StandardError do |error|
    ApplicationLogger.log_error(
      error,
      context: {
        component: "background_job",
        error_type: "job_execution_error",
        job_class: self.class.name,
        job_id: job_id,
        job_arguments: arguments.inspect,
        queue_name: queue_name,
        executions: executions
      }
    )
    
    Log.log(
      log_type: 'background_job',
      level: 'error',
      message: "Job execution failed: #{error.message}",
      action: 'job_execution_failed',
      context: {
        job_class: self.class.name,
        job_id: job_id,
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(10)
      }
    )
    
    raise error
  end
  
  # Callback to log job start
  before_perform do |job|
    next if job.class.name == "LogWriteJob"

    Rails.logger.info("[JOB_START] #{job.class.name} job_id: #{job.job_id}")
    ApplicationLogger.log_info(
      "Background job started",
      category: "background_job",
      data: {
        job_class: job.class.name,
        job_id: job.job_id,
        queue_name: job.queue_name,
        executions: job.executions
      }
    )
  end
  
  # Callback to log job completion
  after_perform do |job|
    next if job.class.name == "LogWriteJob"

    Rails.logger.info("[JOB_COMPLETE] #{job.class.name} job_id: #{job.job_id}")
    ApplicationLogger.log_info(
      "Background job completed",
      category: "background_job",
      data: {
        job_class: job.class.name,
        job_id: job.job_id,
        executions: job.executions
      }
    )
  end
end
