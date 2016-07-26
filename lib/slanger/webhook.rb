require 'fiber'
require 'em-http-request'
require 'oj'

module Slanger
  module Webhook
    def post payload
      return unless Slanger::Config.webhook_url

      payload ={
        time_ms: Time.now.strftime('%s%L'), events: [payload]
      }

      payload = Oj.dump(payload, mode: :compat)

      digest        = OpenSSL::Digest::SHA256.new
      hmac          = OpenSSL::HMAC.hexdigest(digest, Slanger::Config.secret, payload)
      content_type  = 'application/json'

      http = EM::HttpRequest.new(Slanger::Config.webhook_url).
        post(body: payload, head: {
          "X-Pusher-Key" => Slanger::Config.app_key,
          "X-Pusher-Signature" => hmac,
          "Content-Type" => content_type
        })

      # TODO: Exponentially backed off retries for errors
      http.callback {
        if (http.response_header.status < 200 && http.response_header.status > 299)
          puts "Error: #{http.error} while posting to #{Slanger::Config.webhook_url}, Response: #{http.response}"
        end
      }

      http.errback {
        puts "Unable to post to #{Slanger::Config.webhook_url}"
      }

    end

    extend self
  end
end
