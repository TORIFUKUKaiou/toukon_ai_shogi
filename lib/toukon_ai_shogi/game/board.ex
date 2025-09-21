defmodule ToukonAiShogi.Game.Board do
  @moduledoc """
  9x9 盤面の状態を保持する。座標は `{file, rank}` で表す。
  """

  alias ToukonAiShogi.Game.Piece
  alias ToukonAiShogi.Game

  @enforce_keys [:squares]
  defstruct squares: %{}

  @type t :: %__MODULE__{squares: %{Game.coordinate() => Piece.t()}}

  @doc """
  指定座標の駒を取得する。
  """
  @spec fetch(t(), Game.coordinate()) :: {:ok, Piece.t()} | :error
  def fetch(%__MODULE__{squares: squares}, coordinate) do
    case Map.fetch(squares, coordinate) do
      {:ok, %Piece{} = piece} -> {:ok, piece}
      :error -> :error
    end
  end

  @doc """
  駒を配置する。既存の駒は上書きされる。
  """
  @spec put(t(), Game.coordinate(), Piece.t()) :: t()
  def put(%__MODULE__{squares: squares} = board, coordinate, %Piece{} = piece) do
    %{board | squares: Map.put(squares, coordinate, piece)}
  end

  @doc """
  指定座標の駒を取り除く。
  """
  @spec drop(t(), Game.coordinate()) :: {Piece.t() | nil, t()}
  def drop(%__MODULE__{squares: squares} = board, coordinate) do
    {removed, updated} = Map.pop(squares, coordinate)
    {removed, %{board | squares: updated}}
  end
end
