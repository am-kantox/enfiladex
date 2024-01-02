defmodule Mix.Tasks.Enfiladex do
  @moduledoc """
  Mix task to run `commot_test` with `ExUnit` test files.
  """
  @shortdoc "Runs `common_test` for `ExUnit` tests"

  @requirements ["compile", "loadpaths", "app.config"]
  @preferred_cli_env :test

  use Mix.Task

  @doc false
  def compile(path \\ "test") do
    match = Path.join([path, "**", "*_test.exs"])

    for file <- Path.wildcard(match),
        String.contains?(File.read!(file), "use Enfiladex.Suite"),
        {module, code} <- Code.compile_file(file) do
      beam = Path.join(Path.dirname(file), to_string(module) <> ".beam")
      :ok = File.write!(Path.join(Path.dirname(file), to_string(module) <> ".beam"), code)
      %{module: module, fake: Module.concat([module, "Suite"]), beam: beam}
    end
  end

  def run(_args) do
    {_result, 0} = System.cmd("epmd", ["-daemon"], env: [])

    _pid =
      case Node.start(:enfiladex, :shortnames, 15_000) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    ExUnit.start(autorun: false, assert_receive_timeout: 1_000)

    Application.put_env(:common_test, :auto_compile, false)

    path = "test"

    modules = compile(path)

    try do
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

        Enum.map(modules, fn %{fake: module} ->
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
    after
      Node.stop()
      Enum.each(modules, fn %{beam: file} -> File.rm(file) end)
    end
  end
end
