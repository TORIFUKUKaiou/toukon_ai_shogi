defmodule ToukonAiShogi.Game.Piece do
  @moduledoc """
  駒の構造体。LiveView の DOM キーとして使えるよう `id` を必須とする。
  """

  @enforce_keys [:id, :type, :owner]
  defstruct [:id, :type, :owner, promoted: false]

  @type type ::
          :gyoku
          | :hisya
          | :kaku
          | :kin
          | :gin
          | :kei
          | :kyo
          | :fu
          | :ryu
          | :uma
          | :narigin
          | :narikei
          | :narikyo
          | :tokin

  @type t :: %__MODULE__{
          id: String.t(),
          type: type(),
          owner: :sente | :gote,
          promoted: boolean()
        }
end
