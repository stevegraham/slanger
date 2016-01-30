require 'spec_helper'
require 'slanger'
require 'oj'

def clear_redis_connections
  Slanger::Redis.instance_variables.each do |ivar|
    Slanger::Redis.send :remove_instance_variable, ivar
  end
end

describe 'Slanger::Channel' do
  let(:channel) { Slanger::Channel.create channel_id: 'test' }

  before(:each) do
    EM::Hiredis.stubs(:connect).returns stub_everything('redis', :pubsub => stub_everything('redis'))
    clear_redis_connections
  end

  after(:each) do
    clear_redis_connections
    EM::Hiredis.unstub(:connect)
  end

  describe '#unsubscribe' do
    it 'decrements channel subscribers on Redis' do
      Slanger::Redis.expects(:hincrby).
        with('channel_subscriber_count', channel.channel_id, -1).
        once.returns mock { expects(:callback).once.yields(2) }

      channel.unsubscribe 1
    end

    it 'activates a webhook when the last subscriber of a channel unsubscribes' do
      Slanger::Webhook.expects(:post).
        with(name: 'channel_vacated', channel: channel.channel_id).
        once

      Slanger::Redis.expects(:hincrby).
        with('channel_subscriber_count', channel.channel_id, -1).
        times(3).returns mock {
          expects(:callback).times(3).yields(2).then.yields(1).then.yields(0)
        }

      3.times { |i| channel.unsubscribe i + 1 }
    end
  end

  describe '#subscribe' do
    it 'increments channel subscribers on Redis' do
      Slanger::Redis.expects(:hincrby).
        with('channel_subscriber_count', channel.channel_id, 1).
        once.returns mock { expects(:callback).once.yields(2) }
      channel.subscribe { |m| nil }
    end

    it 'activates a webhook when the first subscriber of a channel joins' do
      Slanger::Webhook.expects(:post).
        with(name: 'channel_occupied', channel: channel.channel_id).
        once

      Slanger::Redis.expects(:hincrby).
        with('channel_subscriber_count', channel.channel_id, 1).
        times(3).returns mock {
          expects(:callback).times(3).yields(1).then.yields(2).then.yields(3)
        }

      3.times { channel.subscribe { |m| nil } }
    end
  end

  describe '#dispatch' do
    it 'activates a webhook when client events are received' do
      message = {
        'event'     => 'client-test_event',
        'channel'   => 'private-test_channel',
        'socket_id' => '8.422225',
        'data'      => { 'key' => 'value' }
      }

      expected_params = message.merge({
        'name' => 'client_event',
        'data' => Oj.dump(message['data'])
      })

      Slanger::Webhook.expects(:post).
        with(expected_params).
      once

      channel.dispatch(message, 'private-test_channel')
    end

    it 'does not activate a webhook when non-client event messages are received' do
      message = {
        'event'     => 'non_client_event',
        'channel'   => 'private-test_channel',
        'socket_id' => '8.422225',
        'data'      => { 'key' => 'value' }
      }

      Slanger::Webhook.expects(:post).never

      channel.dispatch(message, 'private-test_channel')
    end
  end
end
