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

  s.required_ruby_version       = ">= 2.2.2"

  s.authors                     = ["Stevie Graham", "Mark Burns"]
  s.email                       = ["sjtgraham@mac.com", "markthedeveloper@gmail.com"]
  s.homepage                    = "https://github.com/stevegraham/slanger"
  s.license                     = "MIT"

  s.add_dependency                "eventmachine",     "~> 1.2.5"
  s.add_dependency                "em-hiredis",       "~> 0.3.1"
  s.add_dependency                "em-websocket",     "~> 0.5.1"
  s.add_dependency                "rack",             "~> 1.5.5"
  s.add_dependency                "rack-fiber_pool",  "~> 0.9.2"
  s.add_dependency                "signature",        "~> 0.1.6"
  s.add_dependency                "activesupport",    "~> 5.1.2"
  s.add_dependency                "sinatra",          "~> 1.4.8"
  s.add_dependency                "thin",             "~> 1.7.2"
  s.add_dependency                "em-http-request",  "~> 0.3.0"
  s.add_dependency                "oj",               "~> 3.3.2"

  s.add_development_dependency    "rspec",            "~> 3.6.0"
  s.add_development_dependency    "pusher",           "~> 1.3.1"
  s.add_development_dependency    "haml",             "~> 5.0.1"
  s.add_development_dependency    "timecop",          "~> 0.9.1"
  s.add_development_dependency    "webmock",          "~> 1.24.6"
  s.add_development_dependency    "mocha",            "~> 1.2.1"
  s.add_development_dependency    "pry",              "~> 0.10.1"
  s.add_development_dependency    "pry-byebug",       "~> 3.4.2"
  s.add_development_dependency    "bundler",          "~> 1.15"
  s.add_development_dependency    "rake",             "~> 12.0.0"

  s.files                       = Dir["README.md", "lib/**/*", "slanger.rb"]
  s.require_path                = "."
end
