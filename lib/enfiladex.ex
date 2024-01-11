defmodule Enfiladex do
  @moduledoc """
  `Enfiladex` is the drop-in `Common Test` wrapper for _ExUnit_. It also exposes functions
  to run some code on a freshly started remote node(s).

  All one needs to evaluate the code on one or more of connected nodes, would be to
  call a function exported from this module.

  Known config parameters:

  - **`transfer_config`** (default: `true`) — whether the configuration of application(s)
    should be transferred to the started nodes, accepts `boolean() | atom()` where `atom()`
    is the application name besides already loaded the config is to be transferred for,
    normally it’s the main application configuration
  - **`start_applications`** (default: `true`) — `boolean() | atom()` specifying whether
    the application(s) should have been starter on the spawned node(s)
  - **`nodes`** (default: `3`) — for `multi_peer/3`, the number of nodes to start

  ---

  To use functions from this module with `ExUnit` tests, one needs a named node.
  Either run `mix test` in a named environment, or use `mix enfiladex.ex_unit` task.

  Allowed start options besides ones above: https://www.erlang.org/doc/man/peer#type-start_options
  """

  @typedoc "The peer handler"
  @type peer :: pid()

  @typedoc "The return value of the function executed on remote peer"
  @type callee_return_value :: any()

  @typedoc "The function to be passed for execution on the remote node(s)"
  @type callee ::
          {module(), atom(), [term()]}
          | (-> callee_return_value())
          | (node() -> callee_return_value())
          | (:peer.server_ref(), node() -> callee_return_value())

  @typedoc "The return value of the callback function executed from remote peer"
  @type callback_return_value :: any()

  @typedoc "The callback to be called on the result on the remote node(s)"
  @type callback ::
          (callee_return_value() -> callback_return_value())
          | (node(), callee_return_value() -> callback_return_value())
          | (:peer.server_ref(), node(), callee_return_value() -> callback_return_value())

  @default_nodes_count Application.compile_env(:enfiladex, :default_nodes_count, 3)

  @doc """
  Executes the function given as first argument on the newly spawned node, with options
    passed as `config` argument.

  It would call `Callback(Result)` if `callback` passed before stopping the peer.

  ## Examples

      iex> {_, _, result} = Enfiladex.peer({IO, :inspect, [:ok]})
      ...> result
      :ok
  """
  @spec peer(callee(), callback() | keyword(), keyword()) :: callee_return_value()
  def peer(fun, callback \\ [], config \\ [])
      when (is_tuple(fun) or is_function(fun)) and (is_function(callback) or is_list(callback)) do
    {callback, config} = fix_callback_config(callback, config)
    [result] = :enfiladex.run_in_peers(fun, callback, Keyword.put(config, :nodes, 1))
    result
  end

  @doc """
  Executes the function given as first argument on several newly spawned nodes, with options
    passed as `config` argument.

  It would call `Callback(Result)` for each result on each node, if `callback` passed before
    stopping the peer. The order is not guaranteed.
  """
  @spec multi_peer(callee(), callback() | keyword(), keyword()) :: [callee_return_value()]
  def multi_peer(fun, callback \\ [], config \\ [])
      when (is_tuple(fun) or is_function(fun)) and (is_function(callback) or is_list(callback)) do
    {callback, config} = fix_callback_config(callback, config)
    :enfiladex.run_in_peers(fun, callback, config)
  end

  @doc """
  Starts the requested amount of peers. These peers should be then stopped with `stop_peers/1`.
  """
  @spec start_peers(pos_integer(), keyword()) ::
          {[
             {:ok, peer()} | {:ok, peer(), node()} | {:error, any()}
           ], [{peer(), node()}]}
  def start_peers(nodes \\ @default_nodes_count, config \\ [])
      when is_integer(nodes) and nodes > 0 do
    :enfiladex.start_peers(Keyword.put(config, :nodes, nodes))
  end

  @doc """
  Stops the peers previously started with `start_peers/1`.
  """
  @spec stop_peers(peer() | [peer()]) :: [:ok]
  def stop_peers(peers) do
    peers |> List.wrap() |> :enfiladex.stop_peers()
  end

  @spec fix_callback_config(callback() | keyword(), keyword()) :: {callback(), keyword()}
  defp fix_callback_config(callback, config) do
    case {callback, config} do
      {[], config} -> {fn result -> result end, config}
      {config, []} when is_list(config) -> {fn result -> result end, config}
      {callback, config} when is_function(callback) -> {callback, config}
    end
  end

  @doc false
  def test(pids, payload) when is_list(pids) do
    for pid <- pids, do: test(pid, payload)
  end

  def test(pid, payload) when is_pid(pid) do
    send(pid, {node(), self(), payload})
  end
end
