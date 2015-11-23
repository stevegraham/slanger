defmodule Slanger.Signature do
  # def authenticate(signature, socket, channel, data) do
  #   case String.split(signature, ":", parts: 2) do
  #     [_, client_signature] ->
  #       token(socket, channel, data)
  #         |> compare client_signature
  #
  #     _ ->
  #       false
  #   end
  # end
  #
  # def token(socket, channel, data) do
  #   [socket, channel, data]
  #     |> Enum.filter(&(&1))
  #     |> Enum.join(":")
  #     |> sign
  # end

  @doc """
  HMAC SHA-256 sign `string` with `secret`
  """

  def sign(string, secret) do
    :crypto.hmac(:sha256, secret, string)
      |> Base.encode16
      |> String.downcase
  end

  @doc """
  Constant time binary equality check between `a` and ` b`
  """

  def equal?(a, b) do
    use Bitwise, only_operators: true

    cond do
      bit_size(a) == bit_size(b) ->
        sum = Enum.zip(:erlang.binary_to_list(a), :erlang.binary_to_list(b))
          |> Enum.reduce 0, fn({ a, b }, acc) -> acc + a ^^^ b end

        sum == 0

      true -> false
    end
  end
end
