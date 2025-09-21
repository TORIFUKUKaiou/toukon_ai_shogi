defmodule ToukonAiShogiWeb.UserSessionHTML do
  use ToukonAiShogiWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:toukon_ai_shogi, ToukonAiShogi.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
