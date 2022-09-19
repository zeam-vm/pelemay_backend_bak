defmodule PelemayBackend.Defn do
  @moduledoc false

  require Logger

  @doc false
  def __stream__(_key, _input, _acc, _vars, _fun, [_args], _options) do
  end

  @doc false
  def __jit__(key, vars, fun, args_list, options) do
    __compile__(key, vars, fun, options).(args_list)
  end

  @doc false
  def __compile__(_key, _vars, _fun, options) do
    #Logger.debug(
    #  "__compile__(key: #{inspect(key)}, vars: #{inspect(vars)}, fun: #{inspect(fun)}, options: #{inspect(options)})"
    #)

    #Logger.debug("fun #{inspect(fun)}(#{inspect(vars)}): #{inspect(fun.(vars))}")

    {_run_options, _compile_options} = Keyword.pop(options, :run_options, [])

    fn [args] ->
      code =
      """
      is_scalar Enum.at(args, 0)
      skip {5, {:if, true}}
      pusht Enum.at(args, 0)
      copy
      scal Enum.at(args, 1)
      sendt self()
      return
      pusht Enum.at(args, 1)
      copy
      scal Enum.at(args, 0)
      sendt self()
      """
      |> PelemayBackend.Engine.assemble(args: args)

      try do
        case PelemayBackend.Engine.execute(code) do
          :ok -> :ok
          {:error, reason} -> raise RuntimeError, message: List.to_string(reason)
        end
      rescue
        e in ErlangError -> raise RuntimeError, message: List.to_string(e.original)
      end

      receive do
        {:result, binary, shape, type} ->
          Nx.from_binary(binary, type)
          |> Nx.reshape(shape)
          |> then(&[&1])
      after
        5000 ->
          raise RuntimeError, message: "timeout"
      end
    end
  end
end
