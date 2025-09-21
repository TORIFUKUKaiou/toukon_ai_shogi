defmodule ToukonAiShogi.Game.InitialSetup do
  @moduledoc """
  初期盤面と初期ステート生成を担当する。
  """

  alias ToukonAiShogi.Game.{Board, Piece, State}

  @spec starting_state() :: State.t()
  def starting_state do
    %State{board: starting_board()}
  end

  @spec starting_board() :: Board.t()
  def starting_board do
    {squares, _} =
      base_layout()
      |> Enum.reduce({%{}, %{}}, fn {coord, {owner, type}}, {acc, counters} ->
        {piece, counters} = build_piece(owner, type, counters)
        {Map.put(acc, coord, piece), counters}
      end)

    %Board{squares: squares}
  end

  defp build_piece(owner, type, counters) do
    key = {owner, type}
    next_index = Map.get(counters, key, 0) + 1
    id = "#{owner}-#{type}-#{next_index}"

    piece = %Piece{id: id, type: type, owner: owner}
    {piece, Map.put(counters, key, next_index)}
  end

  defp base_layout do
    [
      {{1, 1}, {:sente, :kyo}},
      {{2, 1}, {:sente, :kei}},
      {{3, 1}, {:sente, :gin}},
      {{4, 1}, {:sente, :kin}},
      {{5, 1}, {:sente, :gyoku}},
      {{6, 1}, {:sente, :kin}},
      {{7, 1}, {:sente, :gin}},
      {{8, 1}, {:sente, :kei}},
      {{9, 1}, {:sente, :kyo}},
      {{2, 2}, {:sente, :hisya}},
      {{8, 2}, {:sente, :kaku}},
      {{1, 3}, {:sente, :fu}},
      {{2, 3}, {:sente, :fu}},
      {{3, 3}, {:sente, :fu}},
      {{4, 3}, {:sente, :fu}},
      {{5, 3}, {:sente, :fu}},
      {{6, 3}, {:sente, :fu}},
      {{7, 3}, {:sente, :fu}},
      {{8, 3}, {:sente, :fu}},
      {{9, 3}, {:sente, :fu}},
      {{1, 7}, {:gote, :fu}},
      {{2, 7}, {:gote, :fu}},
      {{3, 7}, {:gote, :fu}},
      {{4, 7}, {:gote, :fu}},
      {{5, 7}, {:gote, :fu}},
      {{6, 7}, {:gote, :fu}},
      {{7, 7}, {:gote, :fu}},
      {{8, 7}, {:gote, :fu}},
      {{9, 7}, {:gote, :fu}},
      {{2, 8}, {:gote, :kaku}},
      {{8, 8}, {:gote, :hisya}},
      {{1, 9}, {:gote, :kyo}},
      {{2, 9}, {:gote, :kei}},
      {{3, 9}, {:gote, :gin}},
      {{4, 9}, {:gote, :kin}},
      {{5, 9}, {:gote, :gyoku}},
      {{6, 9}, {:gote, :kin}},
      {{7, 9}, {:gote, :gin}},
      {{8, 9}, {:gote, :kei}},
      {{9, 9}, {:gote, :kyo}}
    ]
  end
end
