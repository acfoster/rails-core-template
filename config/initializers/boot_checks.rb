# Boot checks to verify system dependencies
Rails.application.config.after_initialize do
  begin
    # Check bundler version
    bundler_version = Bundler::VERSION
    Rails.logger.info "✓ Boot check: Bundler #{bundler_version} loaded successfully"
    
    # Check database connection
    ActiveRecord::Base.connection.execute("SELECT 1")
    Rails.logger.info "✓ Boot check: Database connection successful"
    
    # Check that essential services are loadable
    begin
      RulesEvaluationService
      Rails.logger.info "✓ Boot check: RulesEvaluationService loaded successfully"
    rescue => e
      Rails.logger.error "✗ Boot check: RulesEvaluationService failed to load - #{e.message}"
    end
    
    Rails.logger.info "✓ Boot checks completed successfully"
    
  rescue => e
    Rails.logger.error "✗ Boot check failed: #{e.message}"
    # Don't fail the boot process, just log the issue
  end
end