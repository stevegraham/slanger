# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler
    attr_accessor :connection
    delegate :error, :establish, :send_payload, to: :payload

    def initialize(socket)
      @socket        = socket
      @connection = Connection.new(@socket)
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
      error({ code: '5001', message: "Invalid JSON" })
    end

    def onclose
      @subscriptions.each { |c, s| Channel.unsubscribe c, s }
    end

    private

    def authenticate
      return establish if valid_app_key?

      error({ code: '4001', message: "Could not find app by key #{app_key}" })
      @socket.close_websocket
    end

    def ping(msg)
      send_payload nil, 'pusher:ping'
    end

    def pong msg; end

    def subscribe(msg)
      channel_id = msg['data']['channel']

      klass = subscription_klass channel_id

      @subscriptions[channel_id] = klass.new(connection.socket, connection.socket_id, msg).handle
    end

    def valid_app_key?
      Slanger::Config.app_key == @socket.request['path'].split(/\W/)[2]
    end

    def subscription_klass channel_id
      if channel_id =~ /^private-/
        PrivateSubscription
      elsif channel_id =~ /^presence-/
        PresenceSubscription
      else
        Subscription
      end
    end
  end
end
