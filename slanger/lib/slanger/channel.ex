defmodule Slanger.Channel do
  alias Slanger.Event

  @prefix "slanger/channels/"

  @doc """
  Returns { :ok, map } tuple with map of occupied channels or { :error, reason }

  The `prefix` argument filters out channels whose name does not begin with
  `prefix`. `info` is a list of attributes which should be returned for each
  channel. If this argument is missing, an empty map of attributes will be
  returned for each channel. If an attribute is included a channel in the set
  does not support it, e.g. `"user_count"` for non-presence channels
  """

  def channels(prefix \\ "", properties \\ []) do
    import String, only: [starts_with: 1, replace: 1]

    :pg2.which_groups
      |> Stream.filter &(String.starts_with? &1, @prefix)
      |> Stream.map    &(String.replace &1, @prefix, "")
      |> Stream.filter &(String.starts_with? &1, prefix)
      |> Enum.reduce %{}, &(Map.put_new &2, &1, info(&1, properties))
  end

  def info(channel, properties \\ []) do
    data = %{
      occupied: occupied?(channel),
      user_count: subcription_count(channel)
    }

    Map.take properties, [:occupied | info]
  end

  def subscribe("private-" <> channel) do
    # case authenticated?(channel) do
    #   true ->
    #     register_pid channel
    #     send self, { self, Event.subscription_succeeded(channel) }
    #
    #   false ->
    #     send self, { self, Event.subscription_succeeded(channel) }
    # end
  end

  def subscribe("presence-" <> channel) do

  end

  def subscribe(channel) do
    register_pid channel
    send self, { self, Event.subscription_succeeded(channel) }

    :ok
  end

  def unsubscribe(channel) do
    :pg2.create @prefix <> channel
    :pg2.leave @prefix  <> channel, self

    :ok
  end

  def subscription_count(channel) do
    channel
      |> subscribers
      |> Enum.count
  end

  defp register_pid(channel) do
    :pg2.create "slanger/channels/" <> channel
    :pg2.join   "slanger/channels/" <> channel, self
  end

  def publish(channel, event) do
    Task.start fn ->
      channel |> subscribers |> Enum.each(send self, { self, event })
    end
  end

  def subscribers(channel) do
    :pg2.create @prefix <> channel

    case :pg2.get_members @prefix <> channel do
      pids when is_list pids -> pids
      _                      -> []
    end
  end

  def occupied?(channel) do
    Enum.any? subscribers(channel)
  end
end
