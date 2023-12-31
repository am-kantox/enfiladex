defmodule Mix.Tasks.Enfiladex do
  use Mix.Task

  def run(_args) do
    Mix.Task.run(:loadpaths)

    path = "./test"

    Application.put_env(:common_test, :auto_compile, false)
    ExUnit.start()

    match = Path.join([path, "**", "*_test.exs"])

    modules =
      for file <- Path.wildcard(match),
          String.contains?(File.read!(file), "use Enfiladex.Suite"),
          {module, _} <- Code.require_file(file),
          do: module

    IO.inspect(
      # :ct.run_testspec([
      #   {:suites, to_charlist(path), modules},
      #   logdir: ~c"./results",
      #   abort_if_missing_suites: true,
      #   ct_hooks: [Enfiladex.Hooks]
      # ])

      :ct.run_test(
        dir: to_charlist(path),
        include: to_charlist(path),
        suite: Elixir.Enfiladex.Test.Suite.Suite,
        logdir: ~c"./ct_logs",
        auto_compile: false,
        verbosity: 100,
        abort_if_missing_suites: true,
        ct_hooks: [Enfiladex.Hooks]
      )
    )
  end
end
