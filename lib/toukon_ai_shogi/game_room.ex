defmodule ToukonAiShogi.GameRoom do
  @moduledoc false

  use GenServer

  alias ToukonAiShogi.Game
  alias ToukonAiShogi.Game.State
  alias ToukonAiShogi.GameSessions

  def start_link(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    players = Keyword.fetch!(opts, :players)

    GenServer.start_link(__MODULE__, %{room_id: room_id, players: players}, name: via(room_id))
  end

  def via(room_id), do: {:via, Registry, {ToukonAiShogi.GameRoomRegistry, room_id}}

  def attach(room_id, user) do
    GenServer.call(via(room_id), {:attach, user})
  end

  def get_snapshot(room_id) do
    GenServer.call(via(room_id), :snapshot)
  end

  def apply_move(room_id, user_id, move, opts) do
    GenServer.call(via(room_id), {:apply_move, user_id, move, opts})
  end

  def drop_piece(room_id, user_id, piece_id, to) do
    GenServer.call(via(room_id), {:drop_piece, user_id, piece_id, to})
  end

  def promotion_pending?(room_id) do
    GenServer.call(via(room_id), :promotion_pending?)
  end

  def request_review(room_id, user_id) do
    GenServer.call(via(room_id), {:request_review, user_id})
  end

  def resign(room_id, user_id) do
    GenServer.call(via(room_id), {:resign, user_id})
  end

  @impl true
  def init(%{room_id: room_id, players: players}) do
    assignments = %{
      sente: normalize_player(players.sente),
      gote: normalize_player(players.gote)
    }

    state = %{
      room_id: room_id,
      players: assignments,
      by_user_id: %{
        assignments.sente.id => :sente,
        assignments.gote.id => :gote
      },
      sockets: MapSet.new(),
      game_state: Game.new(metadata: %{result: nil}),
      last_broadcast: nil
    }

    GameSessions.create_session(%{
      room_id: room_id,
      sente_user_id: assignments.sente.id,
      gote_user_id: assignments.gote.id
    })

    broadcast(room_id, {:state, state.game_state})

    {:ok, state}
  end

  @impl true
  def handle_call({:attach, user}, _from, state) do
    role = Map.get(state.by_user_id, user.id)

    if role do
      {:reply, {:ok, %{role: role, game_state: state.game_state, players: state.players}}, state}
    else
      {:reply, {:error, :not_authorized}, state}
    end
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, state.game_state}, state}
  end

  def handle_call(:promotion_pending?, _from, state) do
    {:reply, {:ok, state.game_state.metadata[:pending_move]}, state}
  end

  def handle_call({:apply_move, user_id, move, opts}, _from, state) do
    role = Map.get(state.by_user_id, user_id)

    cond do
      role == nil ->
        {:reply, {:error, :not_authorized}, state}

      state.game_state.metadata[:result] ->
        {:reply, {:error, :game_finished}, state}

      state.game_state.turn != role ->
        {:reply, {:error, :not_players_turn}, state}

      true ->
        case Game.apply_move(state.game_state, move, opts) do
          {:ok, %State{} = new_state} ->
            broadcast(state.room_id, {:state, new_state})

            maybe_finish_session(state, new_state)

            {:reply, {:ok, new_state}, %{state | game_state: new_state}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:drop_piece, user_id, piece_id, to}, _from, state) do
    role = Map.get(state.by_user_id, user_id)

    cond do
      role == nil ->
        {:reply, {:error, :not_authorized}, state}

      state.game_state.metadata[:result] ->
        {:reply, {:error, :game_finished}, state}

      true ->
        case Game.drop_piece(state.game_state, role, piece_id, to) do
          {:ok, %State{} = new_state} ->
            broadcast(state.room_id, {:state, new_state})

            {:reply, {:ok, new_state}, %{state | game_state: new_state}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:request_review, user_id}, _from, state) do
    role = Map.get(state.by_user_id, user_id)

    if role do
      entry = %{
        by: role,
        verdict: :draw,
        decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      new_state = Game.log_request(state.game_state, entry)
      broadcast(state.room_id, {:state, new_state})
      {:reply, {:ok, entry}, %{state | game_state: new_state}}
    else
      {:reply, {:error, :not_authorized}, state}
    end
  end

  def handle_call({:resign, user_id}, _from, state) do
    role = Map.get(state.by_user_id, user_id)

    cond do
      role == nil ->
        {:reply, {:error, :not_authorized}, state}

      state.game_state.metadata[:result] ->
        {:reply, {:error, :game_finished}, state}

      true ->
        winner = Game.opponent(role)
        result = %{type: :resign, winner: winner, loser: role}
        new_game_state = Game.record_result(state.game_state, result)

        broadcast(state.room_id, {:state, new_game_state})
        finalize_session(state, new_game_state, %{type: :resign, winner_role: winner})

        {:reply, {:ok, result}, %{state | game_state: new_game_state}}
    end
  end

  defp maybe_finish_session(
         room_state,
         %State{metadata: %{result: %{type: type} = result}} = game_state
       ) do
    finalize_session(room_state, game_state, %{type: type, winner_role: result.winner})
  end

  defp maybe_finish_session(_, _), do: :ok

  defp finalize_session(room_state, %State{} = game_state, %{type: type, winner_role: winner_role}) do
    GameSessions.finish_session(room_state.room_id, %{
      result_type: Atom.to_string(type),
      winner_role: winner_role && Atom.to_string(winner_role),
      winner_user_id: winner_role && player_id(room_state, winner_role),
      ended_at: DateTime.utc_now() |> DateTime.truncate(:second),
      move_log: game_state.move_log,
      request_log: game_state.request_log
    })
  end

  defp player_id(state, role) do
    state.players |> Map.fetch!(role) |> Map.fetch!(:id)
  end

  defp broadcast(room_id, payload) do
    Phoenix.PubSub.broadcast(ToukonAiShogi.PubSub, "game_room:" <> room_id, payload)
  end

  defp normalize_player(%{id: id, display_name: name}) do
    %{id: id, display_name: name}
  end
end
