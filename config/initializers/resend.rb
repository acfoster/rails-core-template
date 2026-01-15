# Configure Resend API
if ENV["RESEND_API_KEY"].present?
  Resend.api_key = ENV["RESEND_API_KEY"]
end

# Custom delivery method for Resend
module ResendDeliveryMethod
  class Client
    attr_accessor :settings

    def initialize(settings = {})
      @settings = settings
    end

    def deliver!(mail)
      return unless ENV["RESEND_API_KEY"].present?

      # Extract email details
      params = {
        from: mail.from.first,
        to: mail.to,
        subject: mail.subject,
        html: mail.html_part&.body&.decoded || mail.body.decoded
      }

      # Add text part if present
      if mail.text_part
        params[:text] = mail.text_part.body.decoded
      end

      # Send via Resend API
      Resend::Emails.send(params)
    rescue => e
      Rails.logger.error("Resend delivery failed: #{e.message}")
      raise e unless Rails.env.production?
    end
  end
end

# Register the delivery method
ActionMailer::Base.add_delivery_method(:resend, ResendDeliveryMethod::Client)
