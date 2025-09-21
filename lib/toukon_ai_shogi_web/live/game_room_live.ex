defmodule ToukonAiShogiWeb.GameRoomLive do
  use ToukonAiShogiWeb, :live_view

  alias ToukonAiShogi.GameRooms
  alias ToukonAiShogi.Game
  alias ToukonAiShogi.Game.{Board, Notation, Piece, State}
  alias ToukonAiShogiWeb.BoardComponents

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:user, user)
      |> assign(:selected_square, nil)
      |> assign(:selected_hand_piece, nil)
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
      coordinate = parse_coordinates(file, rank)

      case socket.assigns.selected_hand_piece do
        nil ->
          handle_board_square_click(socket, coordinate)

        selected_hand ->
          handle_hand_drop(socket, selected_hand, coordinate)
      end
    end
  end

  def handle_event("hand_piece_clicked", %{"piece_id" => piece_id}, socket) do
    cond do
      moves_blocked?(socket) ->
        {:noreply, socket}

      true ->
        case find_hand_piece(socket.assigns.game_state.captures, piece_id) do
          {:ok, owner, %Piece{} = piece} ->
            cond do
              socket.assigns.role != owner ->
                {:noreply, assign(socket, last_event: {:hand_not_yours, piece_id})}

              socket.assigns.game_state.turn != owner ->
                {:noreply, assign(socket, last_event: {:hand_error, :not_players_turn})}

              socket.assigns.selected_hand_piece &&
                  socket.assigns.selected_hand_piece.id == piece.id ->
                {:noreply,
                 socket
                 |> assign(selected_hand_piece: nil)
                 |> assign(last_event: :cancel_hand_selection)}

              true ->
                selected = %{id: piece.id, type: piece.type, owner: owner}

                {:noreply,
                 socket
                 |> assign(selected_hand_piece: selected)
                 |> assign(selected_square: nil)
                 |> assign(last_event: {:hand_pick, selected})}
            end

          :error ->
            {:noreply, assign(socket, last_event: {:hand_error, :not_found})}
        end
    end
  end

  def handle_event("promotion_decision", %{"decision" => decision}, socket) do
    move = socket.assigns.promotion_prompt.move
    promote? = decision == "promote"
    user_id = socket.assigns.current_scope.user.id

    case GameRooms.apply_move(socket.assigns.room_id, user_id, move, promote: promote?) do
      {:ok, _state} ->
        move_info =
          move
          |> Map.put(:promote, promote?)
          |> Map.put(:notation, Notation.move_label(move.from, move.to, promote?))

        {:noreply,
         socket
         |> assign(promotion_prompt: nil, selected_square: nil)
         |> assign(selected_hand_piece: nil)
         |> assign(last_event: {:move_applied, move_info})}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(promotion_prompt: nil)
         |> assign(selected_hand_piece: nil)
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
    {:noreply,
     assign(socket, selected_square: nil, promotion_prompt: nil, selected_hand_piece: nil)}
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

  defp handle_board_square_click(socket, {file, rank} = coordinate) do
    board = socket.assigns.game_state.board

    case {socket.assigns.selected_square, Board.fetch(board, coordinate)} do
      {nil, {:ok, %Piece{} = piece}} ->
        if owns_piece?(socket, piece) do
          {:noreply,
           socket
           |> assign(selected_square: coordinate)
           |> assign(selected_hand_piece: nil)
           |> assign(last_event: {:pick, coordinate})}
        else
          {:noreply,
           socket
           |> assign(selected_hand_piece: nil)
           |> assign(last_event: {:not_your_piece, coordinate})}
        end

      {nil, :error} ->
        {:noreply,
         socket
         |> assign(selected_hand_piece: nil)
         |> assign(last_event: {:empty_square, coordinate})}

      {{^file, ^rank}, _} ->
        {:noreply,
         socket
         |> assign(selected_square: nil)
         |> assign(selected_hand_piece: nil)
         |> assign(last_event: :cancel_selection)}

      {selected, _} when is_tuple(selected) ->
        handle_move(socket, selected, coordinate)
    end
  end

  defp handle_hand_drop(socket, selected_hand, coordinate) do
    case Board.fetch(socket.assigns.game_state.board, coordinate) do
      {:ok, _piece} ->
        {:noreply,
         socket
         |> assign(selected_square: nil)
         |> assign(last_event: {:drop_error, :occupied_square})}

      :error ->
        user_id = socket.assigns.current_scope.user.id

        case GameRooms.drop_piece(socket.assigns.room_id, user_id, selected_hand.id, coordinate) do
          {:ok, _state} ->
            drop_info = %{
              piece: selected_hand,
              to: coordinate,
              notation: Notation.drop_label(selected_hand.type, coordinate)
            }

            {:noreply,
             socket
             |> assign(selected_square: nil)
             |> assign(selected_hand_piece: nil)
             |> assign(last_event: {:drop_applied, drop_info})}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(selected_square: nil)
             |> assign(last_event: {:drop_error, reason})}
        end
    end
  end

  defp find_hand_piece(%{sente: sente, gote: gote}, piece_id) do
    case Enum.find(sente, &(&1.id == piece_id)) do
      %Piece{} = piece ->
        {:ok, :sente, piece}

      nil ->
        case Enum.find(gote, &(&1.id == piece_id)) do
          %Piece{} = piece -> {:ok, :gote, piece}
          nil -> :error
        end
    end
  end

  defp handle_move(socket, from, to) do
    board = socket.assigns.game_state.board
    user_id = socket.assigns.current_scope.user.id

    with {:ok, %Piece{} = piece} <- Board.fetch(board, from) do
      case Board.fetch(board, to) do
        {:ok, %Piece{} = target} when target.owner == piece.owner ->
          {:noreply,
           socket
           |> assign(selected_square: to)
           |> assign(selected_hand_piece: nil)
           |> assign(last_event: {:pick, to})}

        _ ->
          move = %{from: from, to: to}

          if promotion_applicable?(piece, from, to) do
            {:noreply,
             socket
             |> assign(selected_square: nil)
             |> assign(selected_hand_piece: nil)
             |> assign(promotion_prompt: %{move: move})
             |> assign(last_event: {:await_promotion, move})}
          else
            case GameRooms.apply_move(socket.assigns.room_id, user_id, move, promote: false) do
              {:ok, _state} ->
                move_info =
                  move
                  |> Map.put(:promote, false)
                  |> Map.put(:notation, Notation.move_label(from, to, false))

                {:noreply,
                 socket
                 |> assign(selected_square: nil)
                 |> assign(selected_hand_piece: nil)
                 |> assign(last_event: {:move_applied, move_info})}

              {:error, reason} ->
                {:noreply,
                 assign(socket, selected_hand_piece: nil, last_event: {:move_error, reason})}
            end
          end
      end
    else
      _ ->
        {:noreply, assign(socket, selected_hand_piece: nil, last_event: {:move_error, :no_piece})}
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

            <% player_role = player_role(@role) %>
            <% opponent_role = opponent_role(player_role) %>

            <div class="flex w-full flex-col items-center gap-6">
              <div class="flex w-full justify-start">
                <div class="max-w-[220px]">
                  <BoardComponents.hand
                    owner={opponent_role}
                    pieces={Map.get(@game_state.captures, opponent_role, [])}
                    perspective={board_perspective(@role)}
                    selected_piece_id={selected_hand_piece_id(@selected_hand_piece, opponent_role)}
                    disabled={hand_disabled?(@role, opponent_role, @promotion_prompt, @game_state)}
                  />
                </div>
              </div>

              <div class="flex justify-center">
                <BoardComponents.board
                  board={@game_state.board}
                  selected_square={@selected_square}
                  disabled={moves_blocked?(@promotion_prompt, @game_state)}
                  perspective={board_perspective(@role)}
                />
              </div>

              <div class="flex w-full justify-end">
                <div class="max-w-[220px]">
                  <BoardComponents.hand
                    owner={player_role}
                    pieces={Map.get(@game_state.captures, player_role, [])}
                    perspective={board_perspective(@role)}
                    selected_piece_id={selected_hand_piece_id(@selected_hand_piece, player_role)}
                    disabled={hand_disabled?(@role, player_role, @promotion_prompt, @game_state)}
                  />
                </div>
              </div>
            </div>
          </div>

          <div class="flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-800 p-4">
            <h2 class="text-lg font-semibold text-slate-200">操作ログ</h2>
            <div class="rounded bg-slate-900/60 p-3 text-xs text-slate-300">
              <%= case @last_event do %>
                <% {:pick, {file, rank}} -> %>
                  <p>選択: {Notation.square_label({file, rank})}</p>
                <% {:hand_pick, piece} -> %>
                  <p>持ち駒選択: {role_label(piece.owner)} {Piece.label(piece.type)}</p>
                <% :cancel_selection -> %>
                  <p>選択を解除しました</p>
                <% :cancel_hand_selection -> %>
                  <p>持ち駒の選択を解除しました</p>
                <% {:drop_applied, %{piece: piece, notation: notation}} -> %>
                  <p>打ち: {role_label(piece.owner)} {notation}</p>
                <% {:drop_error, reason} -> %>
                  <p>持ち駒打ちエラー: {drop_error_message(reason)}</p>
                <% {:move_applied, %{notation: notation}} -> %>
                  <p>移動: {notation}</p>
                <% {:move_error, reason} -> %>
                  <p>移動エラー: {inspect(reason)}</p>
                <% {:request, _entry} -> %>
                  <p>リクエストを送信しました（仮判定: 引き分け）</p>
                <% {:resign, side} -> %>
                  <p>{role_label(side)} が参りました</p>
                <% {:hand_not_yours, _} -> %>
                  <p>持ち駒は操作できません（あなたの駒台ではありません）</p>
                <% {:hand_error, :not_players_turn} -> %>
                  <p>持ち駒は相手の手番中です</p>
                <% {:hand_error, :not_found} -> %>
                  <p>持ち駒が見つかりませんでした</p>
                <% {:not_your_piece, {file, rank}} -> %>
                  <p>選べません: {Notation.square_label({file, rank})} の駒は相手の持ち駒</p>
                <% {:empty_square, {file, rank}} -> %>
                  <p>空きマス {Notation.square_label({file, rank})}</p>
                <% {:await_promotion, move} -> %>
                  <p>成・不成の選択待ち: {move_text(move)}</p>
                <% nil -> %>
                  <p>まだ操作はありません</p>
              <% end %>
            </div>

            <div>
              <h3 class="text-sm font-semibold text-slate-200">選択中の駒</h3>
              <p class="mt-1 text-sm text-slate-300">
                {selected_item_label(@selected_square, @selected_hand_piece)}
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

  defp player_role(nil), do: :sente
  defp player_role(role), do: role

  defp opponent_role(:sente), do: :gote
  defp opponent_role(:gote), do: :sente
  defp opponent_role(_), do: :gote

  defp hand_disabled?(role, owner, promotion_prompt, %State{metadata: metadata, turn: turn}) do
    role != owner or not is_nil(promotion_prompt) or not is_nil(metadata[:result]) or
      turn != owner
  end

  defp selected_hand_piece_id(nil, _owner), do: nil
  defp selected_hand_piece_id(%{owner: owner, id: id}, owner), do: id
  defp selected_hand_piece_id(_selected, _owner), do: nil

  defp drop_error_message(:occupied_square), do: "マスに駒が残っています"
  defp drop_error_message(:not_players_turn), do: "持ち駒はあなたの手番ではありません"
  defp drop_error_message(:piece_not_in_hand), do: "持ち駒の情報が最新ではありません"
  defp drop_error_message(other), do: "エラー: #{inspect(other)}"

  defp selected_item_label(_square, %{owner: owner, type: type}) do
    "#{role_label(owner)} の持ち駒 #{Piece.label(type)}"
  end

  defp selected_item_label({file, rank}, _hand) when is_integer(file) and is_integer(rank) do
    Notation.square_label({file, rank})
  end

  defp selected_item_label(_square, _hand), do: "なし"

  defp board_perspective(:gote), do: :gote
  defp board_perspective(_), do: :sente

  defp move_text(%{from: from, to: to} = move) do
    Notation.move_label(from, to, Map.get(move, :promote, false))
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
    not is_nil(promotion_prompt) or not is_nil(game_state.metadata[:result])
  end
end
