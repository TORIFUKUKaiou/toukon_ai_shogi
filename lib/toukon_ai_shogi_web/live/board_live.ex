defmodule ToukonAiShogiWeb.BoardLive do
  use ToukonAiShogiWeb, :live_view

  alias ToukonAiShogi.Game
  alias ToukonAiShogi.Game.{Board, Notation, Piece, State}
  alias ToukonAiShogiWeb.BoardComponents

  @impl true
  def mount(_params, _session, socket) do
    game_state = Game.new()

    {:ok,
     socket
     |> assign_game_state(game_state)
     |> assign(selected_square: nil)
     |> assign(last_event: nil)
     |> assign(promotion_prompt: nil)
     |> assign(request_modal: nil)}
  end

  @impl true
  def handle_event("square_clicked", %{"file" => file, "rank" => rank}, socket) do
    if moves_blocked?(socket) do
      {:noreply, socket}
    else
      {file, rank} = parse_coordinates(file, rank)
      board = socket.assigns.game_state.board

      case {socket.assigns.selected_square, Board.fetch(board, {file, rank})} do
        {nil, {:ok, %Piece{} = piece}} when piece.owner == socket.assigns.game_state.turn ->
          updated_state =
            State.merge_metadata(socket.assigns.game_state, %{selected_piece: piece.id})

          {:noreply,
           socket
           |> assign_game_state(updated_state)
           |> assign(selected_square: {file, rank})
           |> assign(last_event: {:pick, {file, rank}})}

        {nil, {:ok, %Piece{}}} ->
          {:noreply, assign(socket, last_event: {:not_your_piece, {file, rank}})}

        {nil, :error} ->
          {:noreply, assign(socket, last_event: {:empty_square, {file, rank}})}

        {{^file, ^rank}, _} ->
          updated_state = State.merge_metadata(socket.assigns.game_state, %{selected_piece: nil})

          {:noreply,
           socket
           |> assign_game_state(updated_state)
           |> assign(selected_square: nil)
           |> assign(last_event: :cancel_selection)}

        {selected, _} when is_tuple(selected) ->
          handle_move(socket, selected, {file, rank})
      end
    end
  end

  @impl true
  def handle_event("reset_board", _params, socket) do
    game_state = Game.new()

    {:noreply,
     socket
     |> assign_game_state(game_state)
     |> assign(selected_square: nil)
     |> assign(last_event: :reset)
     |> assign(promotion_prompt: nil)
     |> assign(request_modal: nil)}
  end

  @impl true
  def handle_event("promotion_decision", %{"decision" => decision}, socket) do
    case socket.assigns.promotion_prompt do
      %{move: move} ->
        promote? = decision == "promote"

        case Game.apply_move(socket.assigns.game_state, move, promote: promote?) do
          {:ok, new_state} ->
            {:noreply,
             socket
             |> assign_game_state(new_state)
             |> assign(selected_square: nil)
             |> assign(promotion_prompt: nil)
             |> assign(last_event: {:move_applied, Map.put(move, :promote, promote?)})}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(promotion_prompt: nil)
             |> assign(last_event: {:move_error, reason})}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("request_review", _params, socket) do
    entry = %{
      by: socket.assigns.game_state.turn,
      verdict: :draw,
      decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    state = Game.log_request(socket.assigns.game_state, entry)

    {:noreply,
     socket
     |> assign_game_state(state)
     |> assign(request_modal: %{verdict: :draw, entry: entry})
     |> assign(last_event: {:request, entry})}
  end

  @impl true
  def handle_event("close_request_modal", _params, socket) do
    {:noreply, assign(socket, request_modal: nil)}
  end

  @impl true
  def handle_event("resign", _params, socket) do
    if game_over?(socket.assigns.game_state) do
      {:noreply, socket}
    else
      loser = socket.assigns.game_state.turn
      winner = Game.opponent(loser)
      result = %{type: :resign, winner: winner, loser: loser}
      state = Game.record_result(socket.assigns.game_state, result)

      {:noreply,
       socket
       |> assign_game_state(state)
       |> assign(selected_square: nil)
       |> assign(promotion_prompt: nil)
       |> assign(last_event: {:resign, loser})}
    end
  end

  defp parse_coordinates(file, rank) do
    {
      parse_int(file),
      parse_int(rank)
    }
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_binary(value), do: String.to_integer(value)

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @promotion_prompt do %>
      <div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/70">
        <div class="w-full max-w-md rounded-xl border border-amber-400/60 bg-slate-900 p-6 shadow-xl">
          <h2 class="text-xl font-semibold text-amber-300">成りますか？</h2>
          <p class="mt-2 text-sm text-slate-200">
            {move_text(@promotion_prompt.move)}
          </p>
          <div class="mt-6 flex justify-end gap-3">
            <button
              phx-click="promotion_decision"
              phx-value-decision="decline"
              class="rounded border border-slate-600 px-4 py-2 text-sm text-slate-200 hover:bg-slate-800"
            >
              不成
            </button>
            <button
              phx-click="promotion_decision"
              phx-value-decision="promote"
              class="rounded bg-amber-500 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-amber-400"
            >
              成
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @request_modal do %>
      <div class="fixed inset-0 z-30 flex items-center justify-center bg-slate-950/60">
        <div class="w-full max-w-md rounded-xl border border-slate-700 bg-slate-900 p-5 text-slate-100 shadow-lg">
          <h2 class="text-lg font-semibold">リクエスト判定（仮）</h2>
          <p class="mt-2 text-sm text-slate-300">判定: 引き分け（対局は続行しません）</p>
          <button
            phx-click="close_request_modal"
            class="mt-6 rounded bg-slate-700 px-4 py-2 text-sm hover:bg-slate-600"
          >
            閉じる
          </button>
        </div>
      </div>
    <% end %>

    <div class="min-h-screen bg-slate-900 py-10">
      <div class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-6 text-slate-100">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h1 class="text-3xl font-semibold">闘魂AI将棋 - 対局ボード</h1>
          <div class="flex flex-wrap gap-2">
            <button
              phx-click="request_review"
              class="rounded border border-amber-500 px-4 py-2 text-sm font-medium text-amber-300 hover:bg-amber-500/10"
              disabled={moves_blocked?(@promotion_prompt, @game_state)}
            >
              リクエスト
            </button>
            <button
              phx-click="resign"
              class="rounded border border-red-500 px-4 py-2 text-sm font-medium text-red-300 hover:bg-red-500/10"
              disabled={game_over?(@game_state)}
            >
              参りました
            </button>
            <button
              phx-click="reset_board"
              class="rounded bg-slate-700 px-4 py-2 text-sm font-medium hover:bg-slate-600"
            >
              盤面を初期化
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,_2fr)_minmax(0,_1fr)]">
          <div class="flex flex-col items-center gap-4">
            <%= if result = game_result(@game_state) do %>
              <p class="rounded border border-amber-500/40 bg-amber-500/10 px-4 py-2 text-sm text-amber-200">
                対局終了: {result_message(result)}
              </p>
            <% else %>
              <p class="text-sm uppercase tracking-wide text-slate-300">
                現在の手番:
                <span class="font-semibold text-amber-300">{turn_label(@game_state.turn)}</span>
              </p>
            <% end %>

            <BoardComponents.board
              board={@game_state.board}
              selected_square={@selected_square}
              disabled={moves_blocked?(@promotion_prompt, @game_state)}
            />
          </div>

          <div class="flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-800 p-4">
            <h2 class="text-lg font-semibold text-slate-200">操作ログ</h2>
            <div class="rounded bg-slate-900/60 p-3 text-xs text-slate-300">
              <%= case @last_event do %>
                <% {:pick, {file, rank}} -> %>
                  <p>選択: {Notation.square_label({file, rank})}</p>
                <% {:drop, {file, rank}} -> %>
                  <p>ドロップ: {Notation.square_label({file, rank})}（駒はまだ移動しません）</p>
                <% {:move_applied, %{notation: notation}} -> %>
                  <p>移動: {notation}</p>
                <% {:move_error, reason} -> %>
                  <p>移動エラー: {inspect(reason)}</p>
                <% {:request, entry} -> %>
                  <p>リクエスト送信: {turn_label(entry.by)}</p>
                <% {:resign, side} -> %>
                  <p>{turn_label(side)} が参りました</p>
                <% {:not_your_piece, {file, rank}} -> %>
                  <p>選べません: {Notation.square_label({file, rank})} の駒は相手の持ち駒</p>
                <% {:empty_square, {file, rank}} -> %>
                  <p>空きマス {Notation.square_label({file, rank})}</p>
                <% :cancel_selection -> %>
                  <p>選択を解除しました</p>
                <% :reset -> %>
                  <p>盤面を初期化しました</p>
                <% {:await_promotion, move} -> %>
                  <p>成・不成の選択待ち: {move_text(move)}</p>
                <% nil -> %>
                  <p>まだ操作はありません</p>
              <% end %>
            </div>

            <div>
              <h3 class="text-sm font-semibold text-slate-200">選択中の駒</h3>
              <p class="mt-1 text-sm text-slate-300">
                <%= if @selected_square do %>
                  Notation.square_label(@selected_square)
                <% else %>
                  なし
                <% end %>
              </p>
            </div>

            <div>
              <h3 class="text-sm font-semibold text-slate-200">リクエスト履歴（最新）</h3>
              <p class="mt-1 text-xs text-slate-400">
                <%= if last_request = @game_state.metadata[:last_request] do %>
                  {turn_label(last_request.by)} が判定を要求 - 結果: 引き分け（仮）
                <% else %>
                  まだリクエストはありません
                <% end %>
              </p>
            </div>

            <div>
              <h3 class="text-sm font-semibold text-slate-200">API シリアライズ例</h3>
              <pre class="mt-1 max-h-64 overflow-auto rounded bg-slate-900/60 p-3 text-[10px] leading-4 text-slate-300"><%= Jason.encode_to_iodata!(Game.serialize(@game_state)) %></pre>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp turn_label(:sente), do: "先手"
  defp turn_label(:gote), do: "後手"

  defp assign_game_state(socket, %State{} = state) do
    assign(socket, game_state: state, serialized: Game.serialize(state))
  end

  defp moves_blocked?(socket) when is_map(socket) do
    moves_blocked?(socket.assigns.promotion_prompt, socket.assigns.game_state)
  end

  defp moves_blocked?(promotion_prompt, state) do
    not is_nil(promotion_prompt) or game_over?(state)
  end

  defp game_over?(%State{metadata: metadata}) do
    not is_nil(Map.get(metadata, :result))
  end

  defp handle_move(socket, from, to) do
    cond do
      from == to ->
        updated_state = State.merge_metadata(socket.assigns.game_state, %{selected_piece: nil})

        {:noreply,
         socket
         |> assign_game_state(updated_state)
         |> assign(selected_square: nil)
         |> assign(last_event: :cancel_selection)}

      true ->
        board = socket.assigns.game_state.board

        with {:ok, %Piece{} = piece} <- Board.fetch(board, from) do
          case Board.fetch(board, to) do
            {:ok, %Piece{} = own_piece} when own_piece.owner == piece.owner ->
              updated_state =
                State.merge_metadata(socket.assigns.game_state, %{selected_piece: own_piece.id})

              {:noreply,
               socket
               |> assign_game_state(updated_state)
               |> assign(selected_square: to)
               |> assign(last_event: {:pick, to})}

            _ ->
              apply_or_prompt_move(socket, piece, from, to)
          end
        else
          _ -> {:noreply, assign(socket, last_event: {:move_error, :no_piece})}
        end
    end
  end

  defp apply_or_prompt_move(socket, piece, from, to) do
    move = %{from: from, to: to}

    if promotion_applicable?(piece, from, to) do
      state = State.merge_metadata(socket.assigns.game_state, %{pending_move: move})

      {:noreply,
       socket
       |> assign_game_state(state)
       |> assign(selected_square: nil)
       |> assign(promotion_prompt: %{move: move})
       |> assign(last_event: {:await_promotion, move})}
    else
      case Game.apply_move(socket.assigns.game_state, move, promote: false) do
        {:ok, new_state} ->
          move_info =
            move
            |> Map.put(:promote, false)
            |> Map.put(:notation, Notation.move_label(from, to, false))

          {:noreply,
           socket
           |> assign_game_state(new_state)
           |> assign(selected_square: nil)
           |> assign(last_event: {:move_applied, move_info})}

        {:error, reason} ->
          {:noreply, assign(socket, last_event: {:move_error, reason})}
      end
    end
  end

  defp promotion_applicable?(%Piece{promoted: true}, _from, _to), do: false

  defp promotion_applicable?(
         %Piece{type: type} = piece,
         {_from_file, from_rank},
         {_to_file, to_rank}
       ) do
    promotable_type?(type) and
      (in_promotion_zone?(piece.owner, from_rank) or in_promotion_zone?(piece.owner, to_rank))
  end

  defp promotable_type?(type), do: type in [:hisya, :kaku, :gin, :kei, :kyo, :fu]

  defp in_promotion_zone?(:sente, rank) when rank >= 7, do: true
  defp in_promotion_zone?(:gote, rank) when rank <= 3, do: true
  defp in_promotion_zone?(_, _), do: false

  defp move_text(%{from: from, to: to} = move) do
    Notation.move_label(from, to, Map.get(move, :promote, false))
  end

  defp game_result(%State{metadata: metadata}), do: Map.get(metadata, :result)

  defp result_message(%{type: :resign, winner: winner, loser: loser}) do
    "#{turn_label(winner)}の勝ち（#{turn_label(loser)}が参りました）"
  end

  defp result_message(%{type: :draw}), do: "引き分け"
  defp result_message(%{type: other}), do: "決着: #{inspect(other)}"
end
