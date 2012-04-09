require 'aquarium'
require 'singleton'
 
if Slanger::Config.statistics
  # Add accessors to the Handler class
  module Slanger
    class Handler
      attr_accessor :application
      attr_accessor :socket
      attr_accessor :peername
      attr_accessor :slanger_id
    end
  end

  # Add new API calls
  module Slanger
    class ApiServer
      get '/statistics/apps/:app_id' do
        statistics_protected!
        f = Fiber.current
        # Retrieve the application statistics
        resp = Statistics.get_metrics_for(params[:app_id])
        resp.callback do |doc|
          f.resume doc
        end
        resp.errback do |err|
          raise *err
        end
        metrics = Fiber.yield

        return [404, {}, "404 NOT FOUND\n"] if metrics.nil?

        [200, {}, metrics['value'].to_json]
      end

      get '/statistics/all_apps' do
        statistics_protected!
        f = Fiber.current
        # Retrieve all the application statistics
        resp = Statistics.get_all_metrics()
        resp.callback do |doc|
          f.resume doc
        end
        resp.errback do |err|
          raise *err
        end
        metrics = Fiber.yield

        return [404, {}, "404 NOT FOUND\n"] if metrics.nil?

        [200, {}, metrics.to_json]
      end

      # Authenticate requests
      def statistics_protected!
        unless statistics_authorized?
          response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      # authorise HTTP users for the API calls
      def statistics_authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [Config.admin_http_user, Config.admin_http_password]
     end
    end
  end
end
  
module Slanger
  class StatisticsSingleton
    include Singleton
    if Slanger::Config.statistics
      include Aquarium::DSL
  
      # Return the metrics for one application
      def get_metrics_for(app_id)
        metrics.find_one(_id: app_id)
      end
 
      # Return the metrics for all applications
      def get_all_metrics()
        metrics.find().defer_as_a
      end

      def initialize()
        # Starts up a periodic timer in eventmachine to calculate the metrics every minutes
        EventMachine::PeriodicTimer.new(60) do
          refresh_metrics
        end
      end     

      # Increment the number of message for an application each time a message is dispatched into one
      # of its channels
      after :calls_to => :dispatch, :on_types => [Slanger::Channel, Slanger::PresenceChannel] do |join_point, channel, *args|
        # Update record
        Statistics.work_data.update(
          {app_id: channel.application.id},
          {'$inc' => {nb_messages: 1}, '$set' => {timestamp: Time.now.to_i}},
          {upsert: true}
        )
      end
  
      # Add new connections to an application to its list
      after :calls_to => :authenticate, :restricting_methods_to => :private, :on_type => Slanger::Handler do |join_point, handler, *args|
        application = handler.application
        unless application.nil?
          # Get peer's IP and port
          peername = Statistics.get_peer_ip_port(handler.socket)
          # Save them so that we can remove them from mongo later
          handler.peername = peername
          # Get slanger_id if it exists or the listening IP and port
          slanger_id = Config.slanger_id || get_socket_ip_port(handler.socket)
          # Save them
          handler.slanger_id = slanger_id
          # Update record
          Statistics.work_data.update(
            {app_id: application.id},
            {'$addToSet' => {connections: {slanger_id: slanger_id, peer: peername}}, '$set' => {timestamp: Time.now.to_i}},
            {upsert: true}
          )
        end
      end
  
      # Remove connexions when it is closed
      before :calls_to => :onclose, :on_type => Slanger::Handler do |join_point, handler, *args|
        application = handler.application
        peername = handler.peername
        slanger_id = handler.slanger_id
        unless application.nil? or peername.nil? or slanger_id.nil?
          # Update record
          Statistics.work_data.update(
            {app_id: application.id},
            {'$pull' => {connections: {slanger_id: slanger_id, peer: peername}}, '$set' => {timestamp: Time.now.to_i}},
            {upsert: true}
          )
        end
      end

      def map_function()
        <<-MAPFUNCTION
        function () {
          if (!this.connections) {
            return;
          }
          var timestamp = Math.round(Date.now() / 1000);
          // Emit app_id, nb conn, max conn and nv messages. 
          // max numberconnections is equal to current number, it will be compared to earlier data 
          // in the reduce function and the maximum kept.
          emit(
            this.app_id,
            {
              timestamp: timestamp,
              nb_connections: this.connections.length,
              max_nb_connections: this.connections.length,
              nb_messages: this.nb_messages
            }
          );
        }
        MAPFUNCTION
      end

      def reduce_function()
        <<-REDUCEFUNCTION
        function (key, values) {
          var result = {timestamp: 0, nb_connections:0, max_nb_connections:0, nb_messages:0};
          values.forEach(
            function (value) {
              if (value.timestamp > result.timestamp) {
                //Keep newest timestamp, number of connections and number of messages
                result.timestamp = value.timestamp;
                result.nb_connections = value.nb_connections;
                result.nb_messages += value.nb_messages;
              }
              //Keep the highest max number of connections
              result.max_nb_connections = Math.max(result.max_nb_connections, value.max_nb_connections);
            }
          );
          return result;
        }
        REDUCEFUNCTION
      end

      # Run a MapReduce query to fill the slanger metrics collection from data
      def refresh_metrics()
        # Only run it on the master node, so that it isn't run several time
        # if several slanger daemons are running
        return unless Cluster.is_master?
        Logger.debug log_message("Calculating metrics.")
        Fiber.new {
          # Retrieve last timestamp
          f = Fiber.current
          resp = variables.find_one(_id: 'statistics.last_timestamp')
          resp.callback do |doc|
            f.resume doc
          end
          resp.errback do |err|
            raise *err
          end
          last_timestamp_record = Fiber.yield 
          last_timestamp = if last_timestamp_record.nil?
            0
          else
            last_timestamp_record['timestamp']
          end
          new_timestamp = Time.now.to_i
          work_data.map_reduce(
            map_function,
            reduce_function,
            {
              query: {timestamp: {'$gte' => last_timestamp}},
              out: {reduce: 'slanger.statistics.metrics'}
            }
          )
          # Save timestamp
          variables.update(
            {_id: 'statistics.last_timestamp'},
            {'$set' => {timestamp: new_timestamp}},
            {upsert: true}
          )
        }.resume
      end

      def get_peer_ip_port(socket)
        peername = socket.get_peername
        if peername.nil?
          nil
        else
          port, ip = Socket.unpack_sockaddr_in(peername) 
          "" + ip + ":" + port.to_s
        end
      end
   
      def get_socket_ip_port(socket)
        slanger_id = socket.get_sockname
        if slanger_id.nil?
          nil
        else
          port, ip = Socket.unpack_sockaddr_in(slanger_id) 
          "" + ip + ":" + port.to_s
        end
      end
   
      # Work data collection in Mongodb
      def work_data
        @work_data ||= Mongo.collection("jagan.statistics.work_data")
      end

      # Variables collection in Mongodb
      def variables
        @variables ||= Mongo.collection("jagan.statistics.variables")
      end
 
      # Metrics collection in Mongodb
      def metrics
        @metrics ||= Mongo.collection("jagan.statistics.metrics")
      end

      def log_message(message)
        "Node " + Cluster.id + ": " + message
      end
    end
  end

  Statistics = StatisticsSingleton.instance
end
