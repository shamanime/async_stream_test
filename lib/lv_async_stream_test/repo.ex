defmodule AsyncStreamTest.Repo do
  use Ecto.Repo,
    otp_app: :lv_async_stream_test,
    adapter: Ecto.Adapters.Postgres
end
