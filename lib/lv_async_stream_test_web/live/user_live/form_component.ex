defmodule AsyncStreamTestWeb.UserLive.FormComponent do
  use AsyncStreamTestWeb, :live_component

  alias AsyncStreamTest.Accounts

  @entries %{
    "banana" => "Banana",
    "apple" => "Apple",
    "watermelon" => "Watermelon",
    "tesla" => "Tesla",
    "hyundai" => "Hyundai",
    "honda" => "Honda"
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage user records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:age]} type="number" label="Age" />
        <.live_select
          field={@form[:fruits]}
          label="Fruits"
          value_mapper={&value_mapper/1}
          phx-target={@myself}
          mode={:tags}
        />
        <.live_select
          field={@form[:cars]}
          label="Cars"
          value_mapper={&value_mapper/1}
          phx-target={@myself}
          mode={:tags}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save User</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  # the value_mapper function is passed to LiveSelect. Its job is to convert the values LiveSelect receives through the form 
  # into the correct options. The options should have the same format as the options set by the "live_select_change" event handler
  # This means that the value should have the data needed to create an Accounts.Item struct, and the label should be the label that the user expects
  defp value_mapper(%{name: name}), do: %{label: String.capitalize(name), value: %{name: name}}

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  defp decode(nil), do: []
  defp decode(list), do: Enum.map(list, &Jason.decode!/1)

  defp decode_params(user_params) do
    user_params
    |> update_in(["cars"], &decode/1)
    |> update_in(["fruits"], &decode/1)
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    # Whenever we want to recreate the User struct from the params, we first need to
    # decode the parameters for "cars" and "fruits", because they are sent as a list of JSON-encoded values
    # We use the decode_params function for this, which is simple enough... 
    # However: could such a function be a helper offered by LiveSelect itself? (e.g. LiveSelect.decode/1)

    user_params = decode_params(user_params)

    # now user params is ready to be passed to the user changeset!
    
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # Same thing applies here as for the "validate" event
    
    save_user(socket, socket.assigns.action, decode_params(user_params))
  end

  def handle_event("live_select_change", %{"text" => text, "id" => live_select_id}, socket) do
    # If we want to be able to recreate Accounts.Item structs from the values in the form, we need the values to have
    # the shape expected by the Accounts.Item changeset (e.g. %{name: name})
    options =
      @entries
      |> Enum.filter(fn {_k, v} -> String.contains?(String.downcase(v), String.downcase(text)) end)
      |> Enum.map(fn {k, v} -> %{label: v, value: %{name: k}} end)
      
    send_update(LiveSelect.Component, id: live_select_id, options: options)

    {:noreply, socket}
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        socket
        |> assign(user: user)
        |> assign_form(Accounts.change_user(user))
        |> then(&{:noreply, &1})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset)
    assign(socket, :form, form)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
