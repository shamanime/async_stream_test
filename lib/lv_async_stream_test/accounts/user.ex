defmodule AsyncStreamTest.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :age, :integer
    embeds_many :fruits, AsyncStreamTest.Accounts.Item, on_replace: :delete
    embeds_many :cars, AsyncStreamTest.Accounts.Item, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :age])
    |> validate_required([:name, :age])
    |> cast_embed(:fruits)
    |> cast_embed(:cars)
  end
end

defmodule AsyncStreamTest.Accounts.Item do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
