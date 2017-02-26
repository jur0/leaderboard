defmodule Leaderboard.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def project do
    [app: :leaderboard,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     deps: deps(),
     docs: docs(),
     package: package()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp description do
    "Leaderboard based on ETS tables"
  end

  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev},
     {:benchfella, "~> 0.3.0"}]
  end

  defp docs do
    [source_url: "https://github.com/jur0/leaderboard",
     source_ref: "v#{@version}",
     extras: ["README.md"],
     main: "Leaderboard"]
  end

  defp package do
    [maintainers: ["Juraj Hlista"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/jur0/leaderboard"}]
  end
end
