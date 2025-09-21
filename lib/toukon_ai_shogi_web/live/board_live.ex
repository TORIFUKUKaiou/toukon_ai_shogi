defmodule ToukonAiShogiWeb.BoardLive do
  use ToukonAiShogiWeb, :live_view

  alias ToukonAiShogi.Game
  alias ToukonAiShogi.Game.{Board, State}
  alias ToukonAiShogiWeb.BoardComponents

  @impl true
  def mount(_params, _session, socket) do
    game_state = Game.new()

    {:ok,
     socket
     |> assign(game_state: game_state)
     |> assign(serialized: Game.serialize(game_state))
     |> assign(selected_square: nil)
     |> assign(last_event: nil)}
  end

  @impl true
  def handle_event("square_clicked", %{"file" => file, "rank" => rank}, socket) do
    {file, rank} = parse_coordinates(file, rank)
    board = socket.assigns.game_state.board

    case {socket.assigns.selected_square, Board.fetch(board, {file, rank})} do
      {nil, {:ok, piece}} ->
        updated_state =
          State.merge_metadata(socket.assigns.game_state, %{selected_piece: piece.id})

        {:noreply,
         socket
         |> assign(game_state: updated_state)
         |> assign(selected_square: {file, rank})
         |> assign(last_event: {:pick, {file, rank}})}

      {{^file, ^rank}, _} ->
        updated_state = State.merge_metadata(socket.assigns.game_state, %{selected_piece: nil})

        {:noreply,
         socket
         |> assign(game_state: updated_state)
         |> assign(selected_square: nil)
         |> assign(last_event: :cancel_selection)}

      {selected, _} when is_tuple(selected) ->
        updated_state =
          State.merge_metadata(socket.assigns.game_state, %{
            selected_piece: nil,
            pending_move: %{from: selected, to: {file, rank}}
          })

        {:noreply,
         socket
         |> assign(game_state: updated_state)
         |> assign(selected_square: nil)
         |> assign(last_event: {:drop, {file, rank}})}

      {nil, :error} ->
        {:noreply, assign(socket, last_event: {:empty_square, {file, rank}})}
    end
  end

  @impl true
  def handle_event("reset_board", _params, socket) do
    game_state = Game.new()

    {:noreply,
     socket
     |> assign(game_state: game_state, serialized: Game.serialize(game_state))
     |> assign(selected_square: nil, last_event: :reset)}
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
    <div class="min-h-screen bg-slate-900 py-10">
      <div class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-6 text-slate-100">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-semibold">闘魂AI将棋 - 対局ボード</h1>
          <button
            phx-click="reset_board"
            class="rounded bg-slate-700 px-4 py-2 text-sm font-medium hover:bg-slate-600"
          >
            盤面を初期化
          </button>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,_2fr)_minmax(0,_1fr)]">
          <div class="flex flex-col items-center gap-4">
            <p class="text-sm uppercase tracking-wide text-slate-300">
              現在の手番: <span class="font-semibold text-amber-300">{turn_label(@game_state.turn)}</span>
            </p>

            <BoardComponents.board
              board={@game_state.board}
              selected_square={@selected_square}
            />
          </div>

          <div class="flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-800 p-4">
            <h2 class="text-lg font-semibold text-slate-200">操作ログ</h2>
            <div class="rounded bg-slate-900/60 p-3 text-xs text-slate-300">
              <%= case @last_event do %>
                <% {:pick, {file, rank}} -> %>
                  <p>選択: {file}筋{rank}段</p>
                <% {:drop, {file, rank}} -> %>
                  <p>ドロップ: {file}筋{rank}段（駒はまだ移動しません）</p>
                <% {:empty_square, {file, rank}} -> %>
                  <p>空きマス ({file}, {rank})</p>
                <% :cancel_selection -> %>
                  <p>選択を解除しました</p>
                <% :reset -> %>
                  <p>盤面を初期化しました</p>
                <% nil -> %>
                  <p>まだ操作はありません</p>
              <% end %>
            </div>

            <div>
              <h3 class="text-sm font-semibold text-slate-200">選択中の駒</h3>
              <p class="mt-1 text-sm text-slate-300">
                <%= if @selected_square do %>
                  {elem(@selected_square, 1)}段 {elem(@selected_square, 0)}筋
                <% else %>
                  なし
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
end
