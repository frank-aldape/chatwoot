require 'json'
require 'net/http'
require 'uri'

# Posts a JSON body to ALERT_WEBHOOK_URL. Callers own the body shape, so each
# alert keeps its own contract with whatever consumes the webhook.
class Internal::AlertWebhook
  def self.configured?
    ENV.fetch('ALERT_WEBHOOK_URL', '').present?
  end

  def self.post(body)
    uri = URI.parse(ENV.fetch('ALERT_WEBHOOK_URL'))
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(body)
    timeout = ENV.fetch('ALERT_WEBHOOK_TIMEOUT_SECONDS', 10).to_f

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: timeout) do |http|
      response = http.request(request)
      raise "alert webhook failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    end
  end
end
