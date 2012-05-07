class RedisRoster
  def initialize channel_id
    @channel_id = channel_id
  end

  def subscribe channel_data
    public_subscription_id = SecureRandom.uuid

    add                public_subscription_id, channel_data
    publisher = publish_connection public_subscription_id, channel_data

    return publisher, public_subscription_id
  end

  def unsubscribe public_subscription_id
    remove                             public_subscription_id
    internal_subscription_table.delete public_subscription_id # if internal_subscription_table[public_subscription_id]
    publish_disconnection              public_subscription_id
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

  def update_internal_table public_subscription_id, internal_id
    internal_subscription_table[public_subscription_id] = internal_id
  end
  private

  def publish_connection_notification(payload, retry_count=0)
    # Send a subscription notification to the global slanger:connection_notification
    # channel.
    Slanger::Redis.publish('slanger:connection_notification', payload.to_json).
      tap { |r| r.errback { publish_connection_notification payload, retry_count.succ unless retry_count == 5 } }
  end

  attr_reader :channel_id


  # This is used map public subscription ids to em channel subscription ids.
  # em channel subscription ids are incremented integers, so they cannot
  # be used as keys in distributed system because they will not be unique
  def internal_subscription_table
    @internal_subscription_table ||= {}
  end


end


