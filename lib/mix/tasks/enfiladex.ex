defmodule Mix.Tasks.Enfiladex do
  @moduledoc """
  Mix task to run `commot_test` with `ExUnit` test files.

  Accepted arguments:

  - **`--test-dir`** (_default:_ `["test"]`) — accumulated list of dirs to run `enfiladex` task in
  - **`--ct-logs-dir`** (_default:_ `["ct_logs"]`) — the directory where to pul `ct_logs` outcome to
  """
  @shortdoc "Runs `common_test` for `ExUnit` tests"

  @requirements ["compile", "loadpaths", "app.config", "app.start"]
  @preferred_cli_env :test

  use Mix.Task

  @doc false
  defp compile(path) do
    match = Path.join([path, "**", "*_test.exs"])

    for file <- Path.wildcard(match),
        String.contains?(File.read!(file), "use Enfiladex.Suite"),
        {module, code} <- Code.compile_file(file) do
      beam = Path.join(Path.dirname(file), to_string(module) <> ".beam")
      :ok = File.write!(Path.join(Path.dirname(file), to_string(module) <> ".beam"), code)
      %{module: module, fake: Module.concat([module, "Suite"]), beam: beam}
    end
  end

  defp mkdir(path) do
    case File.mkdir(path) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      other -> raise inspect(other)
    end
  end

  def run(args) do
    {params, [], []} = OptionParser.parse(args, strict: [test_dir: :keep, ct_logs_dir: :string])
    {ct_logs_dir, params} = Keyword.pop(params, :ct_logs_dir, "ct_logs")
    test_dirs = params |> Keyword.put_new(:test_dir, "test") |> Keyword.get_values(:test_dir)

    {_result, 0} = System.cmd("epmd", ["-daemon"], env: [])

    _pid =
      case Node.start(:enfiladex, :shortnames, 15_000) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    ExUnit.start(autorun: false, assert_receive_timeout: 1_000)

    Application.put_env(:common_test, :auto_compile, false)

    mkdir(ct_logs_dir)
    modules = compile("{" <> Enum.join(test_dirs, ",") <> "}")

    try do
      # credo:disable-for-next-line Credo.Check.Warning.IoInspect
      IO.inspect(
        # :ct.run_testspec([
        #   {:suites, to_charlist(test_dir), modules},
        #   include: to_charlist(test_dir),
        #   logdir: ~c"./ct_logs",
        #   auto_compile: false,
        #   verbosity: 100,
        #   abort_if_missing_suites: true,
        #   ct_hooks: [Enfiladex.Hooks]
        # ])

        Enum.map(modules, fn %{fake: module} ->
          :ct.run_test(
            dir: Enum.map(test_dirs, &to_charlist/1),
            include: Enum.map(test_dirs, &to_charlist/1),
            suite: module,
            logdir: to_charlist(ct_logs_dir),
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
