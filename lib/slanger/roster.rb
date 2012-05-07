class Roster
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

  private
  attr_reader :channel_id
end


