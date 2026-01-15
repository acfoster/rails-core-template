# ReleaseTaskRun model tracks execution of release tasks
# Used to ensure tasks run only once per deployment
class ReleaseTaskRun < ApplicationRecord
  # Status values: pending, running, completed, failed
  validates :task_name, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :for_task, ->(task_name) { where(task_name: task_name) }

  # Check if task has already completed successfully
  def self.task_completed?(task_name)
    completed.for_task(task_name).exists?
  end

  # Mark task as started
  def mark_started!
    update!(status: 'running', started_at: Time.current)
  end

  # Mark task as completed
  def mark_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  # Mark task as failed
  def mark_failed!(error)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error.message
    )
  end
end
