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
    error(Signature::AuthenticationError) { |e| halt 401, "401 UNAUTHORIZED: #{e}" }

    post '/apps/:app_id/events' do
      rv = RequestValidation.new(body, params)
      socket_id = rv.socket_id
      data = rv.data

      authenticate
      # Event and channel data are now serialized in the JSON data
      # So, extract and use it
      # Send event to each channel
      data["channels"].each { |channel| publish(channel, data['name'], data['data'], socket_id) }

      status 202
      return {}.to_json
    end

    def body
      @body ||= request.body.read.tap{|s| s.force_encoding("utf-8")}
    end

    post '/apps/:app_id/channels/:channel_id/events' do
      rv = RequestValidation.new(body)
      socket_id = rv.socket_id
      data = rv.data


      authenticate
      params = rv.user_params

      publish(params[:channel_id], params['name'],  body)

      status 202
      return {}.to_json
    end

    def payload(channel, event, data, socket_id)
      {
        event:     event,
        data:      data,
        channel:   channel,
        socket_id: socket_id
      }.select { |_,v| v }.to_json
    end

    def authenticate
      # authenticate request. exclude 'channel_id' and 'app_id' included by sinatra but not sent by Pusher.
      # Raises Signature::AuthenticationError if request does not authenticate.
      Signature::Request.new('POST', env['PATH_INFO'], params.except('captures', 'splat' , 'channel_id', 'app_id')).
        authenticate { |key| Signature::Token.new key, Slanger::Config.secret }
    end

    def publish(channel, event, data, socket_id)
      Slanger::Redis.publish(channel, payload(channel, event, data, socket_id))
    end
  end
end
