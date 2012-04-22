module Slanger
  module PusherMethods
    def authenticate
      return establish if valid_app_key?

      error({ code: '4001', message: "Could not find app by key #{app_key}" })
      @socket.close_websocket
    end

    def pusher_ping(msg)
      send_payload nil, 'pusher:ping'
    end

    def pusher_pong msg; end

    def pusher_subscribe(msg)
      channel_id = msg['data']['channel']

      klass = subscription_klass channel_id

      @subscriptions[channel_id] = klass.new(connection.socket,
                                             connection.socket_id, msg).subscribe
    end

    private

    def valid_app_key?
      Slanger::Config.app_key == @socket.request['path'].split(/\W/)[2]
    end

    def subscription_klass channel_id
      klass = channel_id.match(/^(private|presence)-/) do |match|
        Slanger.const_get "#{match[1]}_subscription".classify
      end

      klass || Slanger::Subscription
    end
  end
end
