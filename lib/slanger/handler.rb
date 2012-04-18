# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler
    attr_accessor :payload

    def initialize(socket)
      @socket        = socket
      @payload = Payload.new(@socket)
      @subscriptions = {}
      authenticate
    end

    # Dispatches message handling to method with same name as the event name
    def onmessage(msg)
      msg   = JSON.parse msg
      event = msg['event'].gsub('pusher:', '')

      if event =~ /^client-/
        msg['socket_id'] = @socket_id

        Channel.send_client_message msg
      elsif %w(subscribe ping pong authenticate).include? event
        send event, msg
      end

    rescue JSON::ParserError
      payload.error({ code: '5001', message: "Invalid JSON" })
    end

    def onclose
      @subscriptions.each { |c, s| Channel.unsubscribe c, s }
    end

    private

    def authenticate
      return payload.establish_connection if valid_app_key?

      payload.error({ code: '4001', message: "Could not find app by key #{app_key}" })
      @socket.close_websocket
    end

    def ping(msg)
      send_payload nil, 'pusher:ping'
    end

    def pong msg; end

    def subscribe(msg)
      channel_id = msg['data']['channel']

      klass = subscription_klass channel_id

      @subscriptions[channel_id] = klass.new(payload.socket, payload.socket_id, msg).handle
    end

    def valid_app_key?
      Slanger::Config.app_key == @socket.request['path'].split(/\W/)[2]
    end

    def subscription_klass channel_id
      if private_subscription? channel_id
        PrivateSubscription
      elsif presence_subscription? channel_id
        PresenceSubscription
      else
        Subscription
      end
    end

    def private_subscription? channel_id
      channel_id =~ /^private-/
    end

    def presence_subscription? channel_id
      channel_id =~ /^presence-/
    end
  end
end
