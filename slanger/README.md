# Slanger

Slanger is an open source API-compatible server implementation of the Pusher
protocol written in Elixir. It is designed such that clients subscribing to the
same channel need not be connected to the same node. If you declare other nodes
at startup Slanger will work all this out for itself.
Slanger behaves exactly as Pusher does; please open an issue if you find it
doesn't somehow.

Slanger is designed for A and P of CAP and uses PG2 extensively to manage this.

## Features

- Public channels
- Private channels
- Presence channels
- Client events
- Simple console
- REST API
- SockJS transport
- Websocket transport
- Webhooks
- Multi-node support

## Requirements

- Erlang 17.0 or later
- Elixir 1.0.0 or later (for development)

## How to use it

- Download the latest release
- copy it to your PATH
- `slanger --app_key your-pusher-app-key --secret your-pusher-secret`

## Modifying your application code to use the Slanger service

Once you have a Slanger instance listening for incoming connections you need to
alter you application code to use the Slanger endpoint instead of Pusher.
Fortunately this is very simple, unobtrusive, easily reversable, and very painless.

First you will need to add code to your server side component that publishes
events to the Pusher HTTP REST API, usually this means telling the Pusher client
to use a different host and port, e.g. consider this Ruby example

```ruby
...

Pusher.host   = 'slanger.example.com'
Pusher.port   = 4567
```

You will also need to do the same to the Pusher JavaScript client in your client
side JavaScript, e.g

```javascript
<script type="text/javascript">
...

Pusher.host     = 'slanger.example.com'
Pusher.ws_port  = 8080
Pusher.wss_port = 8080

</script>
```

Of course you could proxy all requests to `ws.example.com` to port 8080 of your
Slanger node and `api.example.com` to port 4567 of your Slanger node for example,
that way you would only need to set the host property of the Pusher client.

# Configuration Options

Slanger supports several configuration options, which can be supplied as command
line arguments at invocation.

```
-k or --app-key This is the Pusher app key you want to use. This is a required argument

-s or --secret This is your Pusher secret. This is a required argument

-p or --port This is the port that Slanger will bind to. Defaults to 8080

-u or --webhook-url URL for webhooks. This argument is optional, if given webhook callbacks will be made http://pusher.com/docs/webhooks
```

# Why use Slanger instead of Pusher?

There a few reasons you might want to use Slanger instead of Pusher, e.g.

- You operate in a heavily regulated industry and are worried about sending data
  to 3rd parties, and it is an organisational requirement that you own your own
  infrastructure.
- You might be travelling on an airplane without internet connectivity as I am
  right now. Airplane rides are very good times to get a lot done, unfortunately
  external services are also usually unreachable. Remove internet connectivity
  as a dependency of your development environment by running a local Slanger
  instance in development and Pusher in production.
- Remove the network dependency from your test suite.
- You want to extend the Pusher protocol or have some special requirement. If
  this applies to you, chances are you are out of luck as Pusher is unlikely to
  implement something to suit your special use case, and rightly so. With Slanger
  you are free to modify and extend its behavior anyway that suits your purpose.

# Author

- Stevie Graham
