defmodule ToukonAiShogiWeb.BoardComponents do
  @moduledoc """
  LiveView ボード表示用のコンポーネント群。
  """

  use ToukonAiShogiWeb, :html

  alias ToukonAiShogi.Game.Board
  alias ToukonAiShogi.Game.Piece

  @piece_assets %{
    gyoku: "syougi02_gyokusyou.png",
    hisya: "syougi03_hisya.png",
    ryu: "syougi04_ryuuou.png",
    kaku: "syougi05_gakugyou.png",
    uma: "syougi06_ryuuma.png",
    kin: "syougi07_kinsyou.png",
    gin: "syougi08_ginsyou.png",
    narigin: "syougi09_narigin.png",
    kei: "syougi10_keima.png",
    narikei: "syougi11_narikei.png",
    kyo: "syougi12_kyousya.png",
    narikyo: "syougi13_narikyou.png",
    fu: "syougi14_fuhyou.png",
    tokin: "syougi15_tokin.png"
  }

  attr :board, Board, required: true
  attr :selected_square, :any, default: nil
  attr :disabled, :boolean, default: false

  def board(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <div class="grid grid-cols-9 gap-[2px] bg-amber-800 p-[2px] shadow-lg">
        <%= for rank <- 9..1//-1, file <- 1..9 do %>
          <.board_square
            coordinate={{file, rank}}
            piece={Map.get(@board.squares, {file, rank})}
            selected_square={@selected_square}
            disabled={@disabled}
          />
        <% end %>
      </div>
      <p class="text-xs text-slate-300 opacity-80">
        駒をクリックして移動先を指定できます。成りが可能な場合は成／不成を選択してください。
      </p>
    </div>
    """
  end

  attr :coordinate, :any, required: true
  attr :piece, Piece, default: nil
  attr :selected_square, :any, default: nil
  attr :disabled, :boolean, default: false

  defp board_square(assigns) do
    assigns = assign(assigns, :selected?, assigns[:selected_square] == assigns.coordinate)

    ~H"""
    <button
      phx-click="square_clicked"
      phx-value-file={elem(@coordinate, 0)}
      phx-value-rank={elem(@coordinate, 1)}
      class={[
        "relative aspect-square bg-amber-200 transition",
        square_classes(@selected?, @disabled)
      ]}
      disabled={@disabled}
    >
      <%= if @piece do %>
        <.board_piece piece={@piece} />
      <% end %>
    </button>
    """
  end

  attr :piece, Piece, required: true

  defp board_piece(assigns) do
    assigns = assign(assigns, :asset_path, piece_asset(assigns.piece))

    ~H"""
    <img
      src={@asset_path}
      alt={piece_label(@piece)}
      class={[
        "mx-auto h-14 w-11 select-none drop-shadow",
        if(@piece.owner == :gote, do: "rotate-180", else: nil)
      ]}
      draggable="false"
    />
    """
  end

  defp square_classes(true, true), do: "ring-4 ring-amber-300/80 opacity-60 cursor-not-allowed"
  defp square_classes(true, false), do: "ring-4 ring-amber-400"
  defp square_classes(false, true), do: "opacity-60 cursor-not-allowed"
  defp square_classes(false, false), do: ""

  defp piece_asset(%Piece{type: type}) do
    filename = Map.fetch!(@piece_assets, type)
    ~p"/images/koma/#{filename}"
  end

  defp piece_label(%Piece{type: type, owner: owner}) do
    owner_label = if(owner == :sente, do: "先手", else: "後手")
    "#{owner_label} #{piece_name(type)}"
  end

  defp piece_name(:gyoku), do: "玉将"
  defp piece_name(:hisya), do: "飛車"
  defp piece_name(:ryu), do: "龍王"
  defp piece_name(:kaku), do: "角行"
  defp piece_name(:uma), do: "龍馬"
  defp piece_name(:kin), do: "金将"
  defp piece_name(:gin), do: "銀将"
  defp piece_name(:narigin), do: "成銀"
  defp piece_name(:kei), do: "桂馬"
  defp piece_name(:narikei), do: "成桂"
  defp piece_name(:kyo), do: "香車"
  defp piece_name(:narikyo), do: "成香"
  defp piece_name(:fu), do: "歩兵"
  defp piece_name(:tokin), do: "と金"
end
