defmodule ToukonAiShogi.Repo do
  use Ecto.Repo,
    otp_app: :toukon_ai_shogi,
    adapter: Ecto.Adapters.Postgres
end
