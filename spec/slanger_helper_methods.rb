module SlangerHelperMethods
  def start_slanger_with_options options={}
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      Thin::Logging.silent = true

      opts = { host:             '0.0.0.0',
               api_port:         '4567',
               websocket_port:   '8080',
               app_key:          '765ec374ae0a69f4ce44',
               secret:           'your-pusher-secret',
               activity_timeout: 100
             }

      Slanger::Config.load opts.merge(options)

      Slanger::Service.run
    end
    wait_for_slanger
  end

  alias start_slanger start_slanger_with_options

  def stop_slanger
    # Ensure Slanger is properly stopped. No orphaned processes allowed!
     Process.kill 'SIGKILL', @server_pid
     Process.wait @server_pid
  end

  def wait_for_slanger opts = {}
    opts = { port: 8080 }.update opts
    begin
      TCPSocket.new('0.0.0.0', opts[:port]).close
    rescue
      sleep 0.005
      retry
    end
  end

  def new_websocket opts = {}
    opts = { key: Pusher.key, protocol: 7 }.update opts
    uri = "ws://0.0.0.0:8080/app/#{opts[:key]}?client=js&version=1.8.5&protocol=#{opts[:protocol]}"

    EM::HttpRequest.new(uri).get.tap { |ws| ws.errback &errback }
  end

  def em_stream opts = {}
    messages = []

    em_thread do
      websocket = new_websocket opts

      stream(websocket, messages) do |message|
        yield websocket, messages
      end
    end

    return messages
  end

  def em_thread
    Thread.new do
      EM.run do
        yield
      end
    end.join
  end

  def stream websocket, messages
    websocket.stream do |message|
      messages << JSON.parse(message)

      yield message
    end
  end

  def send_subscribe options
    info      = { user_id: options[:user_id], user_info: { name: options[:name] } }
    socket_id = JSON.parse(options[:message]['data'])['socket_id']
    to_sign   = [socket_id, 'presence-channel', info.to_json].join ':'

    digest = OpenSSL::Digest::SHA256.new

    options[:user].send({
      event: 'pusher:subscribe',
      data: {
        auth: [Pusher.key, OpenSSL::HMAC.hexdigest(digest, Pusher.secret, to_sign)].join(':'),
        channel_data: info.to_json,
        channel: 'presence-channel'
      }
    }.to_json)
  end

  def private_channel websocket, message
    socket_id = JSON.parse(message['data'])['socket_id']
    to_sign   = [socket_id, 'private-channel'].join ':'

    digest = OpenSSL::Digest::SHA256.new

    websocket.send({
      event: 'pusher:subscribe',
      data: {
        auth: [Pusher.key, OpenSSL::HMAC.hexdigest(digest, Pusher.secret, to_sign)].join(':'),
        channel: 'private-channel'
      }
    }.to_json)

  end
end
