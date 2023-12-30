defmodule Enfiladex.Suite do
  # defmodule :enfiladex_test do
  use ExUnit.Case
  use Enfiladex
  doctest Enfiladex

  defp foo_setup(context), do: IO.inspect(%{context: context}, label: "FOO_SETUP")
  defp bar_setup(context), do: IO.inspect(%{context: context}, label: "BAR_SETUP")

  test "very first", _ctx do
    :enfiladex.multi_node([], &IO.inspect/1)
  end

  @enfiladex_strategy :parallel

  setup do
    %{setup_first: :ok}
  end

  setup ctx do
    IO.inspect(ctx, label: "SETUP MAIN 2")

    on_exit(fn ->
      IO.puts("ON EXIT 2. CTX: #{inspect(ctx)}. Process: #{inspect(self())}")
    end)

    Map.put(ctx, :setup_second, :ok)
  end

  setup [:foo_setup, :bar_setup]

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

  describe "succeedeing tests" do
    setup :foo_setup

    test "greets the world", _ctx do
      assert Enfiladex.hello() == :world
    end
  end

  test "greets the world", _ctx do
    :enfiladex.multi_node([], &IO.inspect/1)
  end
end
