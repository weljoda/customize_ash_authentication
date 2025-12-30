defmodule CustomizeAshAuthenticationWeb.MagicSignIn do
  use CustomizeAshAuthenticationWeb, :live_view
  require Ash.Query

  alias CustomizeAshAuthentication.Accounts
  alias CustomizeAshAuthentication.Accounts.User
  alias CustomizeAshAuthentication.Accounts.Profile
  alias AshAuthentication.Jwt.Config

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_page_title(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :token, params["token"])

    with {:ok, socket} <- assign_email(socket) do
      socket
      |> assign_user_assigns()
      |> assign_page_title()
      |> assign(:trigger_submit, false)
      |> assign_form()
      |> then(&{:noreply, &1})
    else
      {:halt, socket} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => _params}, socket) do
    # form = AshPhoenix.Form.validate(socket.assigns.form, params)
    # {:noreply, assign(socket, form: to_form(form))}
    {:noreply, socket}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    if form.source.valid? do
      {:noreply, assign(socket, trigger_submit: true, form: to_form(form))}
    else
      {:noreply, assign(socket, form: to_form(form))}
    end
  end

  defp assign_form(
         %{
           assigns: %{
             token: token,
             profile: profile
           }
         } = socket
       ) do
    form =
      AshPhoenix.Form.for_create(
        User,
        :sign_in_with_magic_link,
        params: %{profile: profile, token: token},
        as: "user",
        load: [:profile],
        forms: [
          profile: [
            type: :single,
            resource: Profile,
            create_action: :create_on_registration
          ]
        ]
      )

    socket
    |> assign(:form, to_form(form))
  end

  defp assign_email(%{assigns: %{token: token}} = socket) do
    with signer <- Config.token_signer(User),
         {:ok, %{"identity" => identity} = claims} <- Joken.verify(token, signer),
         defaults <- Config.default_claims(User),
         {:ok, _claims} <- Joken.validate(defaults, claims, User) do
      {:ok, assign(socket, :email, identity)}
    else
      _ ->
        {:halt,
         socket
         |> put_flash(:error, "Invalid link, please try again.")
         |> push_navigate(to: ~p"/sign-in")}
    end
  end

  defp assign_user_assigns(%{assigns: %{email: email}} = socket) do
    case Accounts.get_user_by_email!(email,
           load: [
             profile: [:first_name, :last_name, :full_name]
           ],
           not_found_error?: false,
           authorize?: false
         ) do
      nil ->
        socket
        |> assign(:profile, %{})
        |> assign(:action_label, label(true))
        |> assign(:name, nil)

      user ->
        socket
        |> assign(:profile, profile_to_map(user.profile))
        |> assign(:action_label, label(false))
        |> assign(:name, if(user.profile, do: user.profile.full_name, else: nil))
    end
  end

  defp profile_to_map(nil), do: %{}

  defp profile_to_map(profile),
    do: Map.take(profile, [:id, :first_name, :last_name])

  defp assign_page_title(%{assigns: %{action_label: action_label}} = socket),
    do: assign(socket, :page_title, action_label)

  defp assign_page_title(socket),
    do: assign(socket, :page_title, label(true))

  defp label(is_registration), do: if(is_registration, do: "Register", else: "Login")

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid h-screen place-items-center bg-base-100">
      <div class="flex-1 flex flex-col justify-center py-12 px-4 lg:flex-none">
        <div class="w-full flex justify-center py-2">
          <a class="text-3xl sm:text-4xl lg:text-5xl" href="/">
            Custom Magic Link - Ash Authentication
          </a>
        </div>
        <div class="mx-auto w-full max-w-sm lg:w-96">
          <div class="mt-4 mb-4">
            <%= if @name do %>
              Hello {@name}, welcome back!
            <% end %>
            <.form
              for={@form}
              action={~p"/auth/user/magic_link"}
              method="post"
              phx-change="validate"
              phx-submit="submit"
              phx-trigger-action={@trigger_submit}
              class="flex flex-col gap-2"
            >
              <input type="hidden" name="user[token]" value={@token} />

              <%= if %{} == @profile do %>
                <.inputs_for :let={profile} field={@form[:profile]}>
                  <.input
                    phx-debounce="200"
                    field={profile[:first_name]}
                    type="text"
                    label="First name"
                  />
                  <.input
                    phx-debounce="200"
                    field={profile[:last_name]}
                    type="text"
                    label="Last name"
                  />
                </.inputs_for>
              <% end %>

              <button
                class="btn btn-primary btn-block mt-4 mb-4"
                phx-disable-with={@action_label <> " ..."}
                type="submit"
              >
                {@action_label}
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
