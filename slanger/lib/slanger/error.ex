defmodule Slanger.Error do
  def unknown_application,  do: { 4001, "Application does not exist" }

  def unsupported_protocol, do: { 4007, "Unsupported protocol version" }

  def missing_protocol,     do: { 4008, "Protocol version not supplied" }

  def malformed_json,       do: { 4009, "Malformed JSON" }

  def unknown_event,        do: { 4010, "Unknown event" }
end
