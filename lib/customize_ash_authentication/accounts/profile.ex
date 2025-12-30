defmodule CustomizeAshAuthentication.Accounts.Profile do
  use Ash.Resource,
    otp_app: :customize_ash_authentication,
    domain: CustomizeAshAuthentication.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "profiles"
    repo CustomizeAshAuthentication.Repo

    references do
      reference :user, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create_on_registration do
      primary? true
      upsert? true
      accept [:first_name, :last_name]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:first_name, :last_name]
    end
  end

  validations do
    validate string_length(:first_name, min: 2),
      message: "Please enter a first name",
      on: [:create, :update]

    validate present(:first_name),
      message: "Please enter a first name",
      on: [:create, :update]

    validate string_length(:last_name, min: 2),
      message: "Please enter a last name",
      on: [:create, :update]

    validate present(:last_name),
      message: "Please enter a last name",
      on: [:create, :update]
  end

  attributes do
    uuid_primary_key :id
    attribute :first_name, :string
    attribute :last_name, :string
    timestamps()
  end

  relationships do
    belongs_to :user, CustomizeAshAuthentication.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :full_name,
              :string,
              expr(
                cond do
                  is_nil(first_name) and is_nil(last_name) -> nil
                  is_nil(first_name) -> last_name
                  is_nil(last_name) -> first_name
                  true -> string_trim("#{first_name} #{last_name}")
                end
              )
  end

  identities do
    identity :unique_user, [:user_id]
  end
end
