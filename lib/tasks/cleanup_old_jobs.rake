namespace :jobs do
  desc "Clean up old/invalid jobs from Solid Queue"
  task cleanup_invalid: :environment do
    puts "Cleaning up invalid jobs from Solid Queue..."

    # Delete jobs with invalid class names
    invalid_count = SolidQueue::Job.where("class_name LIKE ?", "%EvaluationProcessorJob%").delete_all
    puts "Deleted #{invalid_count} jobs with invalid class name 'EvaluationProcessorJob'"

    # Delete very old pending jobs (older than 7 days)
    old_count = SolidQueue::Job.where("created_at < ? AND finished_at IS NULL", 7.days.ago).delete_all
    puts "Deleted #{old_count} old pending jobs"

    puts "Cleanup complete!"
  end
end
