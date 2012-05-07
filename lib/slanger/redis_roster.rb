class RedisRoster
  def initialize channel_id
    @channel_id = channel_id
  end

  def get
    Fiber.new do
      f = Fiber.current
      Slanger::Redis.hgetall(channel_id).
        callback { |res| f.resume res }
      Fiber.yield
    end.resume
  end

  def add public_subscription_id, uuid
    Slanger::Redis.hset(channel_id, public_subscription_id, uuid)
  end

  def remove public_subscription_id
    Slanger::Redis.hdel(channel_id, public_subscription_id)
  end

  def publish_connection public_subscription_id, channel_data
    publish_connection_notification subscription_id: public_subscription_id,
      online: true,
      channel_data: channel_data,
      channel: channel_id
  end

  def publish_disconnection public_subscription_id
    publish_connection_notification subscription_id: public_subscription_id,
      online: false,
      channel: channel_id
  end

  private

  def publish_connection_notification(payload, retry_count=0)
    # Send a subscription notification to the global slanger:connection_notification
    # channel.
    Slanger::Redis.publish('slanger:connection_notification', payload.to_json).
      tap { |r| r.errback { publish_connection_notification payload, retry_count.succ unless retry_count == 5 } }
  end

  attr_reader :channel_id
end


