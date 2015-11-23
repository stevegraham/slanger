defmodule Slanger.API do
  @moduledoc """
  The Slanger HTTP API.

  Parameters MUST be submitted in the query string for GET requests. For POST
  requests, parameters MUST be submitted in the POST body as a JSON hash (while
  setting Content-Type: application/json).

  HTTP status codes are used to indicate the success or otherwise of requests.
  The following status are common:

  `200` -	Successful request. Body will contain a JSON hash of response data
  `400` -	Error: details in response body
  `401`	- Authentication error: response body will contain an explanation

  Other status codes are documented under the appropriate APIs.
  """

  defmodule BadRequestError do
    @moduledoc """
    Generic bad request error. Override properties when used as needed
    """

    defexception message: "Bad Request", plug_status: 400
  end

  use Plug.Router

  alias Slanger.Channel

  plug Authentication, secret: "HUEHUEHUE"
  plug Plug.Parsers,   parsers: [:json], json_decoder: JSEX
  plug :match
  plug :dispatch

  @doc """
  Triggers an event on one or more channels.

  # Request parameters

  `name` - Event name (required)
  `data` - Event data (required) - limited to 10KB
  `channels` - Array of one or more channel names - limited to 10 channels
  `channel` - Channel name if publishing to a single channel (can be used instead of channels)
  `socket_id` - Excludes the event from being sent to a specific connection (see excluding recipients)

  # Success

  Responds with an empty JSON object and a 202 HTTP status code

  # Failure

  Responds with an error message and 400 HTTP status code. Raises Slanger.API.BadRequestError
  """

  post "/apps/:app_id/events" do
    cond do
      conn.params["channels"] ->
        conn.params["channels"]
          |> Enum.take 10
          |> Enum.each &(Channel.publish &1, event)

      conn.params["channel"] ->
        Channel.publish conn.params["channel"], event

      true -> raise BadRequestError message: "Either `channel` or `channels` must be given"
    end

    conn
      |> respond_with 202, %{}
  end

  @doc """
  Returns occupied channels as JSON.

  # Request parameters

  `filter_by_prefix` - Filter the returned channels by a specific prefix. For
  example in order to return only presence channels you would set
  `filter_by_prefix=presence-`

  `info` - A comma separated list of attributes which should be returned for the
  channel. See the table below for a list of available attributes, and for
  which channel types.

  # Info attributes

  Available info attributes


  `user_count` - Number of distinct users currently subscribed to this channel
    (a single user may be subscribed many times, but will only count as one).
    Integer. Available on presence channels only.


  `subscription_count` - Number of connections currently subscribed to this channel.

  If an attribute such as user_count is requested, and the request is not limited
  to presence channels, the Pusher API returns an error (400 code), Slanger
  instead ignores the attribute one channels that do not support it.

  # Success

  Responds with occupied channels represented as JSON with a 200 HTTP status code

      {
        "channels": {
          "presence-foobar": {
            user_count: 42
          },
          "presence-another": {
            user_count: 123
          }
        }
      }

  # Failure

  Responds with an error message and 400 HTTP status code. Raises Slanger.API.BadRequestError
  """

  get "/apps/:app_id/channels" do
    filter_by  = Map.get conn.params, "filter_by_prefix", ""
    properties = propery_list conn

    case Channel.channels(filter_by, properties) do
      { :ok, channels } ->
        respond_with conn, channels
      { :error, reason } ->
        raise BadRequestError message: reason
    end
  end

  @doc """
  Fetches channel occupation status along with any request properties

  # Request parameters

  `info` - A comma separated list of attributes which should be returned for the
  channel. See the table below for a list of available attributes,
  and for which channel types.

  # Info attributes

  Available info attributes


  `user_count` - Number of distinct users currently subscribed to this channel
  (a single user may be subscribed many times, but will only
  count as one). Integer. Available on presence channels only.
  `subscription_count` - Number of connections currently subscribed to this channel.

  # Success

  Responds with occupied channels represented as JSON with a 200 HTTP status code

      {
        occupied: true,
        user_count: 42,
        subscription_count: 42
      }

  # Failure

  Responds with an error message and 400 HTTP status code. Raises Slanger.API.BadRequestError
  """

  get "/apps/:app_id/channels/:channel_name" do
    conn
      |> respond_with Channel.info(channel_name, propery_list conn)
  end

  @doc """
  Fetch user ids currently subscribed to a presence channel. This functionality
  is primarily aimed to complement presence webhooks, by allowing the initial
  state of a channel to be fetched.

  Note that only presence channels allow this functionality, and a request to
  any other kind of channel will result in a 400 HTTP code.

  # Success

  Returns an array of subscribed users ids

      {
        "users": [
          { "id": 1 },
          { "id": 2 }
        ]
      }

  # Failure

  Responds with an error message and 400 HTTP status code. Raises Slanger.API.BadRequestError
  """

  get "/apps/:app_id/channels/:channel_name/:users" do

  end

  @doc """
  Generic catch all route. Returns 404 Not found.
  """

  match _ do
    # Pusher doesn't respond with JSON for failure cases, n.b. http://bit.ly/1H8JCBS
    send_resp conn, 404, "Not found"
  end

  @doc """
  Takes a connection, status code, and an Erlang term. The term is encoded as
  JSON and sent as the request response to the client with the given status code
  """

  def respond_with(conn, status \\ 200, data) do
    conn
      |> put_resp_content_type "application/json"
      |> send_resp status, JSEX.encode!(data)
  end

  defp propery_list(conn) do
    Map.get conn.params, "info", ""
      |> String.split ","
      |> Enum.reject &(String.length(&1) == 0)
  end
end
