# Load disposable email domains from YAML configuration
disposable_domains_file = Rails.root.join('config', 'disposable_email_domains.yml')

if File.exist?(disposable_domains_file)
  config = YAML.load_file(disposable_domains_file)
  Rails.configuration.x.disposable_email_domains = config['domains'] || []
else
  Rails.configuration.x.disposable_email_domains = []
  Rails.logger.warn "Disposable email domains configuration file not found"
end
