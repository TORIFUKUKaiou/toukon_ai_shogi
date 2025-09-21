defmodule ToukonAiShogi.Matchmaking do
  @moduledoc """
  Simple in-memory matchmaking queue that pairs two players into a game room.
  """

  use GenServer

  alias Ecto.UUID
  alias ToukonAiShogi.GameRooms
  alias ToukonAiShogi.Accounts.Scope

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def join(scope, pid) do
    GenServer.call(__MODULE__, {:join, scope, pid})
  end

  def leave(user_id) do
    GenServer.cast(__MODULE__, {:leave, user_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{waiting: nil}}
  end

  @impl true
  def handle_call({:join, %Scope{user: nil}, _pid}, _from, state) do
    {:reply, {:error, :unauthenticated}, state}
  end

  def handle_call({:join, %Scope{user: _user} = scope, pid}, from, %{waiting: nil} = state) do
    monitor_ref = Process.monitor(pid)

    {:reply, {:ok, :waiting},
     %{state | waiting: %{scope: scope, pid: pid, from: from, monitor_ref: monitor_ref}}}
  end

  def handle_call({:join, %Scope{user: user} = scope, _pid}, _from, %{waiting: waiting} = state) do
    %{scope: waiting_scope, pid: waiting_pid, from: waiting_from, monitor_ref: monitor_ref} =
      waiting

    if waiting_scope.user.id == user.id do
      {:reply, {:error, :already_waiting}, state}
    else
      Process.demonitor(monitor_ref, [:flush])

      {assignments, room_payload} = build_room(scope, waiting_scope)
      {:ok, _pid} = GameRooms.start_room(room_payload)

      send(waiting_pid, {:match_found, assignments})
      GenServer.reply(waiting_from, {:matched, assignments})

      {:reply, {:matched, assignments}, %{state | waiting: nil}}
    end
  end

  @impl true
  def handle_cast(
        {:leave, user_id},
        %{waiting: %{scope: %{user: %{id: user_id}}, monitor_ref: ref}} = state
      ) do
    Process.demonitor(ref, [:flush])
    {:noreply, %{state | waiting: nil}}
  end

  def handle_cast({:leave, _user_id}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{waiting: %{monitor_ref: ref}} = state) do
    {:noreply, %{state | waiting: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp build_room(%Scope{user: u1}, %Scope{user: u2}) do
    room_id = UUID.generate()

    roles = Enum.zip([:sente, :gote], Enum.shuffle([u1, u2]))

    player_entries =
      Enum.reduce(roles, %{}, fn {role, user}, acc ->
        Map.put(acc, role, %{id: user.id, display_name: display_name(user)})
      end)

    assignments = Map.put(player_entries, :room_id, room_id)

    payload = %{
      room_id: room_id,
      players: %{sente: player_entries[:sente], gote: player_entries[:gote]}
    }

    {assignments, payload}
  end

  defp display_name(user) do
    user.display_name || user.email
  end
end
