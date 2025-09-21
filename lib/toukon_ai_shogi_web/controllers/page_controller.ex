defmodule ToukonAiShogiWeb.PageController do
  use ToukonAiShogiWeb, :controller

  def home(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: %_struct{}} -> redirect(conn, to: ~p"/lobby")
      _ -> redirect(conn, to: ~p"/users/log-in")
    end
  end
end
