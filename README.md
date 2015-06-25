# Slanger

[![Gem Version](https://badge.fury.io/rb/slanger.svg)](http://badge.fury.io/rb/slanger) [![Build Status](https://travis-ci.org/stevegraham/slanger.svg?branch=master)](https://travis-ci.org/stevegraham/slanger)

**Important! Slanger is not supposed to be included in your Gemfile. RubyGems is used as a distribution mechanism. If you include it in your app, you will likely get dependency conflicts. PRs updating dependencies for compatibility with your app will be closed. Thank you for reading and enjoy Slanger!**

##Typical usage

```
gem install slanger
redis-server &> /dev/null &

slanger --app_key 765ec374ae0a69f4ce44 --secret your-pusher-secret
```

Slanger is a standalone server ruby implementation of the Pusher protocol.  It
is not designed to run inside a Rails or sinatra app, but it can be easily
installed as a gem.

Bundler has multiple purposes, one of which is useful for installation.

##About
Slanger is an open source server implementation of the Pusher protocol written
in Ruby. It is designed to scale horizontally across N nodes and to be agnostic
as to which Slanger node a subscriber is connected to, i.e subscribers to the
same channel are NOT required to be connected to the same Slanger node.
Multiple Slanger nodes can sit behind a load balancer with no special
configuration. In essence it was designed to be very easy to scale.

Presence channel state is shared using Redis. Channels are lazily instantiated
internally within a given Slanger node when the first subscriber connects. When
a presence channel is instantiated within a Slanger node, it queries Redis for
the global state across all nodes within the system for that channel, and then
copies that state internally. Afterwards, when subscribers connect or
disconnect the node publishes a presence message to all interested nodes, i.e.
all nodes with at least one subscriber interested in the given channel.

Slanger is smart enough to know if a new channel subscription belongs to the
same user. It will not send presence messages to subscribers in this case. This
happens when the user has multiple browser tabs open for example. Using a chat
room backed by presence channels as a real example, one would not want
"Barrington" to show up N times in the presence roster because Barrington
has the chat room open in N browser tabs.

Slanger was designed to be highly available and partition tolerant with
eventual consistency, which in practise is instantaneous.

# How to use it

## Requirements

- Ruby 2.1.2 or greater
- Redis

## Server setup

Most linux distributions have by defualt a very low open files limit. In order to sustain more than 1024 ( default ) connections, you need to apply the following changes to your system:
Add to `/etc/sysctl.conf`:
```
fs.file-max = 50000
```
Add to `/etc/security/limits.conf`:
```
* hard nofile 50000
* soft nofile 50000
* hard nproc 50000
* soft nproc 50000
```

## Cluster load-balancing setup with Haproxy

If you want to run multiple slanger instances in a cluster, one option will be to balance the connections with Haproxy.
A basic config can be found in the folder `examples`.
Haproxy can be also used for SSL termination, leaving slanger to not have to deal with SSL checks and so on, making it lighter.


## Starting the service

Slanger is packaged as a Rubygem. Installing the gem makes the 'slanger' executable available. The `slanger` executable takes arguments, of which two are mandatory: `--app_key` and `--secret`. These can but do not have to be the same as the credentials you use for Pusher. They are required because Slanger performs the same HMAC signing of API requests that Pusher does.

__IMPORTANT:__ Redis must be running where Slanger expects it to be (either on localhost:6379 or somewhere else you told Slanger it would be using the option flag) or Slanger will fail silently. I haven't yet figured out how to get em-hiredis to treat an unreachable host as an error

```bash
$ gem install slanger

$ redis-server &> /dev/null &

$ slanger --app_key 765ec374ae0a69f4ce44 --secret your-pusher-secret
```

If all went to plan you should see the following output to STDOUT

```

    .d8888b.  888
   d88P  Y88b 888
   Y88b.      888
    "Y888b.   888  8888b.  88888b.   .d88b.   .d88b.  888d888
       "Y88b. 888     "88b 888 "88b d88P"88b d8P  Y8b 888P"
         "888 888 .d888888 888  888 888  888 88888888 888
   Y88b  d88P 888 888  888 888  888 Y88b 888 Y8b.     888
    "Y8888P"  888 "Y888888 888  888  "Y88888  "Y8888  888
                                         888
                                    Y8b d88P
                                    "Y88P"


Slanger API server listening on port 4567
Slanger WebSocket server listening on port 8080
```

## Ubuntu upstart script

If you're using Ubuntu, you might find this upscript very helpful. The steps below will create an init script that will make slanger run at boot and restart if it fails.
Open `/etc/init/slanger` and add:
```
start on started networking and runlevel [2345]
stop on runlevel [016]
respawn
script
    LANG=en_US.UTF-8 /usr/local/rvm/gems/ruby-RUBY_VERISON/wrappers/slanger --app_key KEY --secret SECRET --redis_address redis://REDIS_IP:REDIS_PORT/REDIS_DB
end script
```
This example assumes you're using rvm and a custom redis configuration

Then, to start / stop the service, just do
```
service slanger start
service slanger stop
```


## Modifying your application code to use the Slanger service

Once you have a Slanger instance listening for incoming connections you need to alter you application code to use the Slanger endpoint instead of Pusher. Fortunately this is very simple, unobtrusive, easily reversable, and very painless.


First you will need to add code to your server side component that publishes events to the Pusher HTTP REST API, usually this means telling the Pusher client to use a different host and port, e.g. consider this Ruby example

```ruby
...

Pusher.host   = 'slanger.example.com'
Pusher.port   = 4567
```

You will also need to do the same to the Pusher JavaScript client in your client side JavaScript, e.g

```html
<script type="text/javascript">
  var pusher = new Pusher('#{Pusher.key}', {
    wsHost: "0.0.0.0",
    wsPort: "8080",
    wssPort: "8080",
    enabledTransports: ['ws', 'flash']
  });
</script>
```

Of course you could proxy all requests to `ws.example.com` to port 8080 of your Slanger node and `api.example.com` to port 4567 of your Slanger node for example, that way you would only need to set the host property of the Pusher client.

# Configuration Options

Slanger supports several configuration options, which can be supplied as command line arguments at invocation. You can also supply a yaml file containing config options. If you use the config file in combination with other configuration options, the values passed on the command line will win. Allows running multiple instances with only a few differences easy.

```
-k or --app_key This is the Pusher app key you want to use. This is a required argument on command line or in optional config file

-s or --secret This is your Pusher secret. This is a required argument on command line or in optional config file

-C or --config_file Path to Yaml file that can contain all or some of the configuration options, including required arguments

-r or --redis_address An address where there is a Redis server running. This is an optional argument and defaults to redis://127.0.0.1:6379/0

-a or --api_host This is the address that Slanger will bind the HTTP REST API part of the service to. This is an optional argument and defaults to 0.0.0.0:4567

-w or --websocket_host This is the address that Slanger will bind the WebSocket part of the service to. This is an optional argument and defaults to 0.0.0.0:8080

-i or --require Require an additional file before starting Slanger to tune it to your needs. This is an optional argument

-p or --private_key_file Private key file for SSL support. This argument is optional, if given, SSL will be enabled

-b or --webhook_url URL for webhooks. This argument is optional, if given webhook callbacks will be made http://pusher.com/docs/webhooks

-c or --cert_file Certificate file for SSL support. This argument is optional, if given, SSL will be enabled

-v or --[no-]verbose This makes Slanger run verbosely, meaning WebSocket frames will be echoed to STDOUT. Useful for debugging

--pid_file  The path to a file you want slanger to write it's PID to. Optional.
```

# Why use Slanger instead of Pusher?

There a few reasons you might want to use Slanger instead of Pusher, e.g.

- You operate in a heavily regulated industry and are worried about sending data to 3rd parties, and it is an organisational requirement that you own your own infrastructure.
- You might be travelling on an airplane without internet connectivity as I am right now. Airplane rides are very good times to get a lot done, unfortunately external services are also usually unreachable. Remove internet connectivity as a dependency of your development envirionment by running a local Slanger instance in development and Pusher in production.
- Remove the network dependency from your test suite.
- You want to extend the Pusher protocol or have some special requirement. If this applies to you, chances are you are out of luck as Pusher is unlikely to implement something to suit your special use case, and rightly so. With Slanger you are free to modify and extend its behavior anyway that suits your purpose.

# Why did you write Slanger

I wanted to write a non-trivial evented app. I also want to write a book on evented programming in Ruby as I feel there is scant good information available on the topic and this project is handy to show publishers.

Pusher is an awesome service, very reasonably priced, and run by an awesome crew. Give them a spin on your next project.

# Author

- Stevie Graham

# Core Team

- Stevie Graham
- Mark Burns

# Contributors

- Stevie Graham
- Mark Burns
- Florian Gilcher
- Claudio Poli

&copy; 2011 a Stevie Graham joint.
