defmodule SoccerReflectionCoach.Repo do
  use Ecto.Repo,
    otp_app: :soccer_reflection_coach,
    adapter: Ecto.Adapters.Postgres
end
