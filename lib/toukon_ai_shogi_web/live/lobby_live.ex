defmodule ToukonAiShogiWeb.LobbyLive do
  use ToukonAiShogiWeb, :live_view

  alias ToukonAiShogi.Matchmaking
  alias ToukonAiShogiWeb.Presence

  @lobby_topic "lobby"

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    user = scope.user

    socket =
      socket
      |> assign(:user, user)
      |> assign(:queue_status, :idle)
      |> assign(:error_message, nil)
      |> assign(:online_players, [])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ToukonAiShogi.PubSub, @lobby_topic)
      Presence.track(self(), @lobby_topic, user.id, %{name: display_name(user)})
    end

    {:ok, assign(socket, :online_players, list_presence())}
  end

  @impl true
  def handle_event("queue", _params, socket) do
    case socket.assigns.queue_status do
      :waiting ->
        {:noreply, socket}

      :idle ->
        case Matchmaking.join(socket.assigns.current_scope, self()) do
          {:matched, assignments} ->
            {:noreply, push_navigate_to_game(socket, assignments)}

          {:error, reason} ->
            {:noreply, assign(socket, error_message: error_text(reason))}

          {:ok, :waiting} ->
            {:noreply, assign(socket, queue_status: :waiting, error_message: nil)}
        end
    end
  end

  def handle_event("cancel", _params, socket) do
    if socket.assigns.queue_status == :waiting do
      Matchmaking.leave(socket.assigns.user.id)
    end

    {:noreply, assign(socket, queue_status: :idle)}
  end

  @impl true
  def handle_info({:match_found, assignments}, socket) do
    {:noreply, push_navigate_to_game(socket, assignments)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: topic, event: "presence_diff"}, socket)
      when topic == @lobby_topic do
    {:noreply, assign(socket, :online_players, list_presence())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns.queue_status == :waiting do
      Matchmaking.leave(socket.assigns.user.id)
    end

    Presence.untrack(self(), @lobby_topic, socket.assigns.user.id)
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 py-10">
      <div class="mx-auto flex w-full max-w-3xl flex-col gap-6 px-6 text-slate-100">
        <div>
          <h1 class="text-3xl font-semibold">ロビー</h1>
          <p class="text-sm text-slate-300">オンライン: <%= length(@online_players) %> 名</p>
        </div>

        <div class="flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-800 p-4">
          <button
            phx-click="queue"
            class="w-full rounded bg-amber-500 px-4 py-3 text-center text-sm font-semibold text-slate-900 hover:bg-amber-400 disabled:bg-slate-500"
            disabled={@queue_status == :waiting}
          >
            <%= if @queue_status == :waiting, do: "マッチング待機中...", else: "対局相手を探す" %>
          </button>

          <%= if @queue_status == :waiting do %>
            <p class="text-xs text-slate-300">ブラウザを閉じるとマッチング待機が解除されます。</p>
          <% end %>

          <%= if @error_message do %>
            <p class="rounded border border-red-500/50 bg-red-500/10 px-3 py-2 text-sm text-red-200">
              <%= @error_message %>
            </p>
          <% end %>
        </div>

        <div class="rounded-lg border border-slate-700 bg-slate-800 p-4">
          <h2 class="text-lg font-semibold">オンラインプレイヤー</h2>
          <%= if Enum.empty?(@online_players) do %>
            <p class="mt-2 text-sm text-slate-300">現在ロビーにいるのはあなた一人です。</p>
          <% else %>
            <ul class="mt-2 space-y-1 text-sm text-slate-200">
              <%= for name <- @online_players do %>
                <li><%= name %></li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp push_navigate_to_game(socket, assignments) do
    socket
    |> assign(queue_status: :idle, error_message: nil)
    |> push_navigate(to: ~p"/game/#{assignments[:room_id]}")
  end

  defp list_presence do
    Presence.list(@lobby_topic)
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.name end)
    |> Enum.sort()
  end

  defp display_name(user), do: user.display_name || user.email

  defp error_text(:unauthenticated), do: "ログインが必要です"
  defp error_text(:already_waiting), do: "既にマッチング待機中です"
  defp error_text(:not_authorized), do: "許可されていません"
  defp error_text(_), do: "マッチングに失敗しました"
end
