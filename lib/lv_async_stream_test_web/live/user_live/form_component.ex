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
          id="fruits_lvs"
          field={@form[:fruits_selection]}
          label="Fruits"
          phx-target={@myself}
          mode={:tags}
        />
        <.live_select
          id="cars_lvs"
          field={@form[:cars_selection]}
          label="Cars"
          phx-target={@myself}
          mode={:tags}
        />
        <.inputs_for :let={f_nested} field={@form[:fruits]}>
          <.input type="hidden" field={f_nested[:name]} />
        </.inputs_for>
        <.inputs_for :let={f_nested} field={@form[:cars]}>
          <.input type="hidden" field={f_nested[:name]} />
        </.inputs_for>
        <:actions>
          <.button phx-disable-with="Saving...">Save User</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)

    if user.fruits do
      send_update(LiveSelect.Component,
        id: "fruits_lvs",
        value: Enum.map(user.fruits, fn v -> %{label: @entries[v.name], value: v.name} end)
      )
    end

    if user.cars do
      send_update(LiveSelect.Component,
        id: "cars_lvs",
        value: Enum.map(user.cars, fn v -> %{label: @entries[v.name], value: v.name} end)
      )
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"_target" => ["user", "cars_selection"], "user" => user_params},
        socket
      ) do
    %{"cars_selection" => selection} = user_params

    user_params =
      Map.merge(
        user_params,
        %{
          "cars" =>
            selection
            |> Enum.with_index()
            |> Enum.map(fn {value, idx} ->
              {to_string(idx), %{"name" => value}}
            end)
            |> Enum.into(%{})
        }
      )

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    socket
    |> assign_form(changeset)
    |> then(&{:noreply, &1})
  end

  def handle_event(
        "validate",
        %{"_target" => ["user", "fruits_selection"], "user" => user_params},
        socket
      ) do
    %{"fruits_selection" => selection} = user_params

    user_params =
      Map.merge(
        user_params,
        %{
          "fruits" =>
            selection
            |> Enum.with_index()
            |> Enum.map(fn {value, idx} ->
              {to_string(idx), %{"name" => value}}
            end)
            |> Enum.into(%{})
        }
      )

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    socket
    |> assign_form(changeset)
    |> then(&{:noreply, &1})
  end

  def handle_event(
        "validate",
        %{"_target" => ["user", "fruits_selection_empty_selection"], "user" => user_params},
        socket
      ) do
    user_params = Map.put(user_params, "fruits", %{})

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event(
        "validate",
        %{"_target" => ["user", "cars_selection_empty_selection"], "user" => user_params},
        socket
      ) do
    user_params = Map.put(user_params, "cars", %{})

    dbg(user_params)

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  def handle_event("live_select_change", %{"text" => text, "id" => live_select_id}, socket) do
    options =
      @entries
      |> Enum.filter(fn {_k, e} -> String.contains?(String.downcase(e), String.downcase(text)) end)
      |> Enum.map(fn {k, v} -> {v, k} end)
      |> Enum.into(%{})

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
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
