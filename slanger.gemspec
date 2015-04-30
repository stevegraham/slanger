require './lib/slanger/version'

Gem::Specification.new do |s|
  s.platform                    = Gem::Platform::RUBY
  s.name                        = 'slanger'
  s.version                     = Slanger::VERSION
  s.summary                     = 'A websocket service compatible with Pusher libraries'
  s.description                 = 'A websocket service compatible with Pusher libraries'

  s.required_ruby_version       = '>= 2.0.0'

  s.author                      = 'Stevie Graham'
  s.email                       = 'sjtgraham@mac.com'
  s.homepage                    = 'http://github.com/stevegraham/slanger'

  s.add_dependency                'eventmachine',     '~> 1.0.0'
  s.add_dependency                'em-hiredis',       '~> 0.2.0'
  s.add_dependency                'em-websocket',     '~> 0.5.1'
  s.add_dependency                'rack',             '~> 1.4.5'
  s.add_dependency                'rack-fiber_pool',  '~> 0.9.2'
  s.add_dependency                'signature',        '~> 0.1.6'
  s.add_dependency                'activesupport',    '~> 4.2.1'
  s.add_dependency                'sinatra',          '~> 1.4.4'
  s.add_dependency                'thin',             '~> 1.6.0'
  s.add_dependency                'em-http-request',  '~> 0.3.0'

  s.add_development_dependency    'rspec',            '~> 2.12.0'
  s.add_development_dependency    'pusher',           '~> 0.14.2'
  s.add_development_dependency    'haml',             '~> 3.1.2'
  s.add_development_dependency    'rake'
  s.add_development_dependency    'timecop',          '~> 0.3.5'
  s.add_development_dependency    'webmock',          '~> 1.8.7'
  s.add_development_dependency    'mocha',            '~> 0.13.2'
  s.add_development_dependency    'pry',              '~> 0.10.1'

  s.files                       = Dir['README.md', 'lib/**/*', 'slanger.rb']
  s.require_path                = '.'

  s.executables << 'slanger'
end
