defmodule Slanger.Roster do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link __MODULE__, :ok, name: __MODULE__
  end

  def init(:ok) do

    { :ok, %{} }
  end

  @doc """
  Slanger.Roster.add "presence-channel",
                     "9cdfb439c7876e703e307864c9167a15",
                     %{ "name" => "lol" }

  [{ pid, id, info }, { pid, id, info }, { pid, id, info }]

  """

  def add("presence-" <> channel, id, info) do
    call { :add, channel, id, info, self }
  end

  def handle_call({ :add, channel, id, info, pid }, _from, state) do
    state
      |> Map.update(channel, )
    # rpc multicall update other nodes
  end

  defp call(action) do
    GenServer.call(__MODULE__, action)
  end
end
