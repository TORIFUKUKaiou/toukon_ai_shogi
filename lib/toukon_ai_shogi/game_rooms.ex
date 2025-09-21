defmodule ToukonAiShogi.GameRooms do
  @moduledoc """
  Supervises `ToukonAiShogi.GameRoom` processes and provides a public API.
  """

  alias ToukonAiShogi.GameRoom
  alias ToukonAiShogi.Accounts.User

  @supervisor ToukonAiShogi.GameRoomSupervisor
  @registry ToukonAiShogi.GameRoomRegistry

  def start_room(%{room_id: room_id} = attrs) do
    players = Map.fetch!(attrs, :players)

    child_spec = {GameRoom, room_id: room_id, players: players}
    DynamicSupervisor.start_child(@supervisor, child_spec)
  end

  def ensure_room(room_id), do: lookup(room_id)

  def attach(room_id, %User{} = user) do
    GameRoom.attach(room_id, user)
  end

  def get_state(room_id) do
    with {:ok, :found} <- lookup(room_id) do
      GameRoom.get_snapshot(room_id)
    end
  end

  def promotion_pending?(room_id) do
    with {:ok, :found} <- lookup(room_id) do
      GameRoom.promotion_pending?(room_id)
    end
  end

  def apply_move(room_id, user_id, move, opts) do
    with {:ok, :found} <- lookup(room_id) do
      GameRoom.apply_move(room_id, user_id, move, opts)
    end
  end

  def drop_piece(room_id, user_id, piece_id, to) do
    with {:ok, :found} <- lookup(room_id) do
      GameRoom.drop_piece(room_id, user_id, piece_id, to)
    end
  end

  def request_review(room_id, user_id) do
    with {:ok, :found} <- lookup(room_id) do
      GameRoom.request_review(room_id, user_id)
    end
  end

  def resign(room_id, user_id) do
    with {:ok, :found} <- lookup(room_id) do
      GameRoom.resign(room_id, user_id)
    end
  end

  def subscribe(room_id) do
    Phoenix.PubSub.subscribe(ToukonAiShogi.PubSub, "game_room:" <> room_id)
  end

  defp lookup(room_id) do
    case Registry.lookup(@registry, room_id) do
      [{_pid, _value}] -> {:ok, :found}
      [] -> {:error, :not_found}
    end
  end
end
