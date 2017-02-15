defmodule Leaderboard.Mixfile do
  use Mix.Project

  def project do
    [app: :leaderboard,
     version: "0.0.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:credo, "~> 0.5", only: [:dev, :test]}]
  end
end
