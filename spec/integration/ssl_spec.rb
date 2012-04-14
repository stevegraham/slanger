require 'bundler/setup'

require 'eventmachine'
require 'thin'
require './spec/spec_helper'
require 'openssl'
require 'socket'

describe 'Integration' do
  let(:errback) { Proc.new { fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' } }

  before(:each) do
    # Fork service. Our integration tests MUST block the main thread because we want to wait for i/o to finish.
    @server_pid = EM.fork_reactor do
      require File.expand_path(File.dirname(__FILE__) + '/../../slanger.rb')
      Thin::Logging.silent = true

      Slanger::Config.load host:             '0.0.0.0',
                           api_port:         '4567',
                           websocket_port:   '8080',
                           app_key:          '765ec374ae0a69f4ce44',
                           secret:           'your-pusher-secret',
                           tls_options: {
                             cert_chain_file:  'spec/server.crt',
                             private_key_file: 'spec/server.key'
                           }

      Slanger::Service.run
    end
    # Give Slanger a chance to start
    sleep 0.6
  end

  after(:each) do
    # Ensure Slanger is properly stopped. No orphaned processes allowed!
    Process.kill 'SIGKILL', @server_pid
    Process.wait @server_pid
  end

  before :all do
    Pusher.tap do |p|
      p.host   = '0.0.0.0'
      p.port   = 4567
      p.app_id = 'your-pusher-app-id'
      p.secret = 'your-pusher-secret'
      p.key    = '765ec374ae0a69f4ce44'
    end
  end

  describe 'Slanger when configured to use SSL' do
    it 'encrypts the connection' do
      socket                 = TCPSocket.new('0.0.0.0', 8080)
      expected_cert          = OpenSSL::X509::Certificate.new(File.open('spec/server.crt'))
      ssl_socket             = OpenSSL::SSL::SSLSocket.new(socket)
      ssl_socket.connect
      ssl_socket.peer_cert.to_s.should == expected_cert.to_s
    end
  end
end
