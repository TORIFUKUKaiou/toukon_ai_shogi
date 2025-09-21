defmodule ToukonAiShogi.Game do
  @moduledoc """
  ドメインコンテキスト。対局状態の初期化とシリアライズを扱う。

  合法手検証はフェーズ4以降で導入予定のため、現在は縁台ルールに合わせて
  任意の座標更新を許容する前提で構造体を定義する。
  """

  alias ToukonAiShogi.Game.{Board, InitialSetup, Piece, State}

  @type coordinate :: {pos_integer(), pos_integer()}

  @doc """
  初期状態の対局を生成する。
  """
  @spec new(keyword()) :: State.t()
  def new(opts \\ []) do
    state = InitialSetup.starting_state()

    case Keyword.get(opts, :metadata) do
      nil -> state
      metadata when is_map(metadata) -> State.merge_metadata(state, metadata)
    end
  end

  @doc """
  初期盤面だけを返す。
  """
  @spec initial_board() :: Board.t()
  def initial_board, do: InitialSetup.starting_board()

  @doc """
  対局状態を Phoenix LiveView で扱いやすい Map に変換する。
  """
  @spec serialize(State.t()) :: map()
  def serialize(%State{} = state) do
    %{
      turn: state.turn,
      board: serialize_board(state.board),
      captures: serialize_captures(state.captures),
      move_log: state.move_log,
      request_log: state.request_log,
      metadata: state.metadata
    }
  end

  @doc """
  初期状態の JSON を返す。LiveView の静的ロードで利用可能。
  """
  @spec initial_state_json() :: binary()
  def initial_state_json do
    starting_state = InitialSetup.starting_state()

    starting_state
    |> serialize()
    |> Jason.encode!()
  end

  @doc """
  「リクエスト」の記録を追記する。判定ロジックは別途導入する前提。
  """
  @spec log_request(State.t(), map()) :: State.t()
  def log_request(%State{} = state, entry) when is_map(entry) do
    %{state | request_log: [entry | state.request_log]}
  end

  @doc """
  直近の指し手をログへ追加する。棋譜表現は後続フェーズで整備する。
  """
  @spec push_move(State.t(), map()) :: State.t()
  def push_move(%State{} = state, move) when is_map(move) do
    %{state | move_log: state.move_log ++ [move]}
  end

  defp serialize_board(%Board{squares: squares}) do
    squares
    |> Enum.sort_by(fn {{file, rank}, _piece} -> {rank, file} end)
    |> Enum.map(fn {{file, rank}, %Piece{} = piece} ->
      %{
        file: file,
        rank: rank,
        id: piece.id,
        type: piece.type,
        owner: piece.owner,
        promoted: piece.promoted
      }
    end)
  end

  defp serialize_captures(%{sente: sente, gote: gote}) do
    %{
      sente: Enum.map(sente, &serialize_piece/1),
      gote: Enum.map(gote, &serialize_piece/1)
    }
  end

  defp serialize_piece(%Piece{} = piece) do
    %{
      id: piece.id,
      type: piece.type,
      owner: piece.owner,
      promoted: piece.promoted
    }
  end
end
