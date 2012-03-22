require 'aquarium'
 
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
end
  
module Slanger
  module Statistics
    if Slanger::Config.statistics
      include Aquarium::DSL
  
      private
   
      # Increment the number of message for an application each time a message is dispatched into one
      # of its channels
      after :calls_to => :dispatch, :on_types => [Slanger::Channel, Slanger::PresenceChannel] do |join_point, channel, *args|
        # Update record
        statistics.update(
          {app_id: channel.application.id},
          {'$inc' => {nb_messages: 1}},
          {upsert: true}
        )
      end
  
      # Add new connections to an application to its list
      after :calls_to => :authenticate, :restricting_methods_to => :private, :on_type => Slanger::Handler do |join_point, handler, *args|
        application = handler.application
        unless application.nil?
          # Get peer's IP and port
          peername = get_peer_ip_port(handler.socket)
          # Save them so that we can remove them from mongo later
          handler.peername = peername
          # Get slanger_id if it exists or the listening IP and port
          slanger_id = Config.slanger_id || get_socket_ip_port(handler.socket)
          # Save them
          handler.slanger_id = slanger_id
          # Update record
          statistics.update(
            {app_id: application.id},
            {'$addToSet' => {collections: slanger_id + "-" + peername}},
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
          statistics.update(
            {app_id: application.id},
            {'$pull' => {collections: slanger_id + "-" + peername}},
            {upsert: true}
          )
        end
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
   
      # Statistics collection in Mongodb
      def statistics
        @statistics ||= Mongo.collection("slanger.applications.statistics")
      end
  
      extend self
    end
  end
end
