defmodule ToukonAiShogiWeb.PageControllerTest do
  use ToukonAiShogiWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == ~p"/board"
  end
end
