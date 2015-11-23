defmodule Time do
  use Timex

  def stamp do
    Date.now |> Date.convert :secs
  end
end
