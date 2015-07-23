# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'
require 'rack'
require 'oj'

module Slanger
  class Handler

    attr_accessor :connection
    delegate :error, :send_payload, to: :connection

    def initialize(socket, handshake)
      @socket        = socket
      @handshake     = handshake
      @connection    = Connection.new(@socket)
      @subscriptions = {}
      authenticate
    end

    # Dispatches message handling to method with same name as
    # the event name
    def onmessage(msg)
      msg = Oj.load(msg)

      msg['data'] = Oj.load(msg['data']) if msg['data'].is_a? String

      event = msg['event'].gsub(/\Apusher:/, 'pusher_')

      if event =~ /\Aclient-/
        msg['socket_id'] = connection.socket_id
        Channel.send_client_message msg
      elsif respond_to? event, true
        send event, msg
      end

    rescue JSON::ParserError
      error({ code: 5001, message: "Invalid JSON" })
    rescue Exception => e
      error({ code: 500, message: "#{e.message}\n #{e.backtrace.join "\n"}" })
    end

    def onclose

      subscriptions = @subscriptions.select { |k,v| k && v }
      
      subscriptions.each_key do |channel_id|
        subscription_id = subscriptions[channel_id]
        Channel.unsubscribe channel_id, subscription_id
      end

    end

    def authenticate
      if !valid_app_key? app_key
        error({ code: 4001, message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
      elsif !valid_protocol_version?
        error({ code: 4007, message: "Unsupported protocol version" })
        @socket.close_websocket
      else
        return connection.establish
      end
    end

    def valid_protocol_version?
      protocol_version.between?(3, 7)
    end

    def pusher_ping(msg)
      send_payload nil, 'pusher:pong'
    end

    def pusher_pong msg; end

    def pusher_subscribe(msg)
      channel_id = msg['data']['channel']
      klass      = subscription_klass channel_id

      if @subscriptions[channel_id]
        error({ code: nil, message: "Existing subscription to #{channel_id}" })
      else
        @subscriptions[channel_id] = klass.new(connection.socket, connection.socket_id, msg).subscribe
      end
    end

    def pusher_unsubscribe(msg)
      channel_id      = msg['data']['channel']
      subscription_id = @subscriptions.delete(channel_id)

      Channel.unsubscribe channel_id, subscription_id
    end

    private

    def app_key
      @handshake.path.split(/\W/)[2]
    end

    def protocol_version
      @query_string ||= Rack::Utils.parse_nested_query(@handshake.query_string)
      @query_string["protocol"].to_i || -1
    end

    def valid_app_key? app_key
      Slanger::Config.app_key == app_key
    end

    def subscription_klass channel_id
      klass = channel_id.match(/\A(private|presence)-/) do |match|
        Slanger.const_get "#{match[1]}_subscription".classify
      end

      klass || Slanger::Subscription
    end
  end
end
