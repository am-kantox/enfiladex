defmodule Enfiladex.Test.Suite do
  # defmodule :enfiladex_test do
  use ExUnit.Case
  use Enfiladex.Suite
  doctest Enfiladex

  setup do
    %{setup_first: [self()]}
  end

  defp foo_setup(context), do: Map.update(context, :foo_setup, [self()], &[self() | &1])
  defp bar_setup(context), do: Map.update(context, :bar_setup, [self()], &[self() | &1])

  test "very first", ctx do
    count = 3
    Enfiladex.multi_peer({Enfiladex, :test, [self(), ctx]}, nodes: count)

    for _ <- 1..count do
      assert_receive {node, pid, _ctx}
      assert is_pid(pid)

      assert [node, Node.self()]
             |> Enum.map(&to_string/1)
             |> Enum.map(&String.split(&1, "@"))
             |> Enum.map(&List.last/1)
             |> Enum.reduce(&Kernel.==/2)
    end
  end

  setup_all context do
    on_exit(fn -> IO.puts("ALL TEARDOWN") end)

    Map.update(context, :setup_all, [self()], &[self() | &1])
  end

  setup_all :foo_setup

  @enfiladex_strategy :parallel

  setup context do
    on_exit(fn ->
      nil
      # IO.puts("ON EXIT 2. CTX: #{inspect(ctx)}. Process: #{inspect(self())}")
    end)

    Map.update(context, :setup, [self()], &[self() | &1])
  end

  setup [:foo_setup, :bar_setup]

  # describe "failing tests" do
  #   setup :foo_setup

  #   test "this will be a test in future"

  #   test "greets the world", _ctx do
  #     assert 42 == :ok
  #   end
  # end

  describe "succeedeing tests" do
    setup :foo_setup

    test "greets the world", _ctx do
      assert 42 != :ok
    end
  end

  test "greets the world", ctx do
    Enfiladex.peer({Enfiladex, :test, [self(), ctx]})

    assert_receive {node, pid, _ctx}
    assert is_pid(pid)

    assert [node, Node.self()]
           |> Enum.map(&to_string/1)
           |> Enum.map(&String.split(&1, "@"))
           |> Enum.map(&List.last/1)
           |> Enum.reduce(&Kernel.==/2)
  end
end
