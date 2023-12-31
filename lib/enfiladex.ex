defmodule Enfiladex do
  @moduledoc """
  `Enfiladex` is the drop-in `Common Test` wrapper for _Elixir_.
  """

  def peer(fun, callback \\ [], config \\ [])
      when (is_tuple(fun) or is_function(fun, 0) or is_function(fun, 1) or is_function(fun, 2)) and
             (is_function(callback, 1) or is_list(callback)) do
    {callback, config} = fix_callback_config(callback, config)
    :enfiladex.anonymous_peer(fun, callback, config)
  end

  def multi_peer(fun, callback \\ [], config \\ [])
      when (is_tuple(fun) or is_function(fun, 0) or is_function(fun, 1) or is_function(fun, 2)) and
             (is_function(callback, 1) or is_list(callback)) do
    {callback, config} = fix_callback_config(callback, config)
    :enfiladex.multi_peer(fun, callback, config)
  end

  defp fix_callback_config(callback, config) do
    case {callback, config} do
      {[], config} -> {fn result -> result end, config}
      {config, []} when is_list(config) -> {fn result -> result end, config}
      {callback, config} when is_function(callback, 1) -> {callback, config}
    end
  end

  @doc """
  Hello world.

  ## Examples

      iex> Enfiladex.hello()
      :world

  """
  def hello do
    IO.inspect(:world, label: "Hello")
  end
end
