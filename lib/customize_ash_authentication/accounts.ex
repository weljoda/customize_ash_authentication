defmodule CustomizeAshAuthentication.Accounts do
  use Ash.Domain,
    otp_app: :customize_ash_authentication

  resources do
    resource CustomizeAshAuthentication.Accounts.Token

    resource CustomizeAshAuthentication.Accounts.User do
      define :get_user_by_email,
        action: :get_by_email,
        args: [:email]
    end

    resource CustomizeAshAuthentication.Accounts.Profile
  end
end
