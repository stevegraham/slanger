require 'sinatra'
require 'haml'
require 'pusher'
require 'digest/md5'
require 'thin'
require 'json'

set :views, File.dirname(__FILE__) + '/templates'
set :port,  3001

enable :sessions

Pusher.app_id  = '8792'
Pusher.key     = '5ad8640c9b11e84cc60a'
Pusher.secret  = '11a872de453861e042a9'

Thread.new do
  loop do
    Pusher['MY_CHANNEL'].trigger 'an_event', color: "##{rand(16777216).to_s 16}"
  end
end

get '/' do
  @channel = "MY_CHANNEL"
  haml :index_pusher
end

get '/chat' do
  @use_pusher = true
  @channel    = "presence-channel"
  if session[:current_user]
    haml :chat_room
  else
    haml :chat_lobby
  end
end

post '/chat' do
  if session[:current_user]
    Pusher['presence-channel'].trigger_async('chat_message', {
      sender: session[:current_user], body: params['message']
    })
    request.xhr? ? status(201) : redirect('/chat')
  else
    status 403
  end
end

post '/identify' do
  session[:current_user] = params['handle']
  redirect request.referer
end

post '/pusher/auth' do
  Pusher[params['channel_name']].authenticate(params['socket_id'], {
    user_id: Digest::MD5.hexdigest(session[:current_user]),
    user_info: {
      name: session[:current_user]
    }
  }).to_json
end
