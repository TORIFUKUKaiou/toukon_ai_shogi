defmodule ToukonAiShogi.Game.State do
  @moduledoc """
  対局全体のスナップショット。LiveView へ丸ごと渡す前提で設計する。
  """

  alias ToukonAiShogi.Game.{Board, Piece}

  defstruct board: %Board{squares: %{}},
            turn: :sente,
            captures: %{sente: [], gote: []},
            move_log: [],
            request_log: [],
            metadata: %{}

  @type t :: %__MODULE__{
          board: Board.t(),
          turn: :sente | :gote,
          captures: %{sente: [Piece.t()], gote: [Piece.t()]},
          move_log: [map()],
          request_log: [map()],
          metadata: map()
        }

  @doc false
  @spec merge_metadata(t(), map()) :: t()
  def merge_metadata(%__MODULE__{} = state, extra) when is_map(extra) do
    %{state | metadata: Map.merge(state.metadata, extra)}
  end
end
