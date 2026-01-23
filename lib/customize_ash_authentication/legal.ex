defmodule CustomizeAshAuthentication.Legal do
  use Ash.Domain,
    otp_app: :customize_ash_authentication

  resources do
    resource CustomizeAshAuthentication.Legal.DocumentVersion do
      define :list_latest_document_versions,
        action: :list_latest

      define :create_document_version,
        action: :create,
        args: [:content, :type, {:optional, :effective_from}]

      define :get_latest_document_version_by_type,
        action: :get_latest_by_type,
        args: [:type]
    end

    resource CustomizeAshAuthentication.Legal.UserAcknowledgement
  end
end
