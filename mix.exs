defmodule CodeStyle.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/kokjinsam/code_style"

  def project do
    [
      app: :code_style,
      version: @version,
      elixir: "~> 1.18",
      description: "Personal Credo checks for Elixir codebases.",
      aliases: aliases(),
      package: package(),
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [check: :test]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", runtime: false},
      {:excellent_migrations, "~> 0.1.10", runtime: false},
      {:ex_slop, "~> 0.4.2", runtime: false},
      {:styler, "~> 1.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "test"
      ]
    ]
  end

  defp package do
    [
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
