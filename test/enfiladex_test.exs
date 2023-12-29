defmodule Enfiladex.Suite do
  # defmodule :enfiladex_test do
  use ExUnit.Case
  use Enfiladex
  doctest Enfiladex

  @enfiladex_strategy :parallel
  setup do
    %{setup: 1}
  end

  setup ctx do
    IO.inspect(ctx, label: "SETUP MAIN 2")

    on_exit(fn ->
      IO.puts("ON EXIT 2. Process: #{inspect(self())}")
    end)

    Map.put(ctx, :setup_two, 2)
  end

  defp foo_setup(context), do: IO.inspect(%{context: context}, label: "FOO_SETUP")

  describe "failing tests" do
    setup :foo_setup

    setup do
      IO.inspect("SETUP FT")
      [setup: 2]
    end

    test "this will be a test in future"

    test "greets the world", _ctx do
      assert Enfiladex.hello() != :world
    end
  end

  test "greets the world", _ctx do
    :enfiladex.multi_node([], &IO.inspect/1)
  end
end
