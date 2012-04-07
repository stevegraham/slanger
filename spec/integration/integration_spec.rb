require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'
require './spec/spec_helper'

describe 'Integration' do
  let(:errback) { Proc.new { fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' } }

  before(:each) do
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      require File.expand_path(File.dirname(__FILE__) + '/../../slanger.rb')
      Thin::Logging.silent = true

      Slanger::Config.load host:           '0.0.0.0',
                           api_port:       '4567',
                           websocket_port: '8080',
                           app_key:        '765ec374ae0a69f4ce44',
                           secret:         'your-pusher-secret'

      Slanger::Service.run
    end
    # Give Slanger a chance to start
    sleep 0.6
  end

  after(:each) do
    # Ensure Slanger is properly stopped. No orphaned processes allowed!
    Process.kill 'SIGKILL', @server_pid
    Process.wait @server_pid
  end

  before :all do
    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = 'your-pusher-app-id'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end


  describe 'regular channels:' do
    it 'pushes messages to interested websocket connections' do
      messages = em_stream do |websocket, messages|
        websocket.callback do
          websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
        end if messages.one?

        if messages.length < 3
          Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }
        else
          EM.stop
        end

     end

      matcher messages, connection_established: true, id_present: true,
        last_event: 'an_event', last_data: { some: 'data' }.to_json
    end

    it 'avoids duplicate events' do
      client2_messages  = []

      client1_messages = em_stream do |client1, client1_messages|
        # if this is the first message to client 1 set up another connection from the same client
        if client1_messages.one?
          client1.callback do
            client1.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
          end

          client2_messages = em_stream do |client2, client2_messages|
            client2.callback do
              client2.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
            end if client2_messages.one?

            if client2_messages.length < 3
              socket_id = client1_messages.first['data']['socket_id']
              Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }, socket_id
            else
              EM.stop
            end
          end
        end
      end

      matcher client1_messages, count: 2

      matcher client2_messages, last_event: 'an_event'
      client2_messages.last['data'].should == { some: 'data' }.to_json
    end
  end

  def private_channel websocket, message
    auth = Pusher['private-channel'].authenticate(message['data']['socket_id'])[:auth]
    websocket.send({ event: 'pusher:subscribe',
                     data: { channel: 'private-channel',
               auth: auth } }.to_json)

  end

  describe 'private channels' do
    context 'with valid authentication credentials:' do
      it 'accepts the subscription request' do
        messages  = em_stream do |websocket, messages|
          if messages.empty?
            private_channel websocket, messages.first
         else
            EM.stop
          end
        end

        matcher messages, first_event: 'pusher:connection_established', id_present: true
        messages.length.should == 1
      end
    end

    context 'with bogus authentication credentials:' do
      it 'sends back an error message' do
        messages  = em_stream do |websocket, messages|
          if messages.length < 2
            websocket.send({ event: 'pusher:subscribe',
                             data: { channel: 'private-channel',
                                     auth: 'bogus' } }.to_json)
          else
            EM.stop
          end
        end

        # Slanger should send an object denoting connection was succesfully established
        messages.first['event'].should == 'pusher:connection_established'
        # Channel id should be in the payload
        messages.first['data']['socket_id'].should_not be_nil
        messages.last['event'].should == 'pusher:error'
        messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
        messages.length.should == 2
      end
    end



    describe 'client events' do
      it "sends event to other channel subscribers" do
        client1_messages, client2_messages  = [], []

        em_thread do
          client1, client2 = new_websocket, new_websocket
          client2_messages, client1_messages = [], []

          client1.callback {}

          stream(client1, client1_messages) do |message|
            if client1_messages.length < 2
              private_channel client1, client1_messages.first
            elsif client1_messages.length == 3
              EM.stop
            end
          end

          client2.callback {}

          stream(client2, client2_messages) do |message|
            if client2_messages.length < 2
              private_channel client2, client2_messages.first
            else
              client2.send({ event: 'client-something', data: { some: 'stuff' }, channel: 'private-channel' }.to_json)
            end
          end
        end

        client1_messages.none? { |m| m['event'] == 'client-something' }
        client2_messages.one?  { |m| m['event'] == 'client-something' }
      end
    end
  end

  describe 'presence channels:' do
    context 'subscribing without channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = em_stream do |websocket, messages|
            if messages.length < 2
              websocket.send({ event: 'pusher:subscribe', data: { channel: 'presence-channel', auth: 'bogus' } }.to_json)
            else
              EM.stop
            end
          end

          matcher messages, connection_established: true, id_present: true,
            count: 2,
            last_event: 'pusher:error'

          messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
        end
      end
    end

    context 'subscribing with channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = em_stream do |websocket, messages|
            if messages.length < 2
               send_subscribe( user: websocket,
                               user_id: '0f177369a3b71275d25ab1b44db9f95f',
                               name: 'SG',
                               message: {data: {socket_id: 'bogus'}}.with_indifferent_access)

           else
              EM.stop
            end
          end

          matcher messages, first_event: 'pusher:connection_established', count: 2,
            id_present: true

          # Channel id should be in the payload
          messages.last['event'].should == 'pusher:error'
          messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
        end
      end

      context 'with genuine authentication credentials'  do
        it 'sends back a success message' do
          messages  = em_stream do |websocket, messages|
            if messages.length < 2
              send_subscribe( user: websocket,
                              user_id: '0f177369a3b71275d25ab1b44db9f95f',
                              name: 'SG',
                              message: messages.first)
           else
              EM.stop
            end

          end

          matcher messages, connection_established: true, count: 2

          messages.last.should == {"channel"=>"presence-channel",
                                   "event"=>"pusher_internal:subscription_succeeded",
                                   "data"=>{"presence"=>
                                            {"count"=>1,
                                             "ids"=>["0f177369a3b71275d25ab1b44db9f95f"],
                                             "hash"=>
                                            {"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}}
        end




        context 'with more than one subscriber subscribed to the channel' do
          it 'sends a member added message to the existing subscribers' do
            messages  = em_stream do |user1, messages|
              case messages.length
              when 1
                send_subscribe(user: user1,
                               user_id: '0f177369a3b71275d25ab1b44db9f95f',
                               name: 'SG',
                               message: messages.first
                              )

              when 2
                new_websocket.tap do |u|
                  u.stream do |message|
                    send_subscribe({user: u,
                      user_id: '37960509766262569d504f02a0ee986d',
                      name: 'CHROME',
                      message: JSON.parse(message)})
                  end
                end
              else
                EM.stop
              end

            end
            matcher messages, connection_established: true, count: 3
            # Channel id should be in the payload
            messages[1].  should == {"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded",
                                     "data"=>{"presence"=>{"count"=>1, "ids"=>["0f177369a3b71275d25ab1b44db9f95f"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}}

            messages.last.should == {"channel"=>"presence-channel", "event"=>"pusher_internal:member_added",
                                     "data"=>{"user_id"=>"37960509766262569d504f02a0ee986d", "user_info"=>{"name"=>"CHROME"}}}
          end

          it 'does not send multiple member added and member removed messages if one subscriber opens multiple connections, i.e. multiple browser tabs.' do
            messages  = em_stream do |user1, messages|
              case messages.length
              when 1
                send_subscribe(user: user1,
                               user_id: '0f177369a3b71275d25ab1b44db9f95f',
                               name: 'SG',
                               message: messages.first)

              when 2
                10.times do
                  new_websocket.tap do |u|
                    u.stream do |message|
                      # remove stream callback
                      ## close the connection in the next tick as soon as subscription is acknowledged
                      u.stream { EM.next_tick { u.close_connection } }

                      send_subscribe({ user: u,
                         user_id: '37960509766262569d504f02a0ee986d',
                         name: 'CHROME',
                         message: JSON.parse(message)})
                    end
                  end
                end
              when 4
                EM.next_tick { EM.stop }
              end

            end

            # There should only be one set of presence messages sent to the refernce user for the second user.
            messages.one? { |message| message['event'] == 'pusher_internal:member_added'   && message['data']['user_id'] == '37960509766262569d504f02a0ee986d' }.should be_true
            messages.one? { |message| message['event'] == 'pusher_internal:member_removed' && message['data']['user_id'] == '37960509766262569d504f02a0ee986d' }.should be_true

          end
        end
      end
    end
  end
end
