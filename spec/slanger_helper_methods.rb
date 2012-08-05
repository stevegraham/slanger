require 'fiber'
require 'mongo'
require 'net/http'
require File.expand_path(File.dirname(__FILE__) + '/../slanger.rb')

module SlangerHelperMethods
  def options()
    { host:                '127.0.0.1',
      api_port:            '4567',
      websocket_port:      '8080',
      log_level:           ::Logger::DEBUG,
      log_file:            File.new(IO::NULL, 'a'),
      api_log_file:        File.new(IO::NULL, 'a'),
      audit_log_file:      File.new(IO::NULL, 'a'),
      slanger_id:          'slanger1',
      mongo_host:          'localhost',
      mongo_port:          '27017',
      mongo_db:            'slanger_test',
      metrics:             true,
      admin_http_user:     'admin',
      admin_http_password: 'secret',
    }
  end

  def start_slanger_with_options arg_options={}
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      Thin::Logging.silent = true
      opts = options
      Slanger::Config.load opts.merge(arg_options)
      # Fill with applications
      Fiber.new do
        Slanger::Application.create({
          app_id: 1,
          key: '765ec374ae0a69f4ce44',
          secret: 'your-pusher-secret'
        })
        Slanger::Application.create({
          app_id: 2,
          key: '23deadbeef99abababab',
          secret: 'your-pusher-secret'
        })
      end.resume 
      Slanger::Service.run
    end
    wait_for_slanger
  end

  def start_slanger_with_mongo
    start_slanger_with_options mongo: true
  end

  alias start_slanger start_slanger_with_options

  def kill_slanger()
    # Kill slanger
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
    @server_pid = nil
  end 

  def stop_slanger
    # Ensure Slanger is properly stopped. No orphaned processes allowed!
    return if @server_pid.nil?
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
    uri = "ws://0.0.0.0:8080/app/#{opts[:key]}?client=js&version=1.8.5"

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

  def mongo
    opts = options
    @mongo ||= Mongo::Connection.new(opts[:mongo_host], opts[:mongo_port]).db(opts[:mongo_db])
  end

  def metrics_work_data
    mongo.collection("slanger.metrics.work_data")
  end

  def metrics_data
    mongo.collection("slanger.metrics.data")
  end

  def cleanup_db
    mongo.collections.each do |collection|
      unless collection.name =~ /^system\./
        collection.remove
      end
    end
  end

  def get_number_of_connections()
    doc = metrics_work_data.find_one({app_id: 1})
    if doc then doc['connections'].count else nil end
  end

  def get_number_of_messages()
    doc = metrics_work_data.find_one({app_id: 1})
    doc['nb_messages']
  end

  def applications
    mongo.collection("slanger.applications")
  end

  def get_application(app_id)
    applications.find_one({'_id' => app_id})
  end

  def rest_api_post(path, payload='')
    opts = options
    req = Net::HTTP::Post.new(path, initheader = {'Content-Type' =>'application/json'})
    req.basic_auth opts[:admin_http_user] , opts[:admin_http_password]
    req.body = payload
    Net::HTTP.new(opts[:host], opts[:api_port]).start {|http| http.request(req) }
  end

  def rest_api_put(path, payload='')
    opts = options
    req = Net::HTTP::Put.new(path, initheader = {'Content-Type' =>'application/json'})
    req.basic_auth opts[:admin_http_user] , opts[:admin_http_password]
    req.body = payload
    Net::HTTP.new(opts[:host], opts[:api_port]).start {|http| http.request(req) }
  end

  def rest_api_delete(path)
    opts = options
    req = Net::HTTP::Delete.new(path, initheader = {'Content-Type' =>'application/json'})
    req.basic_auth opts[:admin_http_user] , opts[:admin_http_password]
    Net::HTTP.new(opts[:host], opts[:api_port]).start {|http| http.request(req) }
  end

  def rest_api_get(path)
    opts = options
    req = Net::HTTP::Get.new(path, initheader = {'Content-Type' =>'application/json'})
    req.basic_auth opts[:admin_http_user] , opts[:admin_http_password]
    Net::HTTP.new(opts[:host], opts[:api_port]).start {|http| http.request(req) }
  end

  def pusher_app1
    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = '1'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end
 
  def pusher_app2
    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = '2'
      p.secret = 'your-pusher-secret'
      p.key    = '23deadbeef99abababab'
    end
  end
end

def with_mongo_slanger(&block)
  context "with Slanger using MongoDB, " do
    before :each do
      start_slanger_with_mongo
    end

    instance_eval &block
  end
end

def with_poro_slanger(&block)
  context "with Slanger using PORO, " do
    before :each do
      start_slanger
    end

    instance_eval &block
  end
end

def with_stale_metrics(&block)
  context "with stale metrics, " do
    before :each do
      metrics_work_data.update(
        {app_id: 1},
        {app_id: 1, connections: [{slanger_id: options['slanger_id'], peer: 'stale peer'}] },
        upsert: true
      )
    end

    instance_eval &block
  end
end


