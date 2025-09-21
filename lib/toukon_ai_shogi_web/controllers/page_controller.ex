defmodule ToukonAiShogiWeb.PageController do
  use ToukonAiShogiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
