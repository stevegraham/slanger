Gem::Specification.new do |s|
  s.platform                    = Gem::Platform::RUBY
  s.name                        = 'slanger'
  s.version                     = '0.2.3'
  s.summary                     = 'A websocket service compatible with Pusher libraries'
  s.description                 = 'A websocket service compatible with Pusher libraries'

  s.required_ruby_version       = '>= 1.9.2'

  s.author                      = 'Stevie Graham'
  s.email                       = 'sjtgraham@mac.com'
  s.homepage                    = 'http://github.com/stevegraham/slanger'

  s.add_dependency                'eventmachine',     '~> 0.12.10'
  s.add_dependency                'em-hiredis',       '~> 0.1.0'
  s.add_dependency                'em-websocket',     '~> 0.3.5'
  s.add_dependency                'rack',             '~> 1.3.3'
  s.add_dependency                'rack-fiber_pool',  '0.9.1'
  s.add_dependency                'signature',        '~> 0.1.3'
  s.add_dependency                'activesupport',    '~> 3.1.0'
  s.add_dependency                'glamazon',         '~> 0.3.1'
  s.add_dependency                'sinatra',          '~> 1.2.6'
  s.add_dependency                'thin',             '~> 1.2.11'
  s.add_dependency                'em-http-request',  '~> 0.3.0'
  s.add_dependency                'mongo',            '~> 1.6.1'
  s.add_dependency                'em-mongo',         '~> 0.4.2'
  s.add_dependency                'bson_ext',         '~> 1.6.1'

  s.add_development_dependency    'rspec',            '~> 2.6.0'
  s.add_development_dependency    'pusher',           '~> 0.9.3'
  s.add_development_dependency    'haml',             '~> 3.1.2'
  s.add_development_dependency    'rake'
  s.add_development_dependency    'timecop',          '~> 0.3.5'
  s.add_development_dependency    'webmock',          '~> 1.8.7'
  s.add_development_dependency    'mocha',            '~> 0.12.0'

  s.files                       = Dir['README.md', 'lib/**/*', 'slanger.rb']
  s.require_path                = '.'

  s.executables << 'slanger'
end

