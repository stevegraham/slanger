module Slanger
  module Metrics

    def self.extended(base)
      # Initialisation
      if Config::metrics
        Logger.debug log_message("Initializing metrics")
        # Starts up a periodic timer in eventmachine to calculate the metrics every minutes
        EventMachine::PeriodicTimer.new(60) do
          refresh_metrics
        end
      
        # Clean up our work data, in case we crashed previously. Of course it doesn't
        # word if the node id has been randomly generated.
        Logger.debug log_message("Cleaning stale word data")
        work_data.update(
          {},
          {'$pull' => {connections: {slanger_id: Cluster.node_id}}}
        )
      end
    end

    # Increment the number of message for an application each time a message is dispatched into one
    # of its channels
    def sent_message(application)
      # Update record
      work_data.update(
        {app_id: application.app_id},
        {'$inc' => {nb_messages: 1}, '$set' => {timestamp: Time.now.to_i}},
        {upsert: true}
      )
      refresh_metrics()
    end
 
    def stop()
      return unless Config.metrics

      # Remove all connexions before slanger stops
      f = Fiber.current
      Logger.debug log_message("Removing connections from DB before stop.")
      resp = work_data.safe_update(
        {},
        {'$pull' => {connections: {slanger_id: Cluster.node_id}}, '$set' => {timestamp: Time.now.to_i}}
      )
      resp.callback do |doc|
        f.resume doc
      end
      resp.errback do |err|
        # Error during save
        Logger.error "Error when cleaning up work data: " + err.to_s
        f.resume nil
      end
      Fiber.yield
    end
 
    # Add new connections to an application to its list
    def new_connection(handler)
      unless handler.application.nil?
        # Get peer's IP and port
        peer = handler.peer_ip_port()
        # Update record
        work_data.update(
          {app_id: handler.application.app_id},
          {'$addToSet' => {connections: {slanger_id: Cluster.node_id, peer: peer}}, '$set' => {timestamp: Time.now.to_i}},
          {upsert: true}
        )
      end
    end 
 
    # Remove connexions when it is closed
    def connection_closed(handler)
      peer = handler.peer_ip_port()
      unless handler.application.nil? or peer.nil?
        # Update record
        work_data.update(
          {app_id: handler.application.app_id},
          {'$pull' => {connections: {slanger_id: Cluster.node_id, peer: peer}}, '$set' => {timestamp: Time.now.to_i}}
        )
      end
    end
 
    private 
  
    #def get_socket_ip_port(socket)
    #  slanger_id = socket.get_sockname
    #  if slanger_id.nil?
    #    nil
    #  else
    #    port, ip = Socket.unpack_sockaddr_in(slanger_id) 
    #    "" + ip + ":" + port.to_s
    #  end
    #end
   
    # Run a MapReduce query to fill the slanger metrics collection from data
    def refresh_metrics()
      # Only run this on the master
      return if not Cluster.is_master?
      Fiber.new {
        Logger.debug log_message("Calculating metrics.")
        # Retrieve last timestamp
        f = Fiber.current
        resp = variables.find_one(_id: 'metrics.last_timestamp')
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
            out: {reduce: 'slanger.metrics.data'}
          }
        )
        # Save timestamp
        variables.update(
          {_id: 'metrics.last_timestamp'},
          {'$set' => {timestamp: new_timestamp}},
          {upsert: true}
        )
      }.resume
    end

    # Work data collection in Mongodb
    def work_data
      @work_data ||= Mongo.collection("slanger.metrics.work_data")
    end

    # Variables collection in Mongodb
    def variables
      @variables ||= Mongo.collection("slanger.metrics.variables")
    end

    # Metrics collection in Mongodb
    def metrics
      @metrics ||= Mongo.collection("slanger.metrics")
    end
  
    # Mongodb Map Reduce query to build metrics
    def map_function()
      <<-MAPFUNCTION
      function () {
        if (!this.connections) {
          return;
        }
        var timestamp = Math.round(Date.now() / 1000);
        // Emit app_id, nb conn, max conn and nb messages. 
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

    def log_message(message)
      "Node " + Cluster.node_id.to_s + ": " + message.to_s
    end

    extend self
  end
end
