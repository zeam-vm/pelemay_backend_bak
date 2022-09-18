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
    Logger.debug(
      "__compile__(key: #{inspect(key)}, vars: #{inspect(vars)}, fun: #{inspect(fun)}, options: #{inspect(options)})"
    )

    Logger.debug("fun #{inspect(fun)}(#{inspect(vars)}): #{inspect(fun.(vars))}")

    {run_options, compile_options} = Keyword.pop(options, :run_options, [])
    callback = &to_root_computation(key, &1, &2, &3, compile_options)

    {executable, used_inputs, outputs, hooks, :ok, debug?} =
      compile(key, vars, fun, compile_options, & &1, callback)

    fn [args] ->
      {time, lock} =
        :timer.tc(fn ->
          # PelemayBackend.Defn.Lock.lock(run_key(executable))
        end)

      if debug? do
        # Logger.debug("PelemayBackend device #{executable.device_id} lock in #{us_to_ms(time)}ms")
      end

      {time, res} =
        :timer.tc(fn ->
          maybe_outfeed(lock, executable, args, used_inputs, outputs, hooks, run_options)
        end)

      if debug? do
        #Logger.debug(
        #  "PelemayBackend execution on device #{executable.device_id} in #{us_to_ms(time)}ms"
        #)
      end

      res
    end
  end

  defp to_root_computation(key, expr, used_shapes, used_hooks, options) do
    Logger.debug(
      "to_root_computation(key: #{inspect(key)}, expr: #{inspect(expr)}, used_shapes: #{inspect(used_shapes)}, used_hooks: #{inspect(used_hooks)}, options: #{inspect(options)})"
    )

    # builder = EXLA.Builder.new(inspect(key))

    # params =
    #  Enum.with_index(used_shapes, fn {pos, shape}, i ->
    #    {pos, EXLA.Op.parameter(builder, i, shape, "p#{i}")}
    #  end)

    # state = %{
    #  precision: Keyword.get(options, :precision, :highest),
    #  builder: builder,
    #  params: Map.new(params)
    # }

    # token = EXLA.Op.create_token(builder)
    # {res, cache} = recur_flatten(expr, state, new_cache(token, used_hooks))
    # {token, used_hooks, outfeed_hooks} = get_hooks(cache)
    # close_outfeed(builder, used_hooks, token)

    # {EXLA.Builder.build(res), :ok, outfeed_hooks}
  end

  defp maybe_outfeed(lock, executable, args, used_inputs, outputs, hooks, run_options)
       when hooks == %{} do
    Logger.debug("maybe_outfeed(lock: #{inspect(lock)}, executable: #{inspect(executable)}, args: #{inspect(args)}, used_inputs: #{inspect(used_inputs)}, outputs: #{inspect(outputs)}, hooks: #{inspect(hooks)}, run_options: #{inspect(run_options)}")

    try do
      [Nx.tensor([2.0, 4.0], type: {:f, 32})]
    after
      # PelemayBackend.Defn.Lock.unlock(lock)
    end

    #try do
    #  buffers =
    #    args
    #    |> filter_inputs(used_inputs)
    #    |> EXLA.Defn.Buffers.from_nx!()

    #  EXLA.Executable.run(executable, [buffers], run_options)
    #else
    #  [result] -> [EXLA.Defn.Buffers.to_nx!(result, outputs)]
    #after
    #  EXLA.Defn.Lock.unlock(lock)
    #end
  end

  defp maybe_outfeed(lock, executable, args, used_inputs, outputs, hooks, run_options) do
    Logger.debug("maybe_outfeed(lock: #{inspect(lock)}, executable: #{inspect(executable)}, args: #{inspect(args)}, used_inputs: #{inspect(used_inputs)}, outputs: #{inspect(outputs)}, hooks: #{inspect(hooks)}, run_options: #{inspect(run_options)}")

    #buffers =
    #  args
    #  |> filter_inputs(used_inputs)
    #  |> EXLA.Defn.Buffers.from_nx!()

    #{:ok, runner} =
    #  EXLA.Defn.Runner.start_link(lock, fn ->
    #    EXLA.Executable.run(executable, [buffers], run_options)
    #  end)

    #{:ok, outfeed} = EXLA.Defn.Outfeed.start_child(executable, hooks)
    #_ = EXLA.Defn.Lock.transfer(lock, fn -> send(runner, lock) end, outfeed)

    #ref = Process.monitor(outfeed)

    #receive do
    #  {:DOWN, ^ref, _, _, _} ->
    #    [result] = EXLA.Defn.Runner.read(runner)
    #    [EXLA.Defn.Buffers.to_nx!(result, outputs)]
    #end
  end

  defp run_key(%{}), do: :global_lock

  ## Compile

  defp compile(key, vars, fun, options, to_used, to_computation) do
    Logger.debug(
      "compile(key: #{inspect(key)}, vars: #{inspect(vars)}, fun: #{inspect(fun)}, options: #{inspect(options)}, to_used: #{inspect(to_used)}, to_computation: #{inspect(to_computation)}"
    )

    # {{expr_cache_fun, comp_cache_fun}, options} =
    #  case Keyword.pop(options, :cache, true) do
    #    {true, options} ->
    #      Keyword.pop(options, EXLA, {&EXLA.Defn.LockedCache.run/2, &EXLA.Defn.LockedCache.run/2})

    #    {false, options} ->
    #      cache_fun = fn _key, fun -> fun.() end
    #      {{cache_fun, cache_fun}, options}
    #  end

    # {debug?, options} = Keyword.pop(options, :debug, false)

    # {args_key, reverse_args_triplet} =
    #  Enum.map_reduce(vars, [], fn var, acc ->
    #    Nx.Defn.Composite.traverse(var, acc, fn
    #      %T{type: type, shape: shape, names: names}, acc ->
    #        triplet = {type, shape, names}
    #        {triplet, [triplet | acc]}
    #    end)
    #  end)

    # {time, {expr, {ref, used_inputs, defined_hooks, outputs}}} =
    #  :timer.tc(fn ->
    #    expr_cache_fun.({key, args_key}, fn ->
    #      expr = fun.(vars)
    #      {expr, used_inputs_and_hooks(expr)}
    #    end)
    #  end)

    # if debug? do
    #  hit_or_miss = if expr, do: "", else: " cache hit"
    #  Logger.debug("EXLA defn evaluation#{hit_or_miss} in #{us_to_ms(time)}ms")
    # end

    # Hooks with default callbacks or user callbacks are part of the cache key
    # {hooks, options} = Keyword.pop(options, :hooks, %{})
    # used_hooks = Enum.sort(for {k, v} <- defined_hooks, v != nil or Map.has_key?(hooks, k), do: k)

    # used_inputs = to_used.(used_inputs)
    # comp_key = {ref, client.name, used_hooks, options}

    # {time, {evaled, {executable, extra, outfeed_hooks}}} =
    #  :timer.tc(fn ->
    #    comp_cache_fun.(comp_key, fn ->
    #      shapes =
    #        reverse_args_triplet
    #        |> Enum.reverse()
    #        |> filter_inputs(used_inputs)
    #        |> Enum.map(fn {type, shape, _names} -> EXLA.Shape.make_shape(type, shape) end)

    #      inputs_and_shapes = Enum.zip(used_inputs, shapes)

    #      {computation, extra, hooks} =
    #        to_computation.(expr || fun.(vars), inputs_and_shapes, used_hooks)

    #      executable = EXLA.Computation.compile(computation, client, shapes, options)
    #      {:ok, {executable, extra, hooks}}
    #    end)
    #  end)

    # Now finally compute the hooks to give to outfeed
    # hooks =
    #  for {flag, {key, template, shapes}} <- outfeed_hooks,
    #      do: {flag, {shapes, compile_hook(key, hooks, defined_hooks, template)}},
    #      into: %{}

    # if debug? do
    #  hit_or_miss = if evaled, do: "", else: " cache hit"
    #  Logger.debug("EXLA compilation#{hit_or_miss} in #{us_to_ms(time)}ms")
    # end

    #{executable, used_inputs, outputs, hooks, extra, debug?}
    {%{}, nil, nil, %{}, :ok, false}
  end

  defp us_to_ms(time), do: Float.round(time / 1000, 1)
end
