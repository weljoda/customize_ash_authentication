defmodule CustomizeAshAuthenticationWeb.DocumentController do
  use CustomizeAshAuthenticationWeb, :controller
  alias CustomizeAshAuthentication.Legal

  plug :put_layout, false

  def show(conn, %{"type" => type}) do
    case Legal.get_latest_document_version_by_type(type) do
      {:ok, document} ->
        render(conn, :show, content: document.content, title: type_to_title(type))

      _ ->
        conn
        |> put_flash(:error, "Document not available.")
        |> redirect(to: ~p"/")
    end
  end

  # A simple helper to pretty-print the original atom (e.g. :privacy_policy -> "Privacy Policy")
  def type_to_title(type) when is_binary(type) do
    type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
