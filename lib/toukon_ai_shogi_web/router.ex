defmodule ToukonAiShogiWeb.Router do
  use ToukonAiShogiWeb, :router

  import ToukonAiShogiWeb.UserAuth

  @dev_routes Application.compile_env(:toukon_ai_shogi, :dev_routes, false)
  @mailbox_routes Application.compile_env(:toukon_ai_shogi, :mailbox_routes, false)

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ToukonAiShogiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ToukonAiShogiWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :public,
      on_mount: [{ToukonAiShogiWeb.UserAuth, :mount_current_scope}] do
      live "/board", BoardLive, :board
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ToukonAiShogiWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if @dev_routes do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ToukonAiShogiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if @mailbox_routes && !@dev_routes do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ToukonAiShogiWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", ToukonAiShogiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [{ToukonAiShogiWeb.UserAuth, :ensure_authenticated}] do
      live "/lobby", LobbyLive, :lobby
      live "/game/:room_id", GameRoomLive, :show
    end

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", ToukonAiShogiWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
