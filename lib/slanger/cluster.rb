require 'aquarium'
require 'singleton'
require 'socket'

module Slanger
  class ClusterSingleton
    include Singleton
    if Slanger::Config.cluster
      include Aquarium::DSL

      def is_master?()
        @master_id == id
      end

      def id()
        # Returns a unique identifier for this node
        Config.slanger_id
      end
 
      def start()
        Slanger::Redis.subscribe 'slanger:cluster'
        Logger.debug log_message("Subscribed to Redis channel: slanger:cluster")
        Logger.info log_message("Entering cluster.")
        # Ask which node is the master
        send_enquiry
      end

      def stop()
        Logger.info log_message("Leaving cluster.")
      end

      def process_message(message)
        # Extract fields from message
        begin
          data = JSON.parse message
        rescue JSON::ParserError
          Logger.error log_message("JSON Parse error on cluster message: '" + msg + "'")
          return        
        end
        message_clock = data['clock'].to_i
        if message_clock > clock 
          @clock = message_clock  # Update our clock        
        end
        sender = data['sender']
        if sender == id
          # Ignore own messages
        end
        destination = data['destination']
        if (destination.nil? || destination == id)
          event = data['event'].to_sym
          if event == :election_enquiry && is_master? && sender < id
            # We are the master, and the enquirer doesn't have an id
            # higher than us. Reply to this enquiry telling it we are the master.
            Logger.debug log_message"Sending master enquiry reply to: " + sender
            send_enquiry_reply(sender)
          elsif event == :election_enquiry_reply && sender > id
            # The master replied
            accept_master(sender)
          elsif event == :election_victory && sender < id
            # Some node claims to be the master, but its id is lower than ours
            # Tell all nodes we are the real master
            Logger.info log_message"Another node claimed to be the master: " + sender + ". Sending new victory message to correct it."
            send_victory
          elsif event == :election_victory && sender > id && (sender > master_id || master_last_seen_unix_timestamp < Time.now.to_i - 60)
            # Some node claims to be the master, and its id is greater than ours
            # and its id is greater than the current master, or the master is
            # outdated. Accept the node as new master
            accept_master(sender)
          elsif event == :master_alive && sender == master_id 
            @master_last_seen_unix_timestamp = Time.now.to_i      
            refesh_master_timeout
          end
        end
      end

      private

      ##############################################
      # Aspects
      ##############################################

      # On startup, subscribe to Redis for cluster messages
      after :calls_to => :run, :for_object => Slanger::Service do |join_point, service, *args|
        Cluster.start()
      end

      # Process cluster messages
      around :calls_to => :on_message, :restricting_methods_to => :private, :for_object => Slanger::Redis do |join_point, redis, *args|
        (channel, message) = args
        if channel == 'slanger:cluster'
          begin
            Cluster.process_message(message)
          rescue Exception => ex
            Logger.error("An exception occured: " + ex.to_s)
            Logger.error("Stack trace: " + ex.backtrace.to_s)
          end
        else
          join_point.proceed
        end
      end

      # TODO: On stop, leave the cluster
      #before :calls_to => :stop, :for_object => Slanger::Service do |join_point, service, *args|
      #  puts "TODO"
      #end

      ############################################
      # Cluster
      ############################################

      # The id of the current master
      def master_id()
        @master_id ||= ""
      end

      # Message sending
      def send_message(event, payload = nil, destination = nil)
        @clock = clock + 1
        Redis.publish('slanger:cluster', {clock: clock, sender: id, destination: destination, event: event, payload: payload}.to_json)
      end

      # The last time a "election victory" occured. 
      # Upon receiving a new election victory, if the last one is old we forget the old master
      # If he's still around and still the highest key he'll send a fresh election
      # victory anyway.
      def master_last_seen_unix_timestamp()
        @master_last_seen_unix_timestamp ||= 0
      end

      # Master election messages, as described
      # in http://en.wikipedia.org/wiki/Bully_algorithm
      def send_enquiry()
        # Send election enquiry message. The master will reply if its id is greater than this node's
        send_message(:election_enquiry)
        # Wait for the master's response for a few seconds
        @master_response_timeout = EM::Timer.new(5) do
          # No response, asume we are the master
          Logger.info log_message("No response from the master, claiming to be the master.")
          become_master
        end
      end

      # Reply to enquiry. Sent by the master if its key is greater than the enquirer's
      def send_enquiry_reply(enquirer)
        send_message(:election_enquiry_reply, nil, enquirer)
      end

      # Victory message, sent by a node which believe it is the master.
      # if another has a greater key, it will send a victory message in return.
      # At the end the node with the greatest key will be the master
      def send_victory()
        send_message(:election_victory)
     end

      def clock()
        @clock ||= 0        
      end

      def become_master()
        @master_id = id
        send_victory
        # Start sending "alive" messages so that other nodes can detect
        # when the master disapears
        @alive_timer.cancel unless @alive_timer.nil?
        @alive_timer = EM::PeriodicTimer.new(1) do
          send_message(:master_alive)
        end
 
      end

      def accept_master(newmaster)
        @master_id = newmaster
        @master_last_seen_unix_timestamp = Time.now.to_i
        # Cancel our timeout
        @master_response_timeout.cancel unless @master_response_timeout.nil?
        @master_response_timeout = nil
        Logger.info log_message("Master is: " + master_id)
        # Stop sending "alive" event if we were master
        @alive_timer.cancel unless @alive_timer.nil?
        @alive_timer = nil
        refesh_master_timeout
      end

      def refesh_master_timeout()
        # After some time without "alive" messages, replace master
        @master_alive_timeout.cancel unless @master_alive_timeout.nil?
        @master_alive_timeout = EM::Timer.new(5) do
          Logger.info log_message("No alive message from the master, claiming to be the master.")
          # No sign the master is alive, asume we are the master, thus starting a new election
          become_master
        end
      end

      def log_message(message)
        "Node " + id + ": " + message
      end
   end
  end

  Cluster = ClusterSingleton.instance
end
