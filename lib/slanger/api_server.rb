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

    post '/apps/:app_id/channels/:channel_id/events' do
      # authenticate request. exclude 'channel_id' and 'app_id' included by sinatra but not sent by Pusher.
      # Raises Signature::AuthenticationError if request does not authenticate.
      Signature::Request.new('POST', env['PATH_INFO'], params.except('channel_id', 'app_id')).
        authenticate { |key| Signature::Token.new key, Slanger::Config.secret }

      f = Fiber.current
      # Publish the event in Redis and translate the result into an HTTP
      # status to return to the client.
      Slanger.publish(params[:channel_id], payload).tap do |r|
        r.callback { f.resume [202, {}, "202 ACCEPTED\n"] }
        r.errback  { f.resume [500, {}, "500 INTERNAL SERVER ERROR\n"] }
      end
      Fiber.yield
    end

    def payload
      payload = {
        event:     params['name'],
        data:      request.body.read.tap{ |s| s.force_encoding('utf-8') },
        channel:   params[:channel_id],
        socket_id: params[:socket_id]
      }
      Hash[payload.reject { |_,v| v.nil? }].to_json
    end
  end
end

