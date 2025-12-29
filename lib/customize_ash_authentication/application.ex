defmodule CustomizeAshAuthentication.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CustomizeAshAuthenticationWeb.Telemetry,
      CustomizeAshAuthentication.Repo,
      {DNSCluster,
       query: Application.get_env(:customize_ash_authentication, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CustomizeAshAuthentication.PubSub},
      # Start a worker by calling: CustomizeAshAuthentication.Worker.start_link(arg)
      # {CustomizeAshAuthentication.Worker, arg},
      # Start to serve requests, typically the last entry
      CustomizeAshAuthenticationWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :customize_ash_authentication]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CustomizeAshAuthentication.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CustomizeAshAuthenticationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
