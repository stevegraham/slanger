require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'

describe 'Integration' do
  let(:errback) { Proc.new { fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' } }

  def new_websocket
    EM::HttpRequest.new("ws://0.0.0.0:8080/app/#{Pusher.key}?client=js&version=1.8.5").
      get :timeout => 0
  end

  before(:each) do
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      require File.expand_path(File.dirname(__FILE__) + '/../../slanger.rb')
      Thin::Logging.silent = true
      Slanger::Config.load host: '0.0.0.0', api_port: '4567', websocket_port: '8080', app_key: '765ec374ae0a69f4ce44', secret: 'your-pusher-secret'
      Slanger::Service.run
    end
    # Give Slanger a chance to start
    sleep 0.4
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
      messages  = []

      Thread.new do
        EM.run do
          websocket = new_websocket

          websocket.errback &errback

          websocket.stream do |message|
            messages << message
            if messages.length < 2
              Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }
            else
              EM.stop
            end
          end

          websocket.callback do
            websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
          end

        end
      end.join

      # Slanger should send an object denoting connection was succesfully established
      JSON.parse(messages.first)['event'].should == 'pusher:connection_established'
      # Channel id should be in the payload
      JSON.parse(messages.first)['data']['socket_id'].should_not be_nil
      # Slanger should send out the message
      JSON.parse(messages.last)['event'].should == 'an_event'
      JSON.parse(messages.last)['data'].should == { some: 'data' }.to_json
    end

    it 'avoids duplicate events' do
      client1_messages, client2_messages  = [], []

      Thread.new do
        EM.run do
          client1 = new_websocket

          client1.callback do
            client1.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
          end

          client1.errback &errback

          client1.stream do |message|
            client1_messages << message

            client2 = new_websocket

            client2.callback do
              client2.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json)
            end

            client2.errback &errback

            client2.stream do |message|
              client2_messages << message
              if client2_messages.length < 2
                socket_id = JSON.parse(client1_messages.first)['data']['socket_id']
                Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: 'data' }, socket_id
              else
                EM.stop
              end
            end
          end
        end
      end.join

      client1_messages.size.should == 1
      JSON.parse(client2_messages.last)['event'].should == 'an_event'
      JSON.parse(client2_messages.last)['data'].should == { some: 'data' }.to_json
    end
  end

  describe 'private channels' do
    context 'with valid authentication credentials:' do
      it 'accepts the subscription request' do
        messages  = []

        Thread.new do
          EM.run do
            websocket = new_websocket

            websocket.errback &errback

            websocket.stream do |message|
              messages << JSON.parse(message)
              auth = Pusher['private-channel'].authenticate(messages.first['data']['socket_id'])[:auth]
              websocket.send({ event: 'pusher:subscribe', data: { channel: 'private-channel', auth: auth } }.to_json)
              EM.add_timer(0.1) { EM.stop }
            end

          end
        end.join

        # Slanger should send an object denoting connection was succesfully established
        messages.first['event'].should == 'pusher:connection_established'
        # Channel id should be in the payload
        messages.first['data']['socket_id'].should_not be_nil
        messages.length.should == 1
      end
    end

    context 'with bogus authentication credentials:' do
      it 'sends back an error message' do
        messages  = []

        Thread.new do
          EM.run do
            websocket = new_websocket

            websocket.errback &errback

            websocket.stream do |message|
              messages << JSON.parse(message)
              if messages.length < 2
                websocket.send({ event: 'pusher:subscribe', data: { channel: 'private-channel', auth: 'bogus' } }.to_json)
              else
                EM.stop
              end
            end

          end
        end.join

        # Slanger should send an object denoting connection was succesfully established
        messages.first['event'].should == 'pusher:connection_established'
        # Channel id should be in the payload
        messages.first['data']['socket_id'].should_not be_nil
        messages.last['event'].should == 'pusher:error'
        messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
        messages.length.should == 2
      end
    end
  end

  describe 'presence channels:' do
    context 'subscribing without channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = []

          Thread.new do
            EM.run do
              websocket = new_websocket

              websocket.errback &errback

              websocket.stream do |message|
                messages << JSON.parse(message)
                if messages.length < 2
                  websocket.send({ event: 'pusher:subscribe', data: { channel: 'presence-channel', auth: 'bogus' } }.to_json)
                else
                  EM.stop
                end
              end

            end
          end.join
          # Slanger should send an object denoting connection was succesfully established
          messages.first['event'].should == 'pusher:connection_established'
          # Channel id should be in the payload
          messages.first['data']['socket_id'].should_not be_nil
          messages.last['event'].should == 'pusher:error'
          messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
          messages.length.should == 2
        end
      end
    end

    context 'subscribing with channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = []

          Thread.new do
            EM.run do
              websocket = new_websocket

              websocket.errback &errback

              websocket.stream do |message|
                messages << JSON.parse(message)
                if messages.length < 2
                  websocket.send({
                    event: 'pusher:subscribe', data: {
                      channel: 'presence-channel', auth: 'bogus'
                    },
                    channel_data: {
                      user_id: '0f177369a3b71275d25ab1b44db9f95f',
                      user_info: {
                        name: 'SG'
                      }
                    }
                  }.to_json)
                else
                  EM.stop
                end
              end

            end
          end.join
          # Slanger should send an object denoting connection was succesfully established
          messages.first['event'].should == 'pusher:connection_established'
          # Channel id should be in the payload
          messages.first['data']['socket_id'].should_not be_nil
          messages.last['event'].should == 'pusher:error'
          messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
          messages.length.should == 2
        end
      end
      context 'with genuine authentication credentials'  do
        it 'sends back a success message' do
          messages  = []

          Thread.new do
            EM.run do
              websocket = new_websocket

              websocket.errback &errback

              websocket.stream do |message|
                messages << JSON.parse(message)
                if messages.length < 2
                  auth = Pusher['presence-channel'].authenticate(messages.first['data']['socket_id'], {
                    user_id: '0f177369a3b71275d25ab1b44db9f95f',
                    user_info: {
                       name: 'SG'
                    }
                  })
                  websocket.send({
                    event: 'pusher:subscribe', data: {
                      channel: 'presence-channel'
                    }.merge(auth)
                 }.to_json)
                else
                  EM.stop
                end
              end

            end
          end.join
          # Slanger should send an object denoting connection was succesfully established
          messages.first['event'].should == 'pusher:connection_established'
          # Channel id should be in the payload
          messages.length.should == 2
          messages.last.should == {"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded", "data"=>{"presence"=>{"count"=>1, "ids"=>["0f177369a3b71275d25ab1b44db9f95f"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}}
        end
        context 'with more than one subscriber subscribed to the channel' do
          it 'sends a member added message to the existing subscribers' do
            messages  = []

            Thread.new do
              EM.run do
                user1 = new_websocket
                user1.errback &errback

                user1.stream do |message|
                  messages << JSON.parse(message)
                  if messages.length == 1
                    auth = Pusher['presence-channel'].authenticate(messages.first['data']['socket_id'], {
                      user_id: '0f177369a3b71275d25ab1b44db9f95f',
                      user_info: {
                         name: 'SG'
                      }
                    })
                    user1.send({
                      event: 'pusher:subscribe', data: {
                        channel: 'presence-channel'
                      }.merge(auth)
                   }.to_json)
                  elsif messages.length == 2
                    user2 = new_websocket
                    user2.stream do |message|
                      auth2 = Pusher['presence-channel'].authenticate(JSON.parse(message)['data']['socket_id'], {
                        user_id: '37960509766262569d504f02a0ee986d',
                        user_info: {
                          name: 'CHROME'
                        }
                      })
                      user2.send({
                        event: 'pusher:subscribe', data: {
                          channel: 'presence-channel'
                        }.merge(auth2)
                      }.to_json)
                    end
                  elsif messages.length == 3
                    EM.stop
                  end
                end

              end
            end.join
            #puts messages.inspect
            # Slanger should send an object denoting connection was succesfully established
            messages.first['event'].should == 'pusher:connection_established'
            # Channel id should be in the payload
            messages.length.should == 3
            messages[1].should == {"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded", "data"=>{"presence"=>{"count"=>1, "ids"=>["0f177369a3b71275d25ab1b44db9f95f"], "hash"=>{"0f177369a3b71275d25ab1b44db9f95f"=>{"name"=>"SG"}}}}}
            messages.last.should == {"channel"=>"presence-channel", "event"=>"pusher_internal:member_added", "data"=>{"user_id"=>"37960509766262569d504f02a0ee986d", "user_info"=>{"name"=>"CHROME"}}}

          end

          it 'does not send multiple member added and member removed messages if one subscriber opens multiple connections, i.e. multiple browser tabs.' do
            messages  = []

            Thread.new do
              EM.run do
                user1 = new_websocket
                user1.errback &errback

                # setup our reference user
                user1.stream do |message|
                  messages << JSON.parse(message)
                  if messages.length == 1
                    auth = Pusher['presence-channel'].authenticate(messages.first['data']['socket_id'], {
                      user_id: '0f177369a3b71275d25ab1b44db9f95f',
                      user_info: {
                         name: 'SG'
                      }
                    })
                    user1.send({
                      event: 'pusher:subscribe', data: {
                        channel: 'presence-channel'
                      }.merge(auth)
                   }.to_json)
                  elsif messages.length == 2
                    10.times do
                      user = new_websocket
                      user.stream do |message|
                        # remove stream callback
                        user.stream do |message|
                          # close the connection in the next tick as soon as subscription is acknowledged
                          EM.next_tick { user.close_connection }
                        end
                        message = JSON.parse(message)
                        auth2 = Pusher['presence-channel'].authenticate(message['data']['socket_id'], {
                          user_id: '37960509766262569d504f02a0ee986d',
                          user_info: {
                            name: 'CHROME'
                          }
                        })
                        user.send({
                          event: 'pusher:subscribe', data: {
                            channel: 'presence-channel'
                          }.merge(auth2)
                        }.to_json)
                      end
                    end
                  elsif messages.length == 4
                    EM.next_tick { EM.stop }
                  end
                end

              end
            end.join

            # There should only be one set of presence messages sent to the refernce user for the second user.
            messages.one? { |message| message['event'] == 'pusher_internal:member_added'   && message['data']['user_id'] == '37960509766262569d504f02a0ee986d' }.should be_true
            messages.one? { |message| message['event'] == 'pusher_internal:member_removed' && message['data']['user_id'] == '37960509766262569d504f02a0ee986d' }.should be_true

          end
        end
      end
    end
  end
end
