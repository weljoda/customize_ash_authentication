defmodule CustomizeAshAuthentication.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        CustomizeAshAuthentication.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:customize_ash_authentication, :token_signing_secret)
  end
end
