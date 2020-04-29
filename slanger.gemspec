# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slanger/version'

Gem::Specification.new do |s|
  s.name                        = "slanger"
  s.version                     = Slanger::VERSION
  s.summary                     = "A websocket service compatible with Pusher libraries"
  s.description                 = "A websocket service compatible with Pusher libraries"
  s.files                       = `git ls-files -z`.split("\x0")
  s.executables                 = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files                  = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths               = ["lib"]

  s.required_ruby_version       = ">= 2.0.0"

  s.authors                     = ["Stevie Graham", "Mark Burns"]
  s.email                       = ["sjtgraham@mac.com", "markthedeveloper@gmail.com"]
  s.homepage                    = "https://github.com/stevegraham/slanger"
  s.license                     = "MIT"

  s.add_dependency                "eventmachine"
  s.add_dependency                "em-hiredis"
  s.add_dependency                "em-websocket"
  s.add_dependency                "rack"
  s.add_dependency                "rack-fiber_pool"
  s.add_dependency                "signature"
  s.add_dependency                "activesupport"
  s.add_dependency                "sinatra"
  s.add_dependency                "thin"
  s.add_dependency                "em-http-request"
  s.add_dependency		  "oj"

  s.add_development_dependency    "rspec",  "~> 3.6.0"
  s.add_development_dependency    "pusher"
  s.add_development_dependency    "haml"
  s.add_development_dependency    "timecop"
  s.add_development_dependency    "webmock"
  s.add_development_dependency    "mocha"
  s.add_development_dependency    "pry"
  s.add_development_dependency    "pry-byebug"
  s.add_development_dependency     "bundler"
  s.add_development_dependency     "rake"
  s.add_development_dependency  "rb-readline"

  s.files                       = Dir["README.md", "lib/**/*", "slanger.rb"]
  s.require_path                = "."
end
