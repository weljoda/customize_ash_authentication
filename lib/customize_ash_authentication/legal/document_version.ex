defmodule CustomizeAshAuthentication.Legal.DocumentVersion do
  use Ash.Resource,
    otp_app: :customize_ash_authentication,
    domain: CustomizeAshAuthentication.Legal,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "document_versions"
    repo CustomizeAshAuthentication.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:content, :type, :effective_from]
    end

    read :get_latest_by_type do
      get? true

      argument :type, :atom do
        allow_nil? false
      end

      filter expr(type == ^arg(:type) and effective_from < now())
      prepare build(sort: [effective_from: :desc], limit: 1)
    end

    read :list_latest do
      filter expr(effective_from < now())
      prepare build(distinct: [:type], distinct_sort: [effective_from: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      public? true
    end

    attribute :effective_from, :utc_datetime

    attribute :type, :atom do
      constraints one_of: [:privacy_policy, :terms_of_service]
      allow_nil? false
    end

    timestamps()
  end
end
