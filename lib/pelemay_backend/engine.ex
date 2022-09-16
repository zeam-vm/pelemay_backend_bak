defmodule PelemayBackend.Engine do
  @moduledoc """
  Document for `PelemayBackend.Engine`.
  """

  @type opcode :: non_neg_integer()
  @type oprand :: any()

  @doc """
  Executes code for the engine.

  The code should be a list of tuples of an opcode and an operand.
  """
  @spec execute(list({opcode(), oprand()})) :: :ok | {:error, String.t()}
  def execute(code) do
    PelemayBackend.NIF.execute_engine(code)
  end
end
