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

  def private_channel websocket, message
    auth = Pusher['private-channel'].authenticate(message['data']['socket_id'])[:auth]
    websocket.send({ event: 'pusher:subscribe',
                     data: { channel: 'private-channel',
               auth: auth } }.to_json)

  end

  class HaveAttributes
    attr_reader :messages, :attributes
    def initialize attributes
      @attributes = attributes
    end

    CHECKS = %w(first_event last_event last_data )

    def matches?(messages)
      @messages = messages
      @failures = []

      check_connection_established if attributes[:connection_established]
      check_id_present             if attributes[:id_present]

      CHECKS.each { |a| attributes[a.to_sym] ?  check(a) : true }

      @failures.empty?
    end

    def check message
      send(message) == attributes[message.to_sym] or @failures << message
    end

    def failure_message
      @failures.map {|f| "expected #{f}: to equal #{attributes[f]} but got #{send(f)}"}.join "\n"
    end

    private

    def check_connection_established
      if first_event != 'pusher:connection_established'
        @failures << :connection_established
      end
    end

    def check_id_present
      if messages.first['data']['socket_id'] == nil
        @failures << :id_present
      end
    end

    def first_event
      messages.first['event']
    end

    def last_event
      messages.last['event']
    end

    def last_data
      messages.last['data']
    end

    def count
      messages.length
    end
  end

  def have_attributes attributes
    HaveAttributes.new attributes
  end
end



