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
    base_state =
      InitialSetup.starting_state()
      |> State.merge_metadata(%{
        selected_piece: nil,
        pending_move: nil,
        promotion_choice: nil,
        last_move: nil,
        result: nil
      })

    case Keyword.get(opts, :metadata) do
      nil -> base_state
      metadata when is_map(metadata) -> State.merge_metadata(base_state, metadata)
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
      move_log: Enum.map(state.move_log, &serialize_move/1),
      request_log: Enum.map(state.request_log, &serialize_request/1),
      metadata: serialize_metadata(state.metadata)
    }
  end

  @doc """
  駒を移動させる。縁台ルールに従い移動先のバリデーションは行わない。

  - `promote: true` の場合は成り処理を行う（対象駒が成れない場合は無視）。
  - 駒を取った場合は持ち駒に追加し、相手ターンに切り替える。
  """
  @spec apply_move(State.t(), %{from: coordinate(), to: coordinate()}, keyword()) ::
          {:ok, State.t()} | {:error, :no_piece | :not_players_turn}
  def apply_move(%State{} = state, %{from: from, to: to} = move, opts \\ []) do
    promote? = Keyword.get(opts, :promote, false)

    with {:ok, %Piece{} = piece, board_without_piece} <- Board.take(state.board, from),
         true <- piece.owner == state.turn do
      {captured_piece, board_cleared_target} = Board.drop(board_without_piece, to)

      moved_piece = maybe_promote(piece, promote?)
      updated_board = Board.put(board_cleared_target, to, moved_piece)
      updated_captures = maybe_capture(state.captures, captured_piece, piece.owner)
      move_entry = build_move_entry(move, promote?, captured_piece)

      new_state =
        %State{
          state
          | board: updated_board,
            captures: updated_captures,
            move_log: state.move_log ++ [move_entry],
            metadata:
              state.metadata
              |> Map.put(:selected_piece, nil)
              |> Map.put(:pending_move, nil)
              |> Map.put(:promotion_choice, nil)
              |> Map.put(:last_move, move_entry),
            turn: opponent(piece.owner)
        }

      {:ok, new_state}
    else
      {:error, :empty} -> {:error, :no_piece}
      false -> {:error, :not_players_turn}
    end
  end

  @doc """
  対局結果を記録する。
  """
  @spec record_result(State.t(), map()) :: State.t()
  def record_result(%State{} = state, result) when is_map(result) do
    State.merge_metadata(state, %{result: result})
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
    %{
      state
      | request_log: [entry | state.request_log],
        metadata: Map.put(state.metadata, :last_request, entry)
    }
  end

  @doc """
  直近の指し手をログへ追加する。棋譜表現は後続フェーズで整備する。
  """
  @spec push_move(State.t(), map()) :: State.t()
  def push_move(%State{} = state, move) when is_map(move) do
    %{state | move_log: state.move_log ++ [move]}
  end

  @spec opponent(:sente | :gote) :: :sente | :gote
  def opponent(:sente), do: :gote
  def opponent(:gote), do: :sente

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

  defp serialize_move(nil), do: nil

  defp serialize_move(%{from: from, to: to} = move) do
    move
    |> Map.put(:from, serialize_coordinate(from))
    |> Map.put(:to, serialize_coordinate(to))
  end

  defp serialize_move(other), do: other

  defp serialize_request(nil), do: nil
  defp serialize_request(entry) when is_map(entry), do: entry
  defp serialize_request(other), do: other

  defp serialize_metadata(metadata) when is_map(metadata) do
    metadata
    |> maybe_update_map(:pending_move, &serialize_move/1)
    |> maybe_update_map(:last_move, &serialize_move/1)
    |> maybe_update_map(:last_request, &serialize_request/1)
  end

  defp serialize_metadata(other), do: other

  defp maybe_update_map(map, key, fun) do
    case Map.fetch(map, key) do
      {:ok, nil} -> map
      {:ok, value} -> Map.put(map, key, fun.(value))
      :error -> map
    end
  end

  defp serialize_coordinate({file, rank}) when is_integer(file) and is_integer(rank) do
    %{file: file, rank: rank}
  end

  defp serialize_coordinate(other), do: other

  defp maybe_promote(%Piece{} = piece, true) do
    if promotable_type?(piece.type) do
      %{piece | promoted: true, type: promote_type(piece.type)}
    else
      piece
    end
  end

  defp maybe_promote(%Piece{} = piece, false), do: piece

  defp maybe_capture(captures, nil, _owner), do: captures

  defp maybe_capture(captures, %Piece{} = captured, owner) do
    base_type = demote_type(captured.type)

    hand_piece = %Piece{
      id: capture_id(owner, base_type),
      type: base_type,
      owner: owner,
      promoted: false
    }

    Map.update!(captures, owner, fn pieces -> [hand_piece | pieces] end)
  end

  defp build_move_entry(%{from: from, to: to}, promote?, captured_piece) do
    %{
      from: from,
      to: to,
      promote: promote?,
      captured:
        case captured_piece do
          nil -> nil
          %Piece{} = piece -> %{type: piece.type, owner: piece.owner, promoted: piece.promoted}
        end
    }
  end

  defp promotable_type?(:gyoku), do: false
  defp promotable_type?(:kin), do: false
  defp promotable_type?(:ryu), do: false
  defp promotable_type?(:uma), do: false
  defp promotable_type?(:tokin), do: false
  defp promotable_type?(:narigin), do: false
  defp promotable_type?(:narikei), do: false
  defp promotable_type?(:narikyo), do: false
  defp promotable_type?(_), do: true

  defp promote_type(:hisya), do: :ryu
  defp promote_type(:kaku), do: :uma
  defp promote_type(:gin), do: :narigin
  defp promote_type(:kei), do: :narikei
  defp promote_type(:kyo), do: :narikyo
  defp promote_type(:fu), do: :tokin
  defp promote_type(other), do: other

  defp demote_type(:ryu), do: :hisya
  defp demote_type(:uma), do: :kaku
  defp demote_type(:narigin), do: :gin
  defp demote_type(:narikei), do: :kei
  defp demote_type(:narikyo), do: :kyo
  defp demote_type(:tokin), do: :fu
  defp demote_type(type), do: type

  defp capture_id(owner, type) do
    suffix = System.unique_integer([:positive, :monotonic])
    "#{owner}-capture-#{type}-#{suffix}"
  end
end
