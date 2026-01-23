defmodule CustomizeAshAuthenticationWeb.DocumentHTML do
  use CustomizeAshAuthenticationWeb, :html

  def show(assigns) do
    ~H"""
    <div class="grid min-h-screen place-items-center bg-base-100 py-12 px-4">
      <div class="mx-auto w-full max-w-2xl">
        <h1 class="text-2xl sm:text-3xl lg:text-4xl py-6 flex justify-center">{@title}</h1>
        <div class="p-6">
          {raw(@content)}
        </div>
      </div>
    </div>
    """
  end
end
