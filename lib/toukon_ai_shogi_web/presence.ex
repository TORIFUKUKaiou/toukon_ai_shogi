defmodule ToukonAiShogiWeb.Presence do
  @moduledoc """
  Tracks players and lobby participants using Phoenix Presence.
  """

  use Phoenix.Presence,
    otp_app: :toukon_ai_shogi,
    pubsub_server: ToukonAiShogi.PubSub
end
