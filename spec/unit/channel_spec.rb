require 'spec/spec_helper'
require 'slanger'

describe 'Application webhooks' do
  let(:application) { 
    Slanger::Application.create({
      app_id: 1,
      key: '765ec374ae0a69f4ce44',
      secret: 'your-pusher-secret'
    })
  }
  let(:channel) { application.channel_from_id 'test_channel' }

  before(:all) do
    EM::Hiredis.stubs(:connect).returns stub_everything('redis')
  end

  after(:all) do
    EM::Hiredis.unstub(:connect)
  end

  describe '#unsubscribe' do
    it 'decrements channel subscribers on Redis' do
      Slanger::Redis.expects(:hincrby).
        with('1:test_channel:channel_subscriber_count', channel.channel_id, -1).
        once.returns mock { expects(:callback).once.yields(2) }

      channel.unsubscribe 1
    end

    it 'activates a webhook when the last subscriber of a channel unsubscribes' do
      application.expects(:post_to_webhook).
        with(name: 'channel_vacated', channel: channel.channel_id).
        once

      Slanger::Redis.expects(:hincrby).
        with('1:test_channel:channel_subscriber_count', channel.channel_id, -1).
        times(3).returns mock {
          expects(:callback).times(3).yields(2).then.yields(1).then.yields(0)
        }

      3.times { |i| channel.unsubscribe i + 1 }
    end
  end

  describe '#subscribe' do
    it 'increments channel subscribers on Redis' do
      Slanger::Redis.expects(:hincrby).
        with('1:test_channel:channel_subscriber_count', channel.channel_id, 1).
        once.returns mock { expects(:callback).once.yields(2) }
      channel.subscribe { |m| nil }
    end

    it 'activates a webhook when the first subscriber of a channel joins' do
      application.expects(:post_to_webhook).
        with(name: 'channel_occupied', channel: channel.channel_id).
        once

      Slanger::Redis.expects(:hincrby).
        with('1:test_channel:channel_subscriber_count', channel.channel_id, 1).
        times(3).returns mock {
          expects(:callback).times(3).yields(1).then.yields(2).then.yields(3)
        }

      3.times { channel.subscribe { |m| nil } }
    end
  end
end
