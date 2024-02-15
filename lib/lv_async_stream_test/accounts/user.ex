defmodule AsyncStreamTest.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :age, :integer
    field :cars, {:array, :string}
    field :fruits, {:array, :string}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :age, :cars, :fruits])
    |> validate_required([:name, :age])
  end
end
