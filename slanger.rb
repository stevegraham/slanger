# encoding: utf-8
require 'bundler/setup'

require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'active_support/core_ext/string'
require File.join(File.dirname(__FILE__), 'lib', 'slanger', 'version')

module Slanger; end

EM.epoll
EM.kqueue

File.tap do |f|
  Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', '*.rb'))].each do |file|
    Slanger.autoload File.basename(file, '.rb').camelize, file
  end

  Dir[f.expand_path(f.join(f.dirname(__FILE__),'lib', 'slanger', 'api', '*.rb'))].each do |file|
    Slanger::Api.autoload File.basename(file, '.rb').camelize, file
  end
end
