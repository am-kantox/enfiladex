defmodule Enfiladex.MixProject do
  use Mix.Project

  @app :enfiladex
  @version "0.1.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.14",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      prune_code_paths: Mix.env() == :prod,
      preferred_cli_env: [{:"enfiladex.suite", :test}],
      description: description(),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  def application do
    [
      extra_applications: [
        :logger
        # :observer,
        # :wx,
        # :runtime_tools,
        # :common_test
      ]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :ci]},
      {:ex_doc, "~> 0.11", only: [:dev, :docs]}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --halt-exit-status"
      ]
    ]
  end

  defp description do
    """
    Erlang `common_test` and multinode test with `:peer` convenient wrapper.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|config lib mix.exs README.md|,
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      source_url: "https://github.com/am-kantox/#{@app}",
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      # logo: "stuff/images/logo.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      # assets: "stuff/images",
      extras: [
        "README.md"
      ],
      groups_for_modules: []
    ]
  end
end
