# ReleaseTaskRunner - Safe "run once" task execution on Railway deployment
#
# SAFETY FEATURES:
# - ENV-gated: Only runs when RUN_RELEASE_TASKS=1
# - Run-once tracking: Database-backed completion tracking
# - Postgres advisory locks: Prevents race conditions across instances
# - Individual task control: Each task has its own ENV var
#
# USAGE:
# In docker entrypoint or Railway deploy:
#   bundle exec rails runner "ReleaseTaskRunner.run"
#
# ENV VARS:
# - RUN_RELEASE_TASKS=1          # Master switch (default: disabled)
# - Add more task flags here as needed
#
module ReleaseTaskRunner
  # Advisory lock key for release tasks coordination
  # Using a high number to avoid conflicts with other advisory locks
  ADVISORY_LOCK_KEY = 987654321

  class << self
    # Main entry point - runs all enabled tasks
    def run
      unless ENV['RUN_RELEASE_TASKS'] == '1'
        Rails.logger.info("[RELEASE_TASKS] Skipped: RUN_RELEASE_TASKS not enabled")
        return
      end

      Rails.logger.info("[RELEASE_TASKS] Starting release tasks execution")

      # Acquire advisory lock to ensure only one instance runs tasks
      acquired = acquire_advisory_lock

      unless acquired
        Rails.logger.info("[RELEASE_TASKS] Could not acquire advisory lock - another instance is running tasks")
        return
      end

      begin
        run_enabled_tasks
      ensure
        release_advisory_lock
      end

      Rails.logger.info("[RELEASE_TASKS] Release tasks execution complete")
    end

    private

    # Run all tasks that are enabled via ENV vars
    def run_enabled_tasks
      tasks = []

      tasks.each do |task_config|
        next unless ENV[task_config[:env_var]] == '1'

        run_task(task_config[:name], task_config[:class_name])
      end
    end

    # Execute a single task with tracking and error handling
    def run_task(task_name, class_name)
      # Check if task already completed
      if ReleaseTaskRun.task_completed?(task_name)
        Rails.logger.info("[RELEASE_TASKS] Task '#{task_name}' already completed - skipping")
        return
      end

      Rails.logger.info("[RELEASE_TASKS] Running task: #{task_name}")

      # Create tracking record
      task_run = ReleaseTaskRun.create!(task_name: task_name, status: 'pending')
      task_run.mark_started!

      begin
        # Instantiate and run the task
        task_class = class_name.constantize
        task_instance = task_class.new
        task_instance.run

        task_run.mark_completed!
        Rails.logger.info("[RELEASE_TASKS] Task '#{task_name}' completed successfully")

      rescue => e
        task_run.mark_failed!(e)
        Rails.logger.error("[RELEASE_TASKS] Task '#{task_name}' failed: #{e.message}")
        Rails.logger.error("[RELEASE_TASKS] Backtrace: #{e.backtrace.first(5).join("\n")}")

        # Don't raise - allow other tasks to run
      end
    end

    # Acquire Postgres advisory lock
    def acquire_advisory_lock
      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_KEY})"
      )
      result.first['pg_try_advisory_lock'] == true
    end

    # Release Postgres advisory lock
    def release_advisory_lock
      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_KEY})"
      )
    end
  end
end
