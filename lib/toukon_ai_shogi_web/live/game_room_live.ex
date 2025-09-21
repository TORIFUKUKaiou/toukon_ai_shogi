defmodule ToukonAiShogiWeb.GameRoomLive do
  use ToukonAiShogiWeb, :live_view

  alias ToukonAiShogi.GameRooms
  alias ToukonAiShogi.Game
  alias ToukonAiShogi.Game.Board
  alias ToukonAiShogi.Game.Piece
  alias ToukonAiShogi.Game.State
  alias ToukonAiShogiWeb.BoardComponents

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:user, user)
      |> assign(:selected_square, nil)
      |> assign(:promotion_prompt, nil)
      |> assign(:request_modal, nil)
      |> assign(:last_event, nil)
      |> assign(:role, nil)
      |> assign(:opponent, nil)

    if connected?(socket) do
      GameRooms.subscribe(room_id)
    end

    case GameRooms.attach(room_id, user) do
      {:ok, %{role: role, game_state: game_state, players: players}} ->
        opponent = opponent_info(players, role)

        {:ok,
         socket
         |> assign(:role, role)
         |> assign(:players, players)
         |> assign(:opponent, opponent)
         |> assign_game_state(game_state)}

      {:error, :not_authorized} ->
        {:ok,
         socket
         |> put_flash(:error, "対局に参加できません")
         |> push_navigate(to: ~p"/lobby")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "対局が見つかりません")
         |> push_navigate(to: ~p"/lobby")}
    end
  end

  @impl true
  def handle_event("square_clicked", %{"file" => file, "rank" => rank}, socket) do
    if moves_blocked?(socket) do
      {:noreply, socket}
    else
      {file, rank} = parse_coordinates(file, rank)
      board = socket.assigns.game_state.board

      case {socket.assigns.selected_square, Board.fetch(board, {file, rank})} do
        {nil, {:ok, %Piece{} = piece}} ->
          if owns_piece?(socket, piece) do
            {:noreply,
             socket
             |> assign(selected_square: {file, rank})
             |> assign(last_event: {:pick, {file, rank}})}
          else
            {:noreply, assign(socket, last_event: {:not_your_piece, {file, rank}})}
          end

        {nil, :error} ->
          {:noreply, assign(socket, last_event: {:empty_square, {file, rank}})}

        {{^file, ^rank}, _} ->
          {:noreply, assign(socket, selected_square: nil, last_event: :cancel_selection)}

        {selected, _} when is_tuple(selected) ->
          handle_move(socket, selected, {file, rank})
      end
    end
  end

  def handle_event("promotion_decision", %{"decision" => decision}, socket) do
    move = socket.assigns.promotion_prompt.move
    promote? = decision == "promote"
    user_id = socket.assigns.current_scope.user.id

    case GameRooms.apply_move(socket.assigns.room_id, user_id, move, promote: promote?) do
      {:ok, _state} ->
        {:noreply,
         socket
         |> assign(promotion_prompt: nil, selected_square: nil)
         |> assign(last_event: {:move_applied, Map.put(move, :promote, promote?)})}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(promotion_prompt: nil)
         |> assign(last_event: {:move_error, reason})}
    end
  end

  def handle_event("request_review", _params, socket) do
    user_id = socket.assigns.current_scope.user.id

    case GameRooms.request_review(socket.assigns.room_id, user_id) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> assign(request_modal: %{verdict: :draw, entry: entry})
         |> assign(last_event: {:request, entry})}

      {:error, reason} ->
        {:noreply, assign(socket, last_event: {:move_error, reason})}
    end
  end

  def handle_event("close_request_modal", _params, socket) do
    {:noreply, assign(socket, request_modal: nil)}
  end

  def handle_event("resign", _params, socket) do
    user_id = socket.assigns.current_scope.user.id

    case GameRooms.resign(socket.assigns.room_id, user_id) do
      {:ok, _result} ->
        {:noreply, assign(socket, last_event: {:resign, socket.assigns.role})}

      {:error, reason} ->
        {:noreply, assign(socket, last_event: {:move_error, reason})}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, selected_square: nil, promotion_prompt: nil)}
  end

  def handle_event("reset_board", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state, %State{} = state}, socket) do
    {:noreply, assign_game_state(socket, state)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp handle_move(socket, from, to) do
    board = socket.assigns.game_state.board
    user_id = socket.assigns.current_scope.user.id

    with {:ok, %Piece{} = piece} <- Board.fetch(board, from) do
      case Board.fetch(board, to) do
        {:ok, %Piece{} = target} when target.owner == piece.owner ->
          {:noreply,
           socket
           |> assign(selected_square: to)
           |> assign(last_event: {:pick, to})}

        _ ->
          move = %{from: from, to: to}

          if promotion_applicable?(piece, from, to) do
            {:noreply,
             socket
             |> assign(selected_square: nil)
             |> assign(promotion_prompt: %{move: move})
             |> assign(last_event: {:await_promotion, move})}
          else
            case GameRooms.apply_move(socket.assigns.room_id, user_id, move, promote: false) do
              {:ok, _state} ->
                {:noreply,
                 socket
                 |> assign(selected_square: nil)
                 |> assign(last_event: {:move_applied, Map.put(move, :promote, false)})}

              {:error, reason} ->
                {:noreply, assign(socket, last_event: {:move_error, reason})}
            end
          end
      end
    else
      _ -> {:noreply, assign(socket, last_event: {:move_error, :no_piece})}
    end
  end

  defp assign_game_state(socket, %State{} = state) do
    socket
    |> assign(:game_state, state)
    |> assign(:serialized, Game.serialize(state))
  end

  defp owns_piece?(socket, %Piece{owner: owner}), do: socket.assigns.role == owner

  defp promotion_applicable?(%Piece{promoted: true}, _from, _to), do: false

  defp promotion_applicable?(
         %Piece{type: type} = piece,
         {_from_file, from_rank},
         {_to_file, to_rank}
       ) do
    type in [:hisya, :kaku, :gin, :kei, :kyo, :fu] and
      (in_promotion_zone?(piece.owner, from_rank) or in_promotion_zone?(piece.owner, to_rank))
  end

  defp in_promotion_zone?(:sente, rank) when rank >= 7, do: true
  defp in_promotion_zone?(:gote, rank) when rank <= 3, do: true
  defp in_promotion_zone?(_, _), do: false

  defp parse_coordinates(file, rank) do
    {parse_int(file), parse_int(rank)}
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_binary(value), do: String.to_integer(value)

  defp opponent_info(players, role) do
    opponent_role = Game.opponent(role)
    Map.get(players, opponent_role)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 py-10">
      <div class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-6 text-slate-100">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-3xl font-semibold">闘魂AI将棋</h1>
            <p class="text-sm text-slate-300">
              あなた: {display_name(@user)}（{role_label(@role)}）
              <%= if @opponent do %>
                / 相手: {@opponent.display_name}
              <% end %>
            </p>
          </div>
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
              disabled={@game_state.metadata[:result]}
            >
              参りました
            </button>
            <button
              phx-click="cancel"
              class="rounded bg-slate-700 px-4 py-2 text-sm font-medium hover:bg-slate-600"
            >
              選択解除
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,_2fr)_minmax(0,_1fr)]">
          <div class="flex flex-col items-center gap-4">
            <%= if result = @game_state.metadata[:result] do %>
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
                  <p>選択: {file}筋{rank}段</p>
                <% {:move_applied, %{from: {from_file, from_rank}, to: {to_file, to_rank}, promote: promote?}} -> %>
                  <p>
                    移動: {from_file}筋{from_rank}段 → {to_file}筋{to_rank}段 {if promote?, do: "（成）"}
                  </p>
                <% {:move_error, reason} -> %>
                  <p>移動エラー: {inspect(reason)}</p>
                <% {:request, _entry} -> %>
                  <p>リクエストを送信しました（仮判定: 引き分け）</p>
                <% {:resign, side} -> %>
                  <p>{role_label(side)} が参りました</p>
                <% {:not_your_piece, {file, rank}} -> %>
                  <p>選べません: {file}筋{rank}段の駒は相手の持ち駒</p>
                <% {:empty_square, {file, rank}} -> %>
                  <p>空きマス ({file}, {rank})</p>
                <% :cancel_selection -> %>
                  <p>選択を解除しました</p>
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
                  {elem(@selected_square, 1)}段 {elem(@selected_square, 0)}筋
                <% else %>
                  なし
                <% end %>
              </p>
            </div>

            <div>
              <h3 class="text-sm font-semibold text-slate-200">API シリアライズ例</h3>
              <pre class="mt-1 max-h-64 overflow-auto rounded bg-slate-900/60 p-3 text-[10px] leading-4 text-slate-300"><%= Jason.encode_to_iodata!(@serialized) %></pre>
            </div>
          </div>
        </div>
      </div>

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
    </div>
    """
  end

  defp turn_label(:sente), do: "先手"
  defp turn_label(:gote), do: "後手"

  defp role_label(:sente), do: "先手"
  defp role_label(:gote), do: "後手"
  defp role_label(_), do: "観戦"

  defp move_text(%{from: {from_file, from_rank}, to: {to_file, to_rank}}) do
    "#{from_file}筋#{from_rank}段 → #{to_file}筋#{to_rank}段"
  end

  defp result_message(%{type: :resign, winner: winner, loser: loser}) do
    "#{role_label(winner)}の勝ち（#{role_label(loser)}が参りました）"
  end

  defp result_message(%{type: :draw}), do: "引き分け"
  defp result_message(%{type: other}), do: "決着: #{inspect(other)}"

  defp display_name(user), do: user.display_name || user.email

  defp moves_blocked?(socket) do
    moves_blocked?(socket.assigns.promotion_prompt, socket.assigns.game_state)
  end

  defp moves_blocked?(promotion_prompt, game_state) do
    (not is_nil(promotion_prompt)) or (not is_nil(game_state.metadata[:result]))
  end
end
