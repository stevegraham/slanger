# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler

    attr_accessor :connection
    delegate :error, :send_payload, to: :connection

    def initialize(socket)
      @socket        = socket
      @connection    = Connection.new(@socket)
      @subscriptions = {}
      authenticate
    end

    # Dispatches message handling to method with same name as
    # the event name
    def onmessage(msg)
      msg   = JSON.parse msg
      event = msg['event'].gsub(/^pusher:/, 'pusher_')

      if event =~ /^client-/
        msg['socket_id'] = connection.socket_id
        channel = application.channel_from_id msg['channel']
        channel.try :send_client_message, msg
      elsif respond_to? event, true
        send event, msg
      else
        Logger.error "Unknown event: " + event.to_s
      end

    rescue JSON::ParserError
      Logger.error log_message("JSON Parse error on message: '" + msg.to_s + "'")
      error({ code: 5001, message: "Invalid JSON" })
    rescue Exception => e
      error({ code: 500, message: "#{e.message}\n #{e.backtrace}" })
    end

    def onclose
      # Unsubscribe from channels
      @subscriptions.each do |channel_id, subscription_id|
        channel = application.channel_from_id channel_id
        channel.try :unsubscribe, subscription_id
      end
      Logger.debug log_message("Closed connection.")
    end

    def authenticate
      if valid_app_key? app_key
        Logger.debug log_message("Connection established.")
        return connection.establish
      else
        error({ code: 4001, message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
        Logger.error log_message("Application key not found: " + app_key._to_s)
      end
    end

    def pusher_ping(msg)
      send_payload nil, 'pusher:ping'
      Logger.debug log_message("Ping sent.")
    end

    def pusher_pong msg
      Logger.debug log_message("Pong received: " + msg.to_s)
    end

    def pusher_subscribe(msg)
      channel_id = msg['data']['channel']
      klass      = subscription_klass channel_id
      subscription_id = klass.new(application, connection.socket, connection.socket_id, msg).subscribe
      @subscriptions[channel_id] = subscription_id
      Logger.debug log_message("Subscribed to channel: " + channel_id.to_s + " subscriptions id: " + subscription_id.to_s)
      Logger.audit log_message("Subscribed to channel: " + channel_id.to_s + " subscriptions id: " + subscription_id.to_s)
    end

    private

    def app_key
      @socket.request['path'].split(/\W/)[2]
    end

    def application
      @application ||= Application.find_by_key(app_key)
    end

    def valid_app_key? app_key
      not application.nil?
    end

    def subscription_klass channel_id
      klass = channel_id.match(/^(private|presence)-/) do |match|
        Slanger.const_get "#{match[1]}_subscription".classify
      end

      klass || Slanger::Subscription
    end

    def log_message(msg)
      peername = connection.socket.get_peername
      if peername.nil?
        "socket_id: " + connection.socket_id.to_s + " " + msg
      else
        port, ip = Socket.unpack_sockaddr_in(peername) 
        "Peer: " + ip.to_s + ":" + port.to_s + " socket_id: " + connection.socket_id.to_s + " " + msg.to_s
      end
    end
  end
end
