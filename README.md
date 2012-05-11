# Jagan

Jagan is an open source server implementation of the Pusher protocol written in Ruby. It is designed to scale horizontally across N nodes and to be agnostic as to which Jagan node a subscriber is connected to, i.e subscribers to the same channel are NOT required to be connected to the same Jagan node. Multiple Jagan nodes can sit behind a load balancer with no special configuration. In essence it was designed to be very easy to scale.

Presence channel state is shared using Redis. Channels are lazily instantiated internally within a given Jagan node when the first subscriber connects. When a presence channel is instantiated within a Jagan node, it queries Redis for the global state across all nodes within the system for that channel, and then copies that state internally. Afterwards, when subscribers connect or disconnect the node publishes a presence message to all interested nodes, i.e. all nodes with at least one subscriber interested in the given channel.

Jagan is smart enough to know if a new channel subscription belongs to the same user. It will not send presence messages to subscribers in this case. This happens when the user has multiple browser tabs open for example. Using a chat room backed by presence channels as a real example, one would not want "Barrington" to show up N times in the presence roster because Barrington is a retard and has the chat room open in N browser tabs.

Jagan was designed to be highly available and partition tolerant with eventual consistency, which in practise is instantaneous.

# How to use it

## Requirements

- Ruby 1.9.2-p290 or greater
- Redis
- Mongodb

## Starting the service

Jagan is packaged as a Rubygem. Installing the gem makes the 'jagan' executable available. The `jagan` executable takes arguments, of which two are mandatory: `--app_key` and `--secret`. These can but do not have to be the same as the credentials you use for Pusher. They are required because Jagan performs the same HMAC signing of API requests that Pusher does.

__IMPORTANT:__ Redis must be running where Jagan expects it to be (either on localhost:6379 or somewhere else you told Jagan it would be using the option flag) or Jagan will fail silently. I haven't yet figured out how to get em-hiredis to treat an unreachable host as an error

<pre>
$ redis-server &> /dev/null &

$ ./bin/slanger --app_key 765ec374ae0a69f4ce44 --secret your-pusher-secret --mongo on --statistics on --id Jagan1 --admin-http-user admin --admin-http-password Verysecret
</pre>

If all went to plan you should see the following output to STDOUT

<pre>

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


Jagan API server listening on port 4567
Jagan WebSocket server listening on port 8080

</pre>

## Modifying your application code to use the Jagan service

Once you have a Jagan instance listening for incoming connections you need to alter you application code to use the Jagan endpoint instead of Pusher. Fortunately this is very simple, unobtrusive, easily reversable, and very painless.


First you will need to add code to your server side component that publishes events to the Pusher HTTP REST API, usually this means telling the Pusher client to use a different host and port, e.g. consider this Ruby example

<pre>
...

Pusher.host   = 'jagan.example.com'
Pusher.port   = 4567

</pre>

You will also need to do the same to the Pusher JavaScript client in your client side JavaScript, e.g

<pre>

<script type="text/javascript">
  ...

  Pusher.host    = 'jagan.example.com'
  Pusher.ws_port = 8080

</script>
</pre>

Of course you could proxy all requests to `ws.example.com` to port 8080 of your Jagan node and `api.example.com` to port 4567 of your Jagan node for example, that way you would only need to set the host property of the Pusher client.

# Configuration Options

Jagan supports several configuration options, which can be supplied as command line arguments at invocation.

<pre>
-i or --app_id This is the Pusher app id you want to use. Optional.

-k or --app_key This is the Pusher app key you want to use. Optional.

-s or --secret This is your Pusher secret. Optional.

-r or --redis_address An address where there is a Redis server running. This is an optional argument and defaults to redis://127.0.0.1:6379/0

--redis_write_address An address where there is a Redis server running where writes will be done. This is an optional argument.

-a or --api_host This is the address that Jagan will bind the HTTP REST API part of the service to. This is an optional argument and defaults to 0.0.0.0:4567

-w or --websocket_host This is the address that Jagan will bind the WebSocket part of the service to. This is an optional argument and defaults to 0.0.0.0:8080

-l or --log-level This is the log level. Optional. Accepted values: fatal, error, warn, info, debug. Default: warn.

--log-file Log file. Optional. Default: STDOUT.

--audit-log-file Audit log file. Optional. Default: STDOUT.

--api-log-file API server log file. Optional. Default: STDOUT.

-v or --[no-]verbose This makes Jagan run verbosely, meaning WebSocket frames will be echoed to STDOUT. Useful for debugging

--id A unique identifier for this jagan daemon in a cluster. Optional.

--statistics Statistics, on or off. Default: off. Number of concurrent connection and messages will be collected for each application.

--mongo Use mongo DB, on or off. Needed for statistics and multiple applications. Default: off

--mongo-host Mongodb host for the statistics. Default: localhost

--mongo-port Mongodb TCP port for the statistics. Default: 27017

--mongo-db Mongodb database name for the statistics. Defailt: jagan.

--admin-http-user HTTP user for accessing statistics and applications.

--admin-http-password HTTP password for accessing statistics and applications.
</pre>

# Statistics access

Statistics can be accessed from these URL with GET requests:
http://jagan.example.com/statistics/all_apps
http://jagan.example.com/statistics/apps/myapp


&copy; 2011 a Stevie Graham joint.

