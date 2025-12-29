defmodule CustomizeAshAuthentication.Accounts do
  use Ash.Domain,
    otp_app: :customize_ash_authentication

  resources do
    resource CustomizeAshAuthentication.Accounts.Token
    resource CustomizeAshAuthentication.Accounts.User
  end
end
