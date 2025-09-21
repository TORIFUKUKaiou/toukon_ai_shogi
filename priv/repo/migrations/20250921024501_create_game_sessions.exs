defmodule ToukonAiShogi.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions) do
      add :room_id, :string, null: false
      add :sente_user_id, references(:users, on_delete: :nothing), null: false
      add :gote_user_id, references(:users, on_delete: :nothing), null: false
      add :status, :string, null: false, default: "in_progress"
      add :result_type, :string
      add :winner_role, :string
      add :winner_user_id, references(:users, on_delete: :nothing)
      add :ended_at, :utc_datetime
      add :move_log, :map, null: false, default: fragment("'[]'::jsonb")
      add :request_log, :map, null: false, default: fragment("'[]'::jsonb")
      add :rating_delta_sente, :integer, null: false, default: 0
      add :rating_delta_gote, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_sessions, [:room_id])
    create index(:game_sessions, [:sente_user_id])
    create index(:game_sessions, [:gote_user_id])
    create index(:game_sessions, [:winner_user_id])
  end
end
