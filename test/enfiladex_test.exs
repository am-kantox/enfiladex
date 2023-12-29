defmodule Enfiladex.Suite do
  # defmodule :enfiladex_test do
  use ExUnit.Case
  use Enfiladex
  doctest Enfiladex

  @enfiladex_strategy :parallel
  describe "failing tests" do
    test "this will be a test in future"

    test "greets the world", _ctx do
      assert Enfiladex.hello() != :world
    end
  end

  test "greets the world", _ctx do
    :enfiladex.multi_node([], &IO.inspect/1)
  end
end
