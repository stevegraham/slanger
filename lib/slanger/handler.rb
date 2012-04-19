# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler
    include PusherMethods

    attr_accessor :connection
    delegate :error, :establish, :send_payload, to: :connection

    def initialize(socket)
      @socket        = socket
      @connection    = Connection.new(@socket)
      @subscriptions = {}
      pusher_authenticate
    end

    # Dispatches message handling to method with same name as
    # the event name
    def onmessage(msg)
      msg   = JSON.parse msg
      event = msg['event'].gsub(/^pusher:/, 'pusher_')

      if event =~ /^client-/
        msg['socket_id'] = @socket_id

        Channel.send_client_message msg
      elsif %w(pusher_subscribe pusher_ping pusher_pong pusher_authenticate).include? event
        send event, msg
      end

    rescue JSON::ParserError
      error({ code: '5001', message: "Invalid JSON" })
    end

    def onclose
      @subscriptions.each { |c, s| Channel.unsubscribe c, s }
    end
  end
end
