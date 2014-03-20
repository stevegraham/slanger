# encoding: utf-8
require 'sinatra/base'
require 'signature'
require 'json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'fiber'
require 'rack/fiber_pool'

module Slanger
  class ApiServer < Sinatra::Base
    use Rack::FiberPool
    set :raise_errors, lambda { false }
    set :show_exceptions, false

    # Respond with HTTP 401 Unauthorized if request cannot be authenticated.
    error(Signature::AuthenticationError) { |c| halt 401, "401 UNAUTHORIZED\n" }

    post '/apps/:app_id/events' do
      authenticate

      # Event and channel data are now serialized in the JSON data
      # So, extract and use it
      data = JSON.parse(request.body.read.tap{ |s| s.force_encoding('utf-8')})

      # Send event to each channel
      data["channels"].each { |channel| publish(channel, data['name'], data['data']) }

      return {}.to_json
    end

    post '/apps/:app_id/channels/:channel_id/events' do
      authenticate

      publish(params[:channel_id], params['name'],  request.body.read.tap{ |s| s.force_encoding('utf-8') })

      return {}.to_json
    end

    def payload(channel, event, data)
      {
        event:     event,
        data:      data,
        channel:   channel,
        socket_id: params[:socket_id]
      }.select { |_,v| v }.to_json
    end

    def authenticate
      # authenticate request. exclude 'channel_id' and 'app_id' included by sinatra but not sent by Pusher.
      # Raises Signature::AuthenticationError if request does not authenticate.
      Signature::Request.new('POST', env['PATH_INFO'], params.except('captures', 'splat' , 'channel_id', 'app_id')).
        authenticate { |key| Signature::Token.new key, Slanger::Config.secret }
    end

    def publish(channel, event, data)
      f = Fiber.current

      # Publish the event in Redis and translate the result into an HTTP
      # status to return to the client.
      Slanger::Redis.publish(channel, payload(channel, event, data)).tap do |r|
        r.callback { f.resume [202, {}, "202 ACCEPTED\n"] }
        r.errback  { f.resume [500, {}, "500 INTERNAL SERVER ERROR\n"] }
      end

      Fiber.yield
    end

  end
end

