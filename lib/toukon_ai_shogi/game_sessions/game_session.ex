defmodule ToukonAiShogi.GameSessions.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias ToukonAiShogi.Accounts.User

  schema "game_sessions" do
    field :room_id, :string
    field :status, :string, default: "in_progress"
    field :result_type, :string
    field :winner_role, :string
    field :ended_at, :utc_datetime
    field :move_log, :map
    field :request_log, :map
    field :rating_delta_sente, :integer, default: 0
    field :rating_delta_gote, :integer, default: 0

    belongs_to :sente_user, User
    belongs_to :gote_user, User
    belongs_to :winner_user, User

    timestamps(type: :utc_datetime)
  end

  def creation_changeset(session, attrs) do
    session
    |> cast(attrs, [:room_id, :sente_user_id, :gote_user_id, :status])
    |> validate_required([:room_id, :sente_user_id, :gote_user_id, :status])
    |> unique_constraint(:room_id)
  end

  def finalize_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :result_type,
      :winner_role,
      :winner_user_id,
      :ended_at,
      :move_log,
      :request_log,
      :rating_delta_sente,
      :rating_delta_gote
    ])
    |> validate_required([:status, :result_type, :ended_at])
  end
end
