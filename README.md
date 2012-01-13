# Slanger

Slanger is an open source server implementation of the Pusher protocol written in Ruby. It is designed to scale horizontally across N nodes and to be agnostic as to which Slanger node a subscriber is connected to, i.e subscribers to the same channel are NOT required to be connected to the same Slanger node. Multiple Slanger nodes can sit behind a load balancer with no special configuration. In essence it was designed to be very easy to scale.

Presence channel state is shared using Redis. Channels are lazily instantiated internally within a given Slanger node when the first subscriber connects. When a presence channel is instantiated within a Slanger node, it queries Redis for the global state across all nodes within the system for that channel, and then copies that state internally. Afterwards, when subscribers connect or disconnect the node publishes a presence message to all interested nodes, i.e. all nodes with at least one subscriber interested in the given channel.

Slanger is smart enough to know if a new channel subscription belongs to the same user. It will not send presence messages to subscribers in this case. This happens when the user has multiple browser tabs open for example. Using a chat room backed by presence channels as a real example, one would not want "Barrington" to show up N times in the presence roster because Barrington is a retard and has the chat room open in N browser tabs.

Slanger was designed to be highly available and partition tolerant with eventual consistency, which in practise is instantaneous.

# How to use it

## Requirements

- Ruby 1.9.2-p290 or greater
- Redis

## Starting the service

Slanger is packaged as a Rubygem. Installing the gem makes the 'slanger' executable available. The `slanger` executable takes arguments, of which two are mandatory: `--app_key` and `--secret`. These can but do not have to be the same as the credentials you use for Pusher. They are required because Slanger performs the same HMAC signing of API requests that Pusher does.

__IMPORTANT:__ Redis must be running where Slanger expects it to be (either on localhost:6379 or somewhere else you told Slanger it would be using the option flag) or Slanger will fail silently. I haven't yet figured out how to get em-hiredis to treat an unreachable host as an error

<pre>
$ gem install slanger

$ redis-server &> /dev/null &

$ slanger --app_key 765ec374ae0a69f4ce44 --secret your-pusher-secret
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


Slanger API server listening on port 4567
Slanger WebSocket server listening on port 8080

</pre>

## Modifying your application code to use the Slanger service

Once you have a Slanger instance listening for incoming connections you need to alter you application code to use the Slanger endpoint instead of Pusher. Fortunately this is very simple, unobtrusive, easily reversable, and very painless.


First you will need to add code to your server side component that publishes events to the Pusher HTTP REST API, usually this means telling the Pusher client to use a different host and port, e.g. consider this Ruby example

<pre>
...

Pusher.host   = 'slanger.example.com'
Pusher.port   = 4567

</pre>

You will also need to do the same to the Pusher JavaScript client in your client side JavaScript, e.g

<pre>

<script type="text/javascript">
  ...

  Pusher.host    = 'slanger.example.com'
  Pusher.ws_port = 8080

</script>
</pre>

Of course you could proxy all requests to `ws.example.com` to port 8080 of your Slanger node and `api.example.com` to port 4567 of your Slanger node for example, that way you would only need to set the host property of the Pusher client.

# Configuration Options

Slanger supports several configuration options, which can be supplied as command line arguments at invocation.

<pre>
-k or --app_key This is the Pusher app key you want to use. This is a required argument

-s or --secret This is your Pusher secret. This is a required argument

-r or --redis_address An address where there is a Redis server running. This is an optional argument and defaults to redis://127.0.0.1:6379/0

-a or --api_host This is the address that Slanger will bind the HTTP REST API part of the service to. This is an optional argument and defaults to 0.0.0.0:4567

-w or --websocket_host This is the address that Slanger will bind the WebSocket part of the service to. This is an optional argument and defaults to 0.0.0.0:8080

-v or --[no-]verbose This makes Slanger run verbosely, meaning WebSocket frames will be echoed to STDOUT. Useful for debugging
</pre>


# Why use Slanger instead of Pusher?

There a few reasons you might want to use Slanger instead of Pusher, e.g.

- You operate in a heavily regulated industry and are worried about sending data to 3rd parties, and it is an organisational requirement that you own your own infrastructure.
- You might be travelling on an airplane without internet connectivity as I am right now. Airplane rides are very good times to get a lot done, unfortunately external services are also usually unreachable. Remove internet connectivity as a dependency of your development envirionment by running a local Slanger instance in development and Pusher in production.
- You want to extend the Pusher protocol or have some special requirement. If this applies to you, chances are you are out of luck as Pusher is unlikely to implement something to suit your special use case, and rightly so. With Slanger you are free to modify and extend its behavior anyway that suits your purpose.

# Why did you write Slanger

I wanted to write a non-trivial evented app. I also want to write a book on evented programming in Ruby as I feel there is scant good information available on the topic and this project is handy to show publishers.

Pusher is an awesome service, very reasonably priced, and run by an awesome crew. Give them a spin on your next project.

&copy; 2011 a Stevie Graham joint.

