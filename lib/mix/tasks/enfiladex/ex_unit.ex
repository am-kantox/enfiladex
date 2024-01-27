defmodule Mix.Tasks.Enfiladex.ExUnit do
  @moduledoc """
  Mix task to run normal `ExUnit` tests using `Enfiladex` goodness.

  Please set the environment for it in your `mix.exs` file as

  ```elixir
    def cli do
      [
        preferred_envs: [
          "enfiladex": "test",
          "enfiladex.ex_unit": "test"
        ]
      ]
    end

    # or inside `project` callback

    preferred_cli_env: ["enfiladex": :test, "enfiladex.ex_unit": :test],

  ```
  """
  @shortdoc "Runs `test` for `ExUnit` tests on a shortnamed node"

  @requirements ["compile", "loadpaths", "app.config", "app.start"]
  # @preferred_cli_env :test

  use Mix.Task

  def run(args) do
    {params, rest, []} = OptionParser.parse(args, strict: [name: :string, distribution: :string])
    {name, params} = Keyword.pop(params, :name, "enfiladex")
    {distribution, []} = Keyword.pop(params, :distribution, "epmd -daemon")

    Application.unload(:dialyxir)

    [cmd | args] = String.split(distribution)
    {_, 0} = System.cmd(cmd, args)

    {stop?, _pid} =
      name
      |> String.to_atom()
      |> Node.start(:shortnames, 15_000)
      |> case do
        {:ok, pid} -> {true, pid}
        {:error, {:already_started, pid}} -> {false, pid}
      end

    try do
      System.put_env("MIX_ENV", "test")
      Mix.Task.run(:test, rest)
    after
      if stop?, do: Node.stop()
    end
  end
end
