require 'securerandom'

module Slanger
  module Cluster

    def is_master?()
      @master_id == node_id
    end

    # Returns a unique identifier for this node
    def node_id()
      @node_id ||= Config.slanger_id || SecureRandom.uuid
    end

    # Enter the cluster 
    def enter()
      # Subscribe to the slanger:cluster Redis channel,
      # it is used for cluster messages broadcasts.
      Slanger::Redis.subscribe 'slanger:cluster'
      Logger.debug log_message("Subscribed to Redis channel: slanger:cluster")
      Logger.info log_message("Entering cluster.")
      # Ask the cluster which node is the master
      send_enquiry
    end

    def leave()
      Logger.info log_message("Leaving cluster.")
    end

    # Process a cluster message
    def process_message(message)
      # Extract fields from message
      begin
        data = JSON.parse message
      rescue JSON::ParserError
        Logger.error log_message("JSON Parse error on cluster message: '" + msg + "'")
        return        
      end
      sender = data['sender']
      return if sender == node_id # Ignore own messages
      destination = data['destination']
      if (destination.nil? || destination == node_id)
        # This is a broadcast, or a message to our node, we need to process it
        event = data['event'].to_sym
        if event == :election_enquiry && is_master? && sender < node_id
          # We are the master, and the enquirer doesn't have an node_id
          # higher than us. Reply to this enquiry telling it we are the master.
          Logger.debug log_message"Sending master enquiry reply to: " + sender
          send_enquiry_reply(sender)
        elsif event == :election_enquiry_reply && sender > node_id
          # The master replied, accept it
          accept_master(sender)
        elsif event == :election_victory && sender < node_id
          # Some node claims to be the master, but its node_id is lower than ours ;
          # Tell all nodes we are the real master.
          Logger.info log_message"Another node claimed to be the master: " + sender + ". Sending new victory message to correct it."
          send_victory
        elsif event == :election_victory && sender > node_id && (sender > master_id || master_last_seen_unix_timestamp < Time.now.to_i - 60)
          # Some node claims to be the master, and its node_id is greater than ours
          # and its node_id is greater than the currently known master, or the master is
          # outdated. Accept the node as new master
          accept_master(sender)
        elsif event == :master_alive && sender == master_id 
          # Master is alive
          @master_last_seen_unix_timestamp = Time.now.to_i      
          refesh_master_timeout
        end
      end
    end

    private

    # The node_id of the current master
    def master_id()
      @master_id ||= ""
    end

    # Sends a cluster message
    def send_message(event, payload = nil, destination = nil)
      Redis.publish('slanger:cluster', {sender: node_id, destination: destination, event: event, payload: payload}.to_json)
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
      # Send election enquiry message. The master will reply if its node_id is greater than this node's
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

    def become_master()
      @master_id = node_id
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
      "Node " + node_id.to_s + ": " + message.to_s
    end

    extend self
  end
end
