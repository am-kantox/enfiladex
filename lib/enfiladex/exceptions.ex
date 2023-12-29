defmodule Enfiladex.ModuleAttributeError do
  @moduledoc """
  Exception raised to indicate the misplaced module attribute.
  """

  @type t :: %__MODULE__{message: String.t()}

  defexception [:message]
end
