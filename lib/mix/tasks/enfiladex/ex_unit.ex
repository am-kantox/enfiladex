defmodule Mix.Tasks.Enfiladex.ExUnit do
  @moduledoc """
  Mix task to run normal `ExUnit` tests using `Enfiladex` goodness.
  """
  @shortdoc "Runs `test` for `ExUnit` tests on a shortnamed node"

  @requirements ["compile", "loadpaths", "app.config", "app.start"]
  @preferred_cli_env :test

  use Mix.Task

  def run(args) do
    {params, [], []} = OptionParser.parse(args, strict: [name: :string])
    {name, []} = Keyword.pop(params, :name, "enfiladex")

    _pid =
      name
      |> String.to_atom()
      |> Node.start(:shortnames, 15_000)
      |> case do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    try do
      System.put_env("MIX_ENV", "test")
      Mix.Task.run(:test)
    after
      Node.stop()
    end
  end
end
