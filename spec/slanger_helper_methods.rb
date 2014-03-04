module SlangerHelperMethods
  def start_slanger_with_options options={}
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      require File.expand_path(File.dirname(__FILE__) + '/../slanger.rb')
      Thin::Logging.silent = true

      opts = { host:             '0.0.0.0',
               api_port:         '4567',
               websocket_port:   '8080',
               app_key:          '765ec374ae0a69f4ce44',
               secret:           'your-pusher-secret' }

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
    opts = { key: Pusher.key }.update opts
    uri = "ws://0.0.0.0:8080/app/#{opts[:key]}?client=js&version=2.1.4"

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

  def auth_from options
    id      = options[:message]['data']['socket_id']
    name    = options[:name]
    user_id = options[:user_id]
    Pusher['presence-channel'].authenticate(id, {user_id: user_id, user_info: {name: name}})
  end

  def send_subscribe options
    auth = auth_from options
    options[:user].send({event: 'pusher:subscribe',
                  data: {channel: 'presence-channel'}.merge(auth)}.to_json)
  end

  def private_channel websocket, message
    auth = Pusher['private-channel'].authenticate(message['data']['socket_id'])[:auth]
    websocket.send({ event: 'pusher:subscribe',
                     data: { channel: 'private-channel',
               auth: auth } }.to_json)

  end
end
