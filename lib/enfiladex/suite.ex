defmodule Enfiladex.Suite do
  @moduledoc """
  `Enfiladex` is the drop-in `Common Test` wrapper for _Elixir_.

  **`@enfiladex_strategy`** attribute can be set before each `describe/2` call to one of the following values:

  - **`[]`** (empty list / no option)
    - The test cases in the group are run one after the other. If a test fails, the others after it in the list are run.
  - **`:shuffle`**
    - Runs the test in a random order. The random seed (the initialization value) used for the sequence will be printed in the HTML logs, of the form {A,B,C}. If a particular sequence of tests fails and you want to reproduce it, use that seed in the HTML logs and change the shuffle option to instead be {shuffle, {A,B,C}}. That way you can reproduce random runs in their precise order if you ever need to.
  - **`:parallel`**
    - The tests are run in different processes. Be careful because if you forget to export the init_per_group and end_per_group functions, Common Test will silently ignore this option.
  - **`:sequence`**
    - Doesn't necessarily mean that the tests are run in order, but rather that if a test fails in the group's list, then all the other subsequent tests are skipped. This option can be combined with shuffle if you want any random test failing to stop the ones after.
  - **`{:repeat, times}`**
    - Repeats the group Times times. You could thus run all test cases in the group in parallel 9 times in a row by using the group properties [parallel, {repeat, 9}]. Times can also have the value forever, although 'forever' is a bit of a lie as it can't defeat concepts such as hardware failure or heat death of the Universe (ahem).
  - **`{:repeat_until_any_fail, n}`**
    - Runs all the tests until one of them fails or they have been run N times. N can also be forever.
  - **`{:repeat_until_all_fail, n}`**
    - Same as above, but the tests may run until all cases fail.
  - **`{:repeat_until_any_succeed, n}`**
    - Same as before, except the tests may run until at least one case succeeds.
  - **`{:repeat_until_all_succeed, n}`**
    - I think you can guess this one by yourself now, but just in case, it's the same as before except that the test cases may run until they all succeed.

  [Common Test for Uncommon Tests](https://learnyousomeerlang.com/common-test-for-uncommon-tests)
  """

  @default_enfiladex_strategy :enfiladex
                              |> Application.compile_env(:default_group_strategy)
                              |> List.wrap()

  @normalize_group_names Application.compile_env(:enfiladex, :normalize_group_names, false)

  defmacro __using__(_opts \\ []) do
    quote generated: true, location: :keep do
      @before_compile Enfiladex.Suite
      @after_compile Enfiladex.Suite

      Module.register_attribute(__MODULE__, :enfiladex_strategy, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :enfiladex_group, accumulate: false, persist: true)
      Module.put_attribute(__MODULE__, :enfiladex_group, [])
      Module.register_attribute(__MODULE__, :enfiladex_tests, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :enfiladex_setup, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :enfiladex_setup_all, accumulate: true, persist: true)

      import ExUnit.Case, only: [test: 1]
      require ExUnit.Case

      import ExUnit.Callbacks,
        except: [setup: 1, setup: 2, setup_all: 1, setup_all: 2, on_exit: 1, on_exit: 2]

      require ExUnit.Callbacks

      import Enfiladex.Suite,
        only: [
          describe: 2,
          test: 2,
          test: 3,
          setup: 1,
          setup: 2,
          setup_all: 1,
          setup_all: 2,
          on_exit: 1,
          on_exit: 2
        ]
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(_env) do
    quote bind_quoted: [enfiladex_strategy: @default_enfiladex_strategy],
          generated: true,
          location: :keep do
      @tests @enfiladex_tests
             |> Enum.reduce(%{}, fn %ExUnit.Test{
                                      name: test,
                                      tags: %{
                                        describe: group,
                                        enfiladex_strategy: strategy
                                      }
                                    },
                                    acc ->
               group = Enfiladex.Suite.fix_atom_name(group)

               acc
               |> Map.put_new(group, %{tests: [], strategies: []})
               |> update_in([group, :tests], &(List.wrap(&1) ++ [test]))
               |> update_in([group, :strategies], &Enum.uniq(List.wrap(strategy) ++ &1))
             end)

      @enfiladex_groups Enum.flat_map(@tests, fn
                          {nil, %{tests: tests, strategies: strategies}} ->
                            []

                          {group, %{tests: tests, strategies: []}} ->
                            [{group, enfiladex_strategy, tests}]

                          {group, %{tests: tests, strategies: [strategy]}} ->
                            [{group, [strategy], tests}]

                          {group, %{tests: tests, strategies: strategies}} ->
                            [{group, strategies, tests}]

                            # [AM] do we need to raise here?!
                            raise Enfiladex.ModuleAttributeError,
                                  "`@enfiladex_strategy` attribute must be the same for all tests " <>
                                    "in `group`/`describe`"
                        end)

      def groups, do: @enfiladex_groups

      @enfiladex_all Enum.flat_map(@tests, fn
                       {nil, %{tests: tests}} -> tests
                       {group, _} -> [{:group, group}]
                     end)

      def all, do: @enfiladex_all

      defmacrop on_entry_ast(on_entry) do
        Enum.map(on_entry, fn f ->
          quote do
            fn ctx ->
              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              case unquote(f)(Map.new(ctx)) do
                :ok -> ctx
                %{} = map -> Enum.to_list(map)
                list when is_list(list) -> list
              end
            end
          end
        end)
      end

      %{group: _, on_entry: on_entry, on_exit: on_exit} =
        Enum.reduce(@enfiladex_setup_all, &Map.merge(&1, &2, fn _k, v1, v2 -> v1 ++ v2 end))

      def init_per_suite(context) do
        Enum.reduce(on_entry_ast(unquote(on_entry)), context, & &1.(&2))
      end

      def end_per_suite(context) do
        unquote(on_exit)
        context
      end

      {%{on_entry: on_entry, on_exit: on_exit, tests: tests}, groups} =
        @enfiladex_setup
        |> Enum.reduce(%{}, fn setup, acc ->
          {groups, setup} =
            case Map.pop!(setup, :group) do
              {[], setup} -> {[nil], setup}
              {groups, setup} -> {Enum.map(groups, &Enfiladex.Suite.fix_atom_name/1), setup}
            end

          merger = fn _k, v1, v2 -> v2 ++ v1 end

          Enum.reduce(groups, acc, fn group, acc ->
            Map.update(acc, group, setup, &Map.merge(&1, setup, merger))
          end)
        end)
        |> Map.merge(@tests, fn _k, %{} = v1, %{} = v2 -> Map.merge(v1, v2) end)
        |> Map.pop(nil, %{tests: [], on_entry: [], on_exit: []})

      for test <- tests do
        def init_per_testcase(unquote(test), context) do
          Enum.reduce(on_entry_ast(unquote(on_entry)), context, & &1.(&2))
        end

        def end_per_testcase(unquote(test), context) do
          unquote(on_exit)
          context
        end
      end

      def init_per_testcase(_, context), do: context
      def end_per_testcase(_, context), do: context

      def init_per_group(group, context \\ [])
      def end_per_group(group, context \\ [])

      for {group, %{on_entry: on_entry, on_exit: on_exit}} <- groups do
        def init_per_group(unquote(group), context) do
          Enum.reduce(on_entry_ast(unquote(on_entry)), context, & &1.(&2))
        end

        def end_per_group(unquote(group), context) do
          unquote(on_exit)
          context
        end
      end

      def init_per_group(_, context), do: context
      def end_per_group(_, context), do: context

      :ok
    end
  end

  defmacro __after_compile__(_env, _bytecode) do
    quote do
      :ok
    end
  end

  defmacro test(message, var \\ quote(do: _), contents) do
    quote do
      ExUnit.Case.test(unquote(message), unquote(var), unquote(contents))
      last_test = ExUnit.Case.get_last_registered_test(__MODULE__)

      @enfiladex_tests %ExUnit.Test{
        last_test
        | tags: Map.put(last_test.tags, :enfiladex_strategy, @enfiladex_strategy)
      }
    end
  end

  defmacro describe(message, do: block) do
    quote do
      @enfiladex_group [Enfiladex.Suite.fix_atom_name(unquote(message)) | @enfiladex_group]
      ExUnit.Case.describe(unquote(message), unquote(do: block))
      @enfiladex_group tl(@enfiladex_group)

      Module.put_attribute(
        __MODULE__,
        :enfiladex_strategy,
        Module.get_attribute(
          __MODULE__,
          :enfiladex_default_strategy,
          unquote(@default_enfiladex_strategy)
        )
      )
    end
  end

  @spec on_exit(term, (-> term)) :: :ok
  def on_exit(name_or_ref \\ make_ref(), callback) when is_function(callback, 0) do
    with :error <- ExUnit.OnExitHandler.add(self(), name_or_ref, callback) do
      IO.puts(
        "test process is not running, `on_exit/2` callback will not make any effect in `ExUnit`"
      )

      :ok
    end
  end

  defmacro setup(block) do
    {kind, on_exit} =
      if Keyword.keyword?(block),
        do: {:block, grab_on_exit(__CALLER__, block)},
        else: {:function, []}

    quote do
      ExUnit.Callbacks.setup(unquote(block))

      funs =
        case unquote(kind) do
          :function -> unquote(block)
          :block -> List.first(@ex_unit_setup)
        end

      Module.put_attribute(__MODULE__, :enfiladex_setup, %{
        on_entry: List.wrap(funs),
        on_exit: unquote(Macro.escape(on_exit)),
        group: @enfiladex_group
      })
    end
  end

  defmacro setup(context, block) do
    on_exit = grab_on_exit(__CALLER__, block)

    quote do
      ExUnit.Callbacks.setup(unquote(context), unquote(block))

      Module.put_attribute(__MODULE__, :enfiladex_setup, %{
        on_entry: List.wrap(List.first(@ex_unit_setup)),
        on_exit: unquote(Macro.escape(on_exit)),
        group: @enfiladex_group
      })
    end
  end

  defmacro setup_all(block) do
    {kind, on_exit} =
      if Keyword.keyword?(block),
        do: {:block, grab_on_exit(__CALLER__, block)},
        else: {:function, []}

    quote do
      ExUnit.Callbacks.setup_all(unquote(block))

      funs =
        case unquote(kind) do
          :function -> unquote(block)
          :block -> List.first(@ex_unit_setup_all)
        end

      Module.put_attribute(__MODULE__, :enfiladex_setup_all, %{
        on_entry: List.wrap(funs),
        on_exit: unquote(Macro.escape(on_exit)),
        group: @enfiladex_group
      })
    end
  end

  defmacro setup_all(context, block) do
    on_exit = grab_on_exit(__CALLER__, block)

    quote do
      ExUnit.Callbacks.setup_all(unquote(context), unquote(block))

      Module.put_attribute(__MODULE__, :enfiladex_setup_all, %{
        on_entry: List.wrap(List.first(@ex_unit_setup_all)),
        on_exit: unquote(Macro.escape(on_exit)),
        group: @enfiladex_group
      })
    end
  end

  defp grab_on_exit(caller, block) do
    {_block, on_exit} =
      Macro.postwalk(block, [], fn
        # AM inject binding as
        {:on_exit, _meta, [{:fn, _, [{:->, _, [[], block]}]}]}, acc -> {nil, [block | acc]}
        other, acc -> {other, acc}
      end)

    {result, all_errors_and_warnings} =
      Code.with_diagnostics(fn ->
        try do
          {:ok, Code.compile_quoted({:fn, [], [{:->, [], [[], on_exit]}]}, caller.file)}
        rescue
          err -> {:error, err}
        end
      end)

    case result do
      {:ok, _ast} ->
        on_exit

      _ ->
        # with {:ok, pid} <- Module.ParallelChecker.start_link(),
        #      do: :erlang.put(:elixir_checker_info, {pid, nil})

        # :erlang.erase(:elixir_code_diagnostics)

        IO.puts(
          "Capturing a context from `on_exit/2` callback in not allowed yet in `Enfiladex`, " <>
            "no teardown callback would have been defined."
        )

        Enum.each(all_errors_and_warnings, &Code.print_diagnostic/1)

        [quote(do: fn -> :ok end)]
    end
  end

  @doc false
  def fix_atom_name(group) when is_atom(group), do: group

  if @normalize_group_names do
    def fix_atom_name(<<head::size(8), _::binary>> = group) when head in ?a..?z,
      do: group |> String.replace(~r/[^a-zA-Z_0-9]/, "_") |> String.to_atom()

    def fix_atom_name(group) when is_binary(group) do
      "enfiladex_"
      |> Kernel.<>(group)
      |> String.replace(~r/[^a-zA-Z_0-9]/, "_")
      |> String.to_atom()
    end
  else
    def fix_atom_name(group) when is_binary(group), do: String.to_atom(group)
  end

  @doc """
  Hello world.

  ## Examples

      iex> Enfiladex.hello()
      :world

  """
  def hello do
    :world
  end
end
