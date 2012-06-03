# encoding: utf-8
require 'bundler/setup'

require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'active_support/core_ext/string'

module Slanger
end

EM.epoll
EM.kqueue

EM.run do
  File.tap do |f|
    Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', '*.rb'))].each do |file|
      Slanger.autoload File.basename(file, '.rb').classify, file
    end
  end
end

module Slanger
  extend Forwardable
  extend self

  def storage
    @backend ||= Slanger::Redis.new
  end

  def_delegators :storage, :read_all, :delete, :set, :publish, :subscribe
end


