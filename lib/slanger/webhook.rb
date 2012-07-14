require 'fiber'
require 'em-http-request'

module Slanger
  module Webhook
    def post payload
      return unless Slanger::Config.webhook_url

      payload = {
        time_ms: Time.now.strftime('%s%L'), events: [payload]
      }.to_json

      digest   = OpenSSL::Digest::SHA256.new
      hmac     = OpenSSL::HMAC.hexdigest(digest, Slanger::Config.secret, payload)

      Fiber.new do
        f = Fiber.current
        
        EM::HttpRequest.new(Slanger::Config.webhook_url).
          post(body: payload, head: { "X-Pusher-Key" => Slanger::Config.app_key, "X-Pusher-Secret" => hmac }).
          callback { f.resume }
          # TODO: Exponentially backed off retries for errors
        Fiber.yield
      end.resume
    end

    extend self
  end
end
