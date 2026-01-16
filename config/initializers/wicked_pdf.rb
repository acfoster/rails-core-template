# WickedPDF configuration
# Use system wkhtmltopdf (installed via nixpacks on Railway)
# This avoids permission issues with the wkhtmltopdf-binary gem's bundled binaries

wkhtmltopdf_path = `which wkhtmltopdf 2>/dev/null`.strip.presence

if wkhtmltopdf_path.nil?
  Rails.logger.warn "wkhtmltopdf not found in PATH. PDF generation will fail."
  Rails.logger.warn "Install wkhtmltopdf: brew install wkhtmltopdf (macOS) or via nixpacks (Railway)"
end

WickedPdf.configure do |config|
  config.exe_path = wkhtmltopdf_path || '/usr/bin/wkhtmltopdf' # fallback path
end
