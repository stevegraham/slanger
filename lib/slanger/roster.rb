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

  def add key, value
    Slanger::Redis.hset(channel_id, key, value)
  end

  def remove key
    Slanger::Redis.hdel(channel_id, key)
  end

  private
  attr_reader :channel_id
end


