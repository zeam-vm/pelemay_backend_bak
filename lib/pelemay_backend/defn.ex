defmodule PelemayBackend.Defn do
  @moduledoc false

  require Logger
  alias Nx.Defn.{Composite, Expr, Tree}
  alias Nx.Tensor, as: T

  @doc false
  def __stream__(key, input, acc, vars, fun, [args], options) do
  end

  @doc false
  def __jit__(key, vars, fun, args_list, options) do
    __compile__(key, vars, fun, options).(args_list)
  end

  @doc false
  def __compile__(key, vars, fun, options) do
  end
end
