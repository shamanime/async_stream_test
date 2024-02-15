defmodule AsyncStreamTest.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :age, :integer
      add :fruits, {:array, :string}
      add :cars, {:array, :string}

      timestamps(type: :utc_datetime)
    end
  end
end
