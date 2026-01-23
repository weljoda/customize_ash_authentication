defmodule CustomizeAshAuthentication.Legal.UserAcknowledgement do
  use Ash.Resource,
    otp_app: :customize_ash_authentication,
    domain: CustomizeAshAuthentication.Legal,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_acknowledgements"
    repo CustomizeAshAuthentication.Repo

    references do
      reference :user, on_delete: :delete, index?: true
      reference :document_version, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:document_version_id]

      argument :accepted, :boolean do
        allow_nil? false
      end

      change before_action(fn %{context: context} = changeset, _context ->
               changeset
               |> Ash.Changeset.force_change_attribute(:ip, context[:client_ip])
               |> Ash.Changeset.force_change_attribute(:user_agent, context[:user_agent])
             end)

      validate argument_equals(:accepted, true),
        message: "An acknowledgment is required"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :ip, :string do
      allow_nil? false
    end

    attribute :user_agent, :string do
      allow_nil? false
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, CustomizeAshAuthentication.Accounts.User do
      allow_nil? false
    end

    belongs_to :document_version, CustomizeAshAuthentication.Legal.DocumentVersion do
      allow_nil? false
    end
  end

  identities do
    identity :unique_user_document_version, [:user_id, :document_version_id]
  end
end
