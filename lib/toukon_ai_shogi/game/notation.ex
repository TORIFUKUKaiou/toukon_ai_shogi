defmodule ToukonAiShogi.Game.Notation do
  @moduledoc """
  Utility helpers for rendering board coordinates and moves using shogi notation
  (file digits 1..9 and rank kanji 一..九).
  """

  alias ToukonAiShogi.Game.Piece

  @rank_kanji %{
    1 => "一",
    2 => "二",
    3 => "三",
    4 => "四",
    5 => "五",
    6 => "六",
    7 => "七",
    8 => "八",
    9 => "九"
  }

  @spec file_label(pos_integer()) :: String.t()
  def file_label(file) when file in 1..9 do
    Integer.to_string(10 - file)
  end

  @spec rank_label(pos_integer()) :: String.t()
  def rank_label(rank) when rank in 1..9, do: Map.fetch!(@rank_kanji, 10 - rank)

  @spec square_label({pos_integer(), pos_integer()}) :: String.t()
  def square_label({file, rank}) do
    "#{file_label(file)}筋#{rank_label(rank)}段"
  end

  @spec move_label({pos_integer(), pos_integer()}, {pos_integer(), pos_integer()}, boolean()) ::
          String.t()
  def move_label(from, to, promote?) do
    base = "#{square_label(from)} → #{square_label(to)}"
    if promote?, do: base <> "（成）", else: base
  end

  @spec drop_label(Piece.type(), {pos_integer(), pos_integer()}) :: String.t()
  def drop_label(piece_type, to) do
    "#{Piece.label(piece_type)}打 #{square_label(to)}"
  end
end
