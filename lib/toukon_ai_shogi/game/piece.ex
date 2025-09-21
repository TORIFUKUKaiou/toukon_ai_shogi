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
  @spec label(type()) :: String.t()
  def label(:gyoku), do: "玉将"
  def label(:hisya), do: "飛車"
  def label(:kaku), do: "角行"
  def label(:kin), do: "金将"
  def label(:gin), do: "銀将"
  def label(:kei), do: "桂馬"
  def label(:kyo), do: "香車"
  def label(:fu), do: "歩兵"
  def label(:ryu), do: "龍王"
  def label(:uma), do: "龍馬"
  def label(:narigin), do: "成銀"
  def label(:narikei), do: "成桂"
  def label(:narikyo), do: "成香"
  def label(:tokin), do: "と金"
end
