# Ash Authentication - Customize Magic Link (Part 1)

This example project demonstrates how to customize Ash Authentication by adding a user profile and enforcing its creation during registration. In Part 2, we will expand this to request user acknowledgement for privacy policies or general terms and conditions (GDPR).

If you want to see the full code, check out the main branch here: [Ash Authentication - Customize Magic Link](https://github.com/weljoda/customize_ash_authentication)

## Getting started

Start by setting up your project using your preferred method (see the [Ash Get Started guide](https://ash-hq.org/#get-started)) or simply run the minimalistic setup script below.

```shell
mix archive.install hex igniter_new --force
mix archive.install hex phx_new 1.8.1 --force

mix igniter.new customize_ash_authentication --with phx.new \
  --install ash,ash_phoenix --install ash_postgres,ash_authentication \
  --install ash_authentication_phoenix --auth-strategy magic_link --setup \
  --yes
```

Verify your setup:

* Run `mix setup` to install dependencies and set up the database.
* Start the Phoenix endpoint with `mix phx.server` (or inside IEx with `iex -S mix phx.server`).

Now, visit [`localhost:4000`](http://localhost:4000) in your browser.

## Adding a profile

Run the following mix script to generate the profile resource:

```shell
mix ash.gen.resource CustomizeAshAuthentication.Accounts.Profile \
  --uuid-primary-key id \
  --attribute first_name:string \
  --attribute last_name:string \
  --relationship belongs_to:user:CustomizeAshAuthentication.Accounts.User:required \
  --timestamps \
  --extend postgres
```

Let's add a handy calculation for the full name and ensure that a user can only have a single profile.

```elixir
# lib/customize_ash_authentication/accounts/profile.ex

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
```

We will also index the user reference and define an `on_delete` policy.

```elixir
# lib/customize_ash_authentication/accounts/profile.ex

postgres do
  table "profiles"
  repo CustomizeAshAuthentication.Repo

  references do
    reference :user, on_delete: :delete, index?: true
  end
end
```

We can make the relationship bidirectional by adding the relationship to the user resource.

```elixir
# lib/customize_ash_authentication/accounts/user.ex

relationships do
  has_one :profile, CustomizeAshAuthentication.Accounts.Profile
end
```

Now we can create the migration and apply it to our database.

```shell
mix ash.codegen add_profile
mix ash.migrate
```

### Profile actions

First, we need to implement a create and update action for our profile. We also add a validation block to avoid code duplication between the actions.

```elixir
# lib/customize_ash_authentication/accounts/profile.ex

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
```

Note that we do not add the `user_id` to the create action arguments. It will be automatically applied by the `manage_relationship` change in the user resource.

The Magic Link sign-in strategy usually creates the user automatically. We need to intercept this by extending the register action in `user.ex` to accept profile arguments.

```elixir
# lib/customize_ash_authentication/accounts/user.ex

create :sign_in_with_magic_link do
  # ... existing code
  
  argument :profile, :map

  # ... existing code
  
  change manage_relationship(:profile,
            on_no_match: :create,
            on_match: :update
          )
end
```

### Exposing the User lookup

Before we build the LiveView, we need to expose a way to fetch the user by their email address via the code interface. This will allow our LiveView to look up the user when processing the magic link.

Add the following definition to your Accounts domain module:

```elixir
# lib/customize_ash_authentication/accounts.ex

resource CustomizeAshAuthentication.Accounts.User do
  define :get_user_by_email,
    action: :get_by_email,
    args: [:email]
end
```

### Custom Magic Sign-In LiveView

Since we modified the create action, we also need to customize the corresponding form by creating a custom "Sign In" LiveView.

The default sign-in LiveView contains a form with the token as a hidden input and a simple submit button. This interaction is required (via the `require_interaction? true` setting) to prevent email scanners or clients from prematurely consuming the magic link token.

Our customized form will handle two scenarios:

1. **Existing User:** It handles the sign-in process via the magic link.
2. **New User:** It handles the registration process by collecting profile data.

I'll provide the full code first, and we will break down the specific parts afterwards.


```elixir
# lib/customize_ash_authentication_web/live/magic_sign_in.ex

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
```

We start with `handle_params` to capture the received token. Next, we verify the token and extract the encoded email address using the following code:

```elixir
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
```

Then, we load the user data and assign the profile if it exists. We use `authorize?: false` to bypass policy checks since we don't have an authenticated actor yet, relying instead on the verified token.

We also need to convert the profile struct to a map, containing only the params needed in the form.

```elixir
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
```

You might notice potential for optimization by loading the profile directly instead of the user. While true, we will need access to other user attributes in Part 2 of this series.

Now we generate the form using `AshPhoenix.Form.for_create`. We explicitly add the related profile and specify which action to use for its creation.

```elixir
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
```

Finally, the form itself. We wrap the profile inputs in the `inputs_for` component and render them only if no profile exists yet.

```heex
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
```

Note that we use standard HTML attributes (`action=...`, `method="post"`) and `phx-trigger-action={@trigger_submit}`. Crucially, we do **not** call `AshPhoenix.Form.submit/2`. Instead, we validate the form manually in the `handle_event`.

This approach ensures the form is submitted via a regular HTTP POST request rather than over the LiveView WebSocket. This is necessary to set the authentication session cookie in the browser connection.

```elixir
def handle_event("submit", %{"user" => params}, socket) do
  form = AshPhoenix.Form.validate(socket.assigns.form, params)

  if form.source.valid? do
    {:noreply, assign(socket, trigger_submit: true, form: to_form(form))}
  else
    {:noreply, assign(socket, form: to_form(form))}
  end
end
```

Finally, we need to adapt the router to use our new `MagicSignIn` instead of the default one. Uncomment the following lines and add one to replace the route.

```elixir
# lib/customize_ash_authentication_web/router.ex

# Remove this if you do not use the magic link strategy.
# magic_sign_in_route(CustomizeAshAuthentication.Accounts.User, :magic_link,
#   auth_routes_prefix: "/auth",
#   overrides: [
#     CustomizeAshAuthenticationWeb.AuthOverrides,
#     Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
#   ]
# )

live "/magic_link/:token", MagicSignIn, :show
```

## Manual testing

You can manually test the magic link workflow by navigating to [`http://localhost:4000/sign-in`](http://localhost:4000/sign-in) and entering your email address. Then, visit [`http://localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox) and follow the link in the email. Then fill in the registration form.

You should now see a registration form similar to this:

And that's it! While we don't have any protected routes yet, you can easily add them by following the [Ash Authentication Phoenix documentation](https://hexdocs.pm/ash_authentication_phoenix/liveview.html).

The beauty of this Magic Link workflow is that the user is fully persisted only *after* clicking the link and submitting the form. This "just-in-time" creation is perfect for adding GDPR-compliant acknowledgements, which we will tackle in the next part.
