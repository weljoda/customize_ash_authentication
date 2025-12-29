import Config
config :customize_ash_authentication, token_signing_secret: "/PZUUyvLSfdEnnTst+J9o6AhzXnLF1AP"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :customize_ash_authentication, CustomizeAshAuthentication.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "customize_ash_authentication_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :customize_ash_authentication, CustomizeAshAuthenticationWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "9JdO8mV39NFoKr5v3rVLxlmKHn2nSu/9FvGMxpjNdxW33P4mdIwIfPEIy6D4eROK",
  server: false

# In test we don't send emails
config :customize_ash_authentication, CustomizeAshAuthentication.Mailer,
  adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
