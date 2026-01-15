class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("DEFAULT_MAIL_FROM", "support@tradecheckr.com")
  layout "mailer"
end
