module EventMachineHelperMethods
  def new_websocket
    uri = "ws://0.0.0.0:8080/app/#{Pusher.key}?client=js&version=1.8.5"

    EM::HttpRequest.new(uri).get(:timeout => 0).tap do |ws|
      ws.errback &errback
    end
  end

  def em_stream
    messages = []

    em_thread do
      websocket = new_websocket

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
    id = options[:message]['data']['socket_id']
    name = options[:name]
    user_id = options[:user_id]
    Pusher['presence-channel'].authenticate(id, {user_id: user_id, user_info: {name: name}})
  end

  def send_subscribe options
    auth = auth_from options
    options[:user].send({event: 'pusher:subscribe',
                  data: {channel: 'presence-channel'}.merge(auth)}.to_json)
  end

  def matcher messages, options
    messages.first['event'].should == 'pusher:connection_established' if options[:connection_established]
    messages.first['data']['socket_id'].should_not be_nil   if options[:id_present]
    messages.first['event'].should == options[:first_event] if options[:first_event]
    messages.last['event'].should  == options[:last_event]  if options[:last_event]
    messages.last['data'].should   == options[:last_data]   if options[:last_data]
    messages.length.should         == options[:count]       if options[:count]
  end
end


