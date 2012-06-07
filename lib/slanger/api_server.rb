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
    use Rack::CommonLogger, Config.api_log_file
    set :raise_errors, lambda { false }
    set :show_exceptions, false

    #################################
    # Pusher API
    #################################

    # Respond with HTTP 401 Unauthorized if request cannot be authenticated.
    error(Signature::AuthenticationError) { |c| halt 401, "401 UNAUTHORIZED\n" }

    post '/apps/:app_id/channels/:channel_id/events' do
      # Retrieve application
      application = Application.find_by_app_id(params[:app_id].to_i)
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
      Slanger::Redis.publish(application.app_id.to_s + ":" + params[:channel_id], payload).tap do |r|
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
        event:     params['name'],
        data:      request.body.read.tap{ |s| s.force_encoding('utf-8') },
        channel:   params[:channel_id],
        socket_id: params[:socket_id],
        app_id: params[:app_id]
      }
      Hash[payload.reject { |_,v| v.nil? }].to_json
    end

    def log_message(msg)
      msg + " app_id: " + params[:app_id].to_s + " channel_id: " + params[:channel_id].to_s
    end


    #################################
    # Application REST API
    #################################
    
    # GET /applications - return all applications
    get '/applications/?', :provides => :json do
      content_type :json
      protected!
      apps = Application.all
      return [404, {}, "404 NOT FOUND\n"] if apps.nil?
      return [200, {}, apps.to_json]
    end

    # GET /applications/:app_id - return application with specified id
    get '/applications/:app_id', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      return [200, {}, app.to_json]
    end

    # POST /applications - create new application
    post '/applications/?', :provides => :json  do
      content_type :json
      protected!
      app = Application.create_new
      headers["Location"] = "/applications/#{app.app_id}"
      status 201
      app.to_json
    end

    # POST /applications/:app_id/generate_new_token - generate new key and secret for application.
    post '/applications/:app_id/generate_new_token', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      app.generate_new_token!
      app.save
      app.to_json
    end

    # DELETE /applications/:app_id - delete application
    delete '/applications/:app_id', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      app.destroy
      status 204
    end

    # Authenticate requests
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    # authorise HTTP users for the API calls
    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [Config.admin_http_user, Config.admin_http_password]
    end
  end
end
