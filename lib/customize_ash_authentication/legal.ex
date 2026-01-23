defmodule CustomizeAshAuthentication.Legal do
  use Ash.Domain,
    otp_app: :customize_ash_authentication

  resources do
    resource CustomizeAshAuthentication.Legal.DocumentVersion
  end
end
