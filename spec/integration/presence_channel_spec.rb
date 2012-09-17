#encoding: utf-8
require 'spec_helper'

describe 'Integration' do

  before(:each) { start_slanger }

  describe 'presence channels:' do
    context 'subscribing without channel data' do
      context 'and bogus authentication credentials' do
        it 'sends back an error message' do
          messages  = em_stream do |websocket, messages|
            case messages.length
            when 1
              websocket.send({ event: 'pusher:subscribe', data: { channel: 'presence-channel', auth: 'bogus' } }.to_json)
            else
              EM.stop
            end
          end

          messages.should have_attributes connection_established: true, id_present: true,
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
            case messages.length
            when 1
               send_subscribe( user: websocket,
                               user_id: '0f177369a3b71275d25ab1b44db9f95f',
                               name: 'SG',
                               message: {data: {socket_id: 'bogus'}}.with_indifferent_access)
           else
              EM.stop
            end
          end

          messages.should have_attributes first_event: 'pusher:connection_established', count: 2,
            id_present: true

          # Channel id should be in the payload
          messages.last['event'].should == 'pusher:error'
          messages.last['data']['message'].=~(/^Invalid signature: Expected HMAC SHA256 hex digest of/).should be_true
        end
      end

      context 'with genuine authentication credentials'  do
        it 'sends back a success message' do
          messages  = em_stream do |websocket, messages|
            case messages.length
            when 1
              send_subscribe( user: websocket,
                              user_id: '0f177369a3b71275d25ab1b44db9f95f',
                              name: 'SG',
                              message: messages.first)
            else
              EM.stop
            end
          end

          messages.should have_attributes connection_established: true, count: 2

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

            messages.should have_attributes connection_established: true, count: 3
            # Channel id should be in the payload
            messages[1].should == {"channel"=>"presence-channel", "event"=>"pusher_internal:subscription_succeeded",
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
