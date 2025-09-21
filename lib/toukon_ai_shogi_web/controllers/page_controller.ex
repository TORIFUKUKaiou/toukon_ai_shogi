defmodule ToukonAiShogiWeb.PageController do
  use ToukonAiShogiWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/board")
  end
end
