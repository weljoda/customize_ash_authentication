defmodule CustomizeAshAuthenticationWeb.Router do
  use CustomizeAshAuthenticationWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CustomizeAshAuthenticationWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", CustomizeAshAuthenticationWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {CustomizeAshAuthenticationWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {CustomizeAshAuthenticationWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {CustomizeAshAuthenticationWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", CustomizeAshAuthenticationWeb do
    pipe_through :browser

    get "/", PageController, :home
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{CustomizeAshAuthenticationWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    CustomizeAshAuthenticationWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  CustomizeAshAuthenticationWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route CustomizeAshAuthentication.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [
        CustomizeAshAuthenticationWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]

    # Remove this if you do not use the magic link strategy.
    # magic_sign_in_route(CustomizeAshAuthentication.Accounts.User, :magic_link,
    #   auth_routes_prefix: "/auth",
    #   overrides: [
    #     CustomizeAshAuthenticationWeb.AuthOverrides,
    #     Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
    #   ]
    # )

    live "/magic_link/:token", MagicSignIn, :show

    get "/documents/:type", DocumentController, :show
  end

  scope "/", CustomizeAshAuthenticationWeb do
    pipe_through [:browser, :put_ash_request_context_metadata]

    auth_routes AuthController, CustomizeAshAuthentication.Accounts.User, path: "/auth"
  end

  defp put_ash_request_context_metadata(conn, _opts) do
    ip =
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()
      |> AshAuthentication.AddOn.AuditLog.IpPrivacy.apply_privacy(:truncate, %{})

    user_agent =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()

    Ash.PlugHelpers.set_context(conn, %{shared: %{client_ip: ip, user_agent: user_agent}})
  end

  # Other scopes may use custom stacks.
  # scope "/api", CustomizeAshAuthenticationWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:customize_ash_authentication, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CustomizeAshAuthenticationWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
