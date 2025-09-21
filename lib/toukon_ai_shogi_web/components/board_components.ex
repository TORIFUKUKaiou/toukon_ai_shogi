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
  attr :perspective, :atom, default: :sente

  def board(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <div class="grid grid-cols-9 gap-[2px] bg-amber-800 p-[2px] shadow-lg">
        <%= for rank <- rank_sequence(@perspective), file <- file_sequence(@perspective) do %>
          <.board_square
            coordinate={{file, rank}}
            piece={Map.get(@board.squares, {file, rank})}
            selected_square={@selected_square}
            disabled={@disabled}
            perspective={@perspective}
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
  attr :perspective, :atom, default: :sente

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
        <.board_piece piece={@piece} perspective={@perspective} />
      <% end %>
    </button>
    """
  end

  attr :piece, Piece, required: true
  attr :perspective, :atom, default: :sente

  defp board_piece(assigns) do
    assigns = assign(assigns, :asset_path, piece_asset(assigns.piece))

    ~H"""
    <img
      src={@asset_path}
      alt={piece_label(@piece)}
      class={[
        "mx-auto h-14 w-11 select-none drop-shadow",
        piece_rotation_class(@piece, @perspective)
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
    "#{owner_label(owner)} #{Piece.label(type)}"
  end

  @hand_piece_order [
    :gyoku,
    :hisya,
    :kaku,
    :kin,
    :gin,
    :kei,
    :kyo,
    :fu,
    :ryu,
    :uma,
    :narigin,
    :narikei,
    :narikyo,
    :tokin
  ]

  attr :owner, :atom, required: true
  attr :pieces, :list, required: true
  attr :label, :string, default: nil
  attr :perspective, :atom, default: :sente
  attr :selected_piece_id, :string, default: nil
  attr :disabled, :boolean, default: false

  def hand(assigns) do
    assigns =
      assigns
      |> assign(:pieces, sort_hand_pieces(assigns.pieces))
      |> assign_new(:label, fn -> "#{owner_label(assigns.owner)}の持ち駒" end)

    ~H"""
    <div class="flex flex-col gap-2">
      <p class="text-xs font-semibold uppercase tracking-wide text-slate-300">{@label}</p>
      <div class="flex flex-wrap gap-2">
        <%= if Enum.empty?(@pieces) do %>
          <span class="rounded border border-slate-700 px-3 py-2 text-xs text-slate-400">なし</span>
        <% else %>
          <%= for piece <- @pieces do %>
            <button
              type="button"
              phx-click="hand_piece_clicked"
              phx-value-piece_id={piece.id}
              class={hand_piece_classes(piece.id == @selected_piece_id, @disabled)}
              disabled={@disabled}
            >
              <.board_piece piece={piece} perspective={@perspective} />
            </button>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp sort_hand_pieces(pieces) do
    Enum.sort_by(pieces, fn %Piece{type: type, id: id} -> {hand_sort_index(type), id} end)
  end

  defp hand_sort_index(type) do
    Enum.find_index(@hand_piece_order, &(&1 == type)) || length(@hand_piece_order)
  end

  defp hand_piece_classes(selected?, disabled?) do
    [
      "flex h-16 w-12 items-center justify-center rounded border border-amber-200/20 bg-amber-900/20 transition",
      if(selected?, do: "ring-2 ring-amber-400 bg-amber-700/30", else: nil),
      if(disabled?, do: "opacity-60 cursor-not-allowed", else: "hover:bg-amber-700/20")
    ]
  end

  defp owner_label(:sente), do: "先手"
  defp owner_label(:gote), do: "後手"
  defp owner_label(_), do: "観戦"

  defp rank_sequence(:gote), do: 1..9
  defp rank_sequence(_), do: 9..1//-1

  defp file_sequence(:gote), do: 9..1//-1
  defp file_sequence(_), do: 1..9

  defp piece_rotation_class(%Piece{owner: owner}, perspective) do
    cond do
      perspective == :sente and owner == :gote -> "rotate-180"
      perspective == :gote and owner == :sente -> "rotate-180"
      true -> nil
    end
  end
end
