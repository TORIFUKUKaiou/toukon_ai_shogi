defmodule ToukonAiShogi.GameSessions do
  @moduledoc """
  Persistence helpers for finished game sessions.
  """

  import Ecto.Query, warn: false
  alias ToukonAiShogi.Repo
  alias ToukonAiShogi.GameSessions.GameSession

  def create_session(attrs) do
    %GameSession{}
    |> GameSession.creation_changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  def finish_session(room_id, attrs) do
    Repo.transaction(fn ->
      session = Repo.get_by!(GameSession, room_id: room_id)

      session
      |> GameSession.finalize_changeset(
        Map.merge(attrs, %{status: Map.get(attrs, :status, "finished")})
      )
      |> Repo.update()
    end)
  end
end
