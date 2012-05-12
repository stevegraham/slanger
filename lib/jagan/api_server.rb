require 'sinatra/base'
require 'signature'
require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'fiber'
require 'rack/fiber_pool'

module Jagan
  class ApiServer < Sinatra::Base
    use Rack::FiberPool
    use Rack::CommonLogger, ::Logger.new(Config.api_log_file)
    set :raise_errors, lambda { false }
    set :show_exceptions, false

    # Respond with HTTP 401 Unauthorized if request cannot be authenticated.
    error(Signature::AuthenticationError) { 
      |c| halt 401, "401 UNAUTHORIZED\n"
    }

    post '/apps/:app_id/channels/:channel_id/events' do
      # Retrieve application
      application = Applications[params[:app_id]]
      # Return a 404 error code if app is unknown
      return [404, {}, "404 NOT FOUND\n"] if application.nil?
      # authenticate request. exclude 'channel_id' and 'app_id' included by sinatra but not sent by Pusher.
      # Raises Signature::AuthenticationError if request does not authenticate.
      begin
        Signature::Request.new('POST', env['PATH_INFO'], params.except('channel_id', 'app_id')).
        authenticate { |key| Signature::Token.new key, application.secret }
      rescue Signature::AuthenticationError
        Logger.error log_message("Signature authentication error.")
        raise
      end

      f = Fiber.current
      # Publish the event in Redis and translate the result into an HTTP
      # status to return to the client.
      Jagan::Redis.publish(application.id + ":" + params[:channel_id], payload).tap do |r|
        r.callback { 
          Logger.debug log_message("Successfully published to Redis.")
          f.resume [202, {}, "202 ACCEPTED\n"] 
        }
        r.errback  { 
          Logger.error log_message("Redis error.")
          f.resume [500, {}, "500 INTERNAL SERVER ERROR\n"] 
        }
      end
      Fiber.yield
    end

    def payload
      payload = {
        event: params['name'], data: request.body.read, channel: params[:channel_id], socket_id: params[:socket_id], app_id: params[:app_id]
      }
      Hash[payload.reject { |k,v| v.nil? }].to_json
    end

    def log_message(msg)
      msg + " app_id: " + params[:app_id] + " channel_id: " + params[:channel_id]
    end
  end
end

