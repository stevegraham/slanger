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
require 'uri'

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
    # Metrics
    #################################

    # GET /applications/metrics.json - return all application metrics
    get '/applications/metrics.json', :provides => :json do
      content_type :json
      protected!
      # Retrieve all the application metrics
      metrics = Metrics.get_all_metrics()

      return [404, {}, "404 NOT FOUND\n"] if metrics.nil?
      return [200, {}, metrics.to_json]
    end

    # GET /applications/metrics/:app_id.json - return application metrics for app with specified id
    get '/applications/metrics/:app_id.json', :provides => :json do
      content_type :json
      protected!
      # Retrieve the application metrics
      metrics = Metrics.get_metrics_for(params[:app_id].to_i)

      return [404, {}, "404 NOT FOUND\n"] if metrics.nil?
      return [200, {}, metrics['value'].to_json]
    end

    #################################
    # Application REST API
    #################################
    
    # GET /applications.json- return all applications
    get '/applications.json', :provides => :json do
      content_type :json
      protected!
      apps = Application.all
      return [404, {}, "404 NOT FOUND\n"] if apps.nil?
      return [200, {}, apps.collect do |app| map_id(app) end.to_json]
    end

    # GET /applications/:app_id.json - return application with specified id
    get '/applications/:app_id.json', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      return [200, {}, map_id(app).to_json]
    end

    # POST /applications.json - create new application
    post '/applications.json', :provides => :json  do
      content_type :json
      protected!
      app = Application.create_new
      headers["Location"] = "/applications/#{app.app_id}"
      status 201
      map_id(app).to_json
    end

    # PUT /applications/:app_id/generate_new_token.json - generate new key and secret for application.
    put '/applications/:app_id/generate_new_token.json', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      app.generate_new_token!
      map_id(app).to_json
    end

    # PUT /applications/:app_id.json - modify app
    put '/applications/:app_id.json', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      begin
        data = JSON.parse(request.body.string)
        # Disallows changing the key
        return [403, {}, "Modification of the key is forbidden\n"] if data['key'] != app.key
        return [403, {}, "Modification of the secret is forbidden\n"] if data['secret'] != app.secret
        if data['webhook_url'] != app.webhook_url
          # Modify the webhook URL
          app.webhook_url = data['webhook_url']
        end
      rescue JSON::ParserError
        return [400, {}, "Invalid JSON data\n"]        
      end
      app.save
      status 204
    end

    # DELETE /applications/:app_id.json - delete application
    delete '/applications/:app_id.json', :provides => :json do
      content_type :json
      protected!
      app = Application.find_by_app_id(params[:app_id].to_i)
      return [404, {}, "404 NOT FOUND\n"] if app.nil?
      app.destroy
      status 204
    end

    # Change app_id into id in REST results to play well with Activeresource
    def map_id(app)
      {id: app.app_id, key: app.key, secret: app.secret, webhook_url: app.webhook_url}
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
