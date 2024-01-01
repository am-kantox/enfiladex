defmodule Mix.Tasks.Enfiladex do
  @moduledoc """
  Mix task to run `commot_test` with `ExUnit` test files.
  """

  use Mix.Task

  def run(_args) do
    Mix.Task.run(:loadpaths)

    path = "test"

    Application.put_env(:common_test, :auto_compile, false)
    ExUnit.start()

    match = Path.join([path, "**", "*_test.exs"])

    modules =
      for file <- Path.wildcard(match),
          String.contains?(File.read!(file), "use Enfiladex.Suite"),
          {module, code} <- Code.compile_file(file),
          :ok <- [File.write!(Path.join(Path.dirname(file), to_string(module) <> ".beam"), code)],
          do: Module.concat([module, "Suite"])

    # credo:disable-for-next-line Credo.Check.Warning.IoInspect
    IO.inspect(
      # :ct.run_testspec([
      #   {:suites, to_charlist(path), modules},
      #   include: to_charlist(path),
      #   logdir: ~c"./ct_logs",
      #   auto_compile: false,
      #   verbosity: 100,
      #   abort_if_missing_suites: true,
      #   ct_hooks: [Enfiladex.Hooks]
      # ])

      Enum.map(modules, fn module ->
        :ct.run_test(
          dir: to_charlist(path),
          include: to_charlist(path),
          suite: module,
          logdir: ~c"./ct_logs",
          auto_compile: false,
          verbosity: 100,
          abort_if_missing_suites: true,
          ct_hooks: [Enfiladex.Hooks]
        )
      end)
    )
  end
end
