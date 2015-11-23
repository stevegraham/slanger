defmodule Slanger.Roster do
  @prefix "slanger/rosters/"

  def add("presence-" <> channel, key, value) do
    Agent.update agent_for(channel), HashDict, :put, [key, value]
  end

  def remove("presence-" <> channel, key) do
    Agent.update agent_for(channel), HashDict, :drop, [[key]]
  end

  def for_channel("presence-" <> channel) do
    Agent.get agent_for(channel), HashDict, :drop, [[]]
  end

  defp agent_for(channel) do
    # Use Agents.start/4 to enable rolling code hot swaps on multinode setups
    case Agent.start(HashDict, :new, [], name: { :global, @prefix <> channel }) do
      { :ok, pid } ->
        pid

      { :error, { :already_started, pid } } ->
        pid
    end
  end
end

defmodule Slanger.Roster do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link __MODULE__, :ok, name: __MODULE__
  end

  def init(:ok) do
    # rpc parallel eval replicate
    { :ok, %{} }
  end

  def add("presence-" <> channel, id, info) do
    call { :add, channel, id, info, self }
  end

  def remove("presence-" <> channel, id) do
    call { :remove, channel, id, self }
  end

  def for_channel("presence-" <> channel) do
    call :roster
  end

  def handle_call({ :add, channel, id, info, pid }, _from, state) do
    Map.get state, channel, %{}
      |> Map.merge %{ }
    ref = Process.monitor pid

    # rpc multicall update other nodes
  end

  def handle_call({ :remove, channel, id, pid }, _from, state) do
    Process.demonitor ref
  end

  def handle_call(:roster, _from, state) do

  end

  def handle_info({ 'DOWN', _ref, _type, pid, info }, state) do

  end

  defp call(action) do
    GenServer.call(__MODULE__, action)
  end
end
