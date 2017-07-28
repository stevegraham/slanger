require 'spec_helper'
require 'lib/slanger/webhook'

describe 'Slanger::Webhook' do

  around do |example|
    Slanger::Config.load webhook_url: 'https://example.com/pusher',
      app_key: 'PUSHER_APP_KEY', secret: 'secret'
    WebMock.enable!
    Timecop.freeze(Time.now) { example.run }
    WebMock.disable!
    Slanger::Config.load webhook_url: nil
  end

  describe '.post' do
    it 'make a POST request to the endpoint' do
      payload = {
        time_ms: Time.now.strftime('%s%L'),
        events: [{ name: 'channel_occupied', channel: 'test channel' }]
      }.to_json

      digest   = OpenSSL::Digest::SHA256.new
      hmac     = OpenSSL::HMAC.hexdigest(digest, Slanger::Config.secret, payload)

      stub_request(:post, Slanger::Config.webhook_url).
        with(body: payload, headers: {
            "X-Pusher-Key"    => Slanger::Config.app_key,
            "X-Pusher-Signature" => hmac,
            "Content-Type" => 'application/json'
        }).
        to_return(:status => 200, :body => {}.to_json, :headers => {})

      Slanger::Webhook.post name: 'channel_occupied', channel: 'test channel'

      expect(WebMock).to have_requested(:post, Slanger::Config.webhook_url).
        with(body: payload, headers: {
            "X-Pusher-Key"    => Slanger::Config.app_key,
            "X-Pusher-Signature" => hmac,
            "Content-Type" => 'application/json'
        })
    end
  end
end
