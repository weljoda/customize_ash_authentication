defmodule CustomizeAshAuthenticationWeb.PageController do
  use CustomizeAshAuthenticationWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
