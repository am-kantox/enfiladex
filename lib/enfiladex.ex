defmodule Enfiladex do
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

  @enfiladex_strategy :enfiladex
                      |> Application.compile_env(:default_group_strategy)
                      |> List.wrap()
  defmacro __using__(_opts \\ []) do
    quote generated: true, location: :keep do
      @before_compile Enfiladex
      @after_compile Enfiladex

      Module.register_attribute(__MODULE__, :enfiladex_strategy, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :enfiladex_tests, accumulate: true, persist: true)

      @enfiladex_strategy unquote(@enfiladex_strategy)

      import ExUnit.Case, only: [test: 1]
      require ExUnit.Case

      import Enfiladex, only: [describe: 2, test: 2, test: 3]
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true, location: :keep do
      @tests Enum.reduce(@enfiladex_tests, %{}, fn %ExUnit.Test{
                                                     name: test,
                                                     tags: %{
                                                       describe: group,
                                                       enfiladex_strategy: enfiladex_strategy
                                                     }
                                                   },
                                                   acc ->
               group = if is_binary(group), do: String.to_atom(group), else: group

               acc
               |> Map.put_new(group, %{tests: [], enfiladicis: MapSet.new([])})
               |> update_in([group, :tests], &(List.wrap(&1) ++ [test]))
               |> update_in([group, :enfiladicis], &MapSet.put(&1, enfiladex_strategy))
             end)

      def groups do
        Enum.flat_map(@tests, fn
          {nil, %{tests: tests, enfiladicis: enfiladex_strategy}} ->
            []

          {group, %{tests: tests, enfiladicis: enfiladex_strategy}} ->
            if MapSet.size(enfiladex_strategy) > 1 do
              raise Enfiladex.ModuleAttributeError,
                    "`@enfiladex_strategy` attribute must be the same for all tests " <>
                      "in `group`/`describe`"
            end

            [{group, MapSet.to_list(enfiladex_strategy), tests}]
        end)
      end

      def all do
        Enum.flat_map(@tests, fn
          {nil, %{tests: tests}} -> tests
          {group, _} -> [{:group, group}]
        end)
      end

      :ok
    end
  end

  defmacro __after_compile__(_env, _bytecode) do
    quote do
      IO.inspect(__MODULE__.__info__(:functions), label: "AFTER")
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
      ExUnit.Case.describe(unquote(message), unquote(do: block))
      @enfiladex_strategy unquote(@enfiladex_strategy)
    end
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
