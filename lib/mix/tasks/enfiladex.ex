defmodule Mix.Tasks.Enfiladex do
  @moduledoc """
  Mix task to run `commot_test` with `ExUnit` test files.

  Accepted arguments:

  - **`--test-dir`** (_default:_ `["test"]`) — accumulated list of dirs to run `enfiladex` task in
  - **`--ct-logs-dir`** (_default:_ `["ct_logs"]`) — the directory where to pul `ct_logs` outcome to

  Full [list of options](https://www.erlang.org/doc/man/ct#run_test-1):

  * **✓** `{dir, TestDirs}` — as `--test-dir`
  * **✓** `{suite, Suites}` — as suite per test module with `use Enfiladex.Suite`
  * **✓** `{group, Groups}` — as gained from `describe` blocks per suite
  * **✗** `{testcase, Cases}`
  * **✗** `{spec, TestSpecs}`
  * **✗** `{join_specs, boolean()}`
  * **✗** `{label, Label}`
  * **✗** `{config, CfgFiles}`
  * **✗** `{userconfig, UserConfig}`
  * **✗** `{allow_user_terms, boolean()}`
  * **✓** `{logdir, LogDir}` — as `--log-dir`
  * **✗** `{silent_connections, Conns}`
  * **✗** `{stylesheet, CSSFile}`
  * **✗** `{cover, CoverSpecFile}` — requires `.erl` files, TODO
  * **✗** `{cover_stop, boolean()}`
  * **✗** `{step, StepOpts}`
  * **✗** `{event_handler, EventHandlers}`
  * **✓** `{include, InclDirs}` — as `--test-dir`
  * **✓** `{auto_compile, boolean()}` — as `false` because `ct` needs `beam` files
  * **✓** `{abort_if_missing_suites, boolean()}` — as hardcoded `true`
  * **✗** `{create_priv_dir, CreatePrivDir}`
  * **✗** `{multiply_timetraps, M}`
  * **✗** `{scale_timetraps, boolean()}`
  * **✗** `{repeat, N}`
  * **✗** `{duration, DurTime}`
  * **✗** `{until, StopTime}`
  * **✗** `{force_stop, ForceStop}`
  * **✗** `{decrypt, DecryptKeyOrFile}`
  * **✗** `{refresh_logs, LogDir}`
  * **✗** `{logopts, LogOpts}`
  * **✓** `{verbosity, VLevels}` — as hardcoded `100`
  * **✗** `{basic_html, boolean()}`
  * **✗** `{esc_chars, boolean()}`
  * **✗** `{keep_logs, KeepSpec}`
  * **✓** `{ct_hooks, CTHs}` — as provided by `Enfiladex.Hooks`
  * **✗** `{enable_builtin_hooks, boolean()}`
  * **✗** `{release_shell, boolean()}`
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
        Enum.map(modules, fn %{fake: module} ->
          :ct.run_test(
            dir: Enum.map(test_dirs, &to_charlist/1),
            include: Enum.map(test_dirs, &to_charlist/1),
            suite: module,
            logdir: to_charlist(ct_logs_dir),
            auto_compile: false,
            # cover: ~c"cover.spec",
            # cover_stop: false,
            abort_if_missing_suites: true,
            verbosity: 100,
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
