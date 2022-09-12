defmodule PelemayBackend.Backend do
  @moduledoc ~S"""
  An integrated lightweight tensor backend for Nx.
  """

  use Complex.Kernel

  @behaviour Nx.Backend

  @doc false
  defstruct [:state]

  alias Nx.Tensor, as: T
  alias Nx.BinaryBackend, as: B

  import Nx.Shared
  import Bitwise, only: [>>>: 2, &&&: 2]

  @impl true
  defdelegate constant(out, constant, backend_options), to: Nx.BinaryBackend

  @impl true
  defdelegate random_uniform(out, min, max, backend_options), to: Nx.BinaryBackend

  @impl true
  defdelegate random_normal(out, mu, sigma, backend_options), to: Nx.BinaryBackend

  @impl true
  defdelegate iota(out, axis, backend_options), to: Nx.BinaryBackend

  @impl true
  defdelegate eye(out, backend_options), to: Nx.BinaryBackend

  @impl true
  defdelegate from_binary(t, binary, backend_options), to: Nx.BinaryBackend

  @impl true
  defdelegate to_binary(t, limit), to: Nx.BinaryBackend

  @impl true
  defdelegate backend_copy(tensor, backend, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate backend_transfer(tensor, backend, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate backend_deallocate(tensor), to: Nx.BinaryBackend

  @impl true
  defdelegate to_batched(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate reshape(out, tensor), to: Nx.BinaryBackend

  @impl true
  defdelegate squeeze(out, tensor, axes), to: Nx.BinaryBackend

  @impl true
  defdelegate broadcast(out, t, shape, axes), to: Nx.BinaryBackend

  @impl true
  defdelegate transpose(out, t, axes), to: Nx.BinaryBackend

  @impl true
  defdelegate pad(out, t, pad_value, padding_config), to: Nx.BinaryBackend

  @impl true
  defdelegate reverse(out, t, axes), to: Nx.BinaryBackend

  @impl true
  defdelegate dot(out, left, contract_axes1, batch_axes2, right, contract_axes2, batch_axes2),
    to: Nx.BinaryBackend

  @impl true
  defdelegate select(out, pred, on_true, on_false), to: Nx.BinaryBackend

  ## Element wise bin ops

  for fun <-
        [:add, :subtract, :multiply, :power, :remainder, :divide, :atan2, :min, :max, :quotient] ++
          [:bitwise_and, :bitwise_or, :bitwise_xor, :left_shift, :right_shift] ++
          [:equal, :not_equal, :greater, :less, :greater_equal, :less_equal] ++
          [:logical_and, :logical_or, :logical_xor] do
    capture = Macro.var(:"element_#{fun}", __MODULE__)

    @impl true
    def unquote(fun)(out, left, right) do
      element_wise_bin_op(out, left, right, &(unquote(capture) / 3))
    end
  end

  defp element_wise_bin_op(%{type: type} = out, %{shape: {}} = left, right, fun) do
    number = scalar_to_number(left)

    data =
      binary_to_binary(to_binary(right), right.type, type, fn x ->
        fun.(type, number, x)
      end)

    from_binary(out, data)
  end

  defp element_wise_bin_op(%{type: type} = out, left, %{shape: {}} = right, fun) do
    number = scalar_to_number(right)

    data =
      binary_to_binary(to_binary(left), left.type, type, fn x ->
        fun.(type, x, number)
      end)

    from_binary(out, data)
  end

  defp element_wise_bin_op(%{shape: shape, type: type} = out, left, right, fun) do
    %T{type: {_, left_size} = left_type} = left
    %T{type: {_, right_size} = right_type} = right

    count = Nx.size(shape)
    left_data = broadcast_data(left, shape)
    right_data = broadcast_data(right, shape)

    data =
      match_types [left_type, right_type, type] do
        for i <- 0..(count - 1), into: <<>> do
          left_consumed = i * left_size
          <<_::size(left_consumed)-bitstring, match!(x, 0), _::bitstring>> = left_data
          x = read!(x, 0)

          right_consumed = i * right_size
          <<_::size(right_consumed)-bitstring, match!(y, 1), _::bitstring>> = right_data
          y = read!(y, 1)

          <<write!(fun.(type, x, y), 2)>>
        end
      end

    from_binary(out, data)
  end

  defp element_add(_, a, b), do: Complex.add(a, b)
  defp element_subtract(_, a, b), do: Complex.subtract(a, b)
  defp element_multiply(_, a, b), do: Complex.multiply(a, b)
  defp element_divide(_, a, b), do: Complex.divide(a, b)
  defp element_quotient(_, a, b), do: div(a, b)

  defp element_remainder(_, a, b) when is_integer(a) and is_integer(b), do: rem(a, b)
  defp element_remainder(_, a, b), do: :math.fmod(a, b)

  defp element_atan2(_, a, b), do: Complex.atan2(a, b)

  defp element_max(_, :nan, _), do: :nan
  defp element_max(_, _, :nan), do: :nan
  defp element_max(_, :infinity, _), do: :infinity
  defp element_max(_, _, :infinity), do: :infinity
  defp element_max(_, :neg_infinity, x), do: x
  defp element_max(_, x, :neg_infinity), do: x
  defp element_max(_, a, b) when is_number(a) and is_number(b), do: max(a, b)

  defp element_min(_, :nan, _), do: :nan
  defp element_min(_, _, :nan), do: :nan
  defp element_min(_, :infinity, x), do: x
  defp element_min(_, x, :infinity), do: x
  defp element_min(_, :neg_infinity, _), do: :neg_infinity
  defp element_min(_, _, :neg_infinity), do: :neg_infinity
  defp element_min(_, a, b) when is_number(a) and is_number(b), do: min(a, b)

  defp element_power({type, _}, a, b) when type in [:s, :u], do: Integer.pow(a, b)
  defp element_power(_, a, b), do: Complex.power(a, b)

  defp element_bitwise_and(_, a, b), do: :erlang.band(a, b)
  defp element_bitwise_or(_, a, b), do: :erlang.bor(a, b)
  defp element_bitwise_xor(_, a, b), do: :erlang.bxor(a, b)

  defp element_left_shift(_, a, b) when is_number(b) and b >= 0,
    do: :erlang.bsl(a, b)

  defp element_left_shift(_, _, b), do: raise(ArgumentError, "cannot left shift by #{b}")

  defp element_right_shift(_, a, b) when is_number(b) and b >= 0,
    do: :erlang.bsr(a, b)

  defp element_right_shift(_, _, b), do: raise(ArgumentError, "cannot right shift by #{b}")

  defp element_equal(_, :nan, _), do: 0
  defp element_equal(_, _, :nan), do: 0
  defp element_equal(_, a, b), do: boolean_as_number(a == b)

  defp element_not_equal(_, :nan, _), do: 1
  defp element_not_equal(_, _, :nan), do: 1
  defp element_not_equal(_, a, b), do: boolean_as_number(a != b)

  defp element_logical_and(_, a, b), do: boolean_as_number(as_boolean(a) and as_boolean(b))
  defp element_logical_or(_, a, b), do: boolean_as_number(as_boolean(a) or as_boolean(b))
  defp element_logical_xor(_, a, b), do: boolean_as_number(as_boolean(a) != as_boolean(b))

  defp element_greater(_, :nan, _), do: 0
  defp element_greater(_, _, :nan), do: 0
  defp element_greater(_, x, x), do: 0
  defp element_greater(_, :infinity, _), do: 1
  defp element_greater(_, _, :neg_infinity), do: 1
  defp element_greater(_, :neg_infinity, _), do: 0
  defp element_greater(_, _, :infinity), do: 0
  defp element_greater(_, a, b), do: boolean_as_number(a > b)

  defp element_less(_, :nan, _), do: 0
  defp element_less(_, _, :nan), do: 0
  defp element_less(_, :infinity, _), do: 0
  defp element_less(_, _, :neg_infinity), do: 0
  defp element_less(_, x, x), do: 0
  defp element_less(_, _, :infinity), do: 1
  defp element_less(_, :neg_infinity, _), do: 1
  defp element_less(_, a, b), do: boolean_as_number(a < b)

  defp element_greater_equal(_, :nan, _), do: 0
  defp element_greater_equal(_, _, :nan), do: 0
  defp element_greater_equal(_, x, x), do: 1
  defp element_greater_equal(_, :neg_infinity, _), do: 0
  defp element_greater_equal(_, _, :infinity), do: 0
  defp element_greater_equal(_, :infinity, _), do: 1
  defp element_greater_equal(_, _, :neg_infinity), do: 1
  defp element_greater_equal(_, a, b), do: boolean_as_number(a >= b)

  defp element_less_equal(_, :nan, _), do: 0
  defp element_less_equal(_, _, :nan), do: 0
  defp element_less_equal(_, _, :infinity), do: 1
  defp element_less_equal(_, :neg_infinity, _), do: 1
  defp element_less_equal(_, x, x), do: 1
  defp element_less_equal(_, :infinity, _), do: 0
  defp element_less_equal(_, _, :neg_infinity), do: 0
  defp element_less_equal(_, a, b), do: boolean_as_number(a <= b)

  defp as_boolean(n) when n == 0, do: false
  defp as_boolean(%Complex{re: re, im: im}) when re == 0 and im == 0, do: false
  defp as_boolean(_), do: true

  defp boolean_as_number(true), do: 1
  defp boolean_as_number(false), do: 0

  ## Element wise unary ops

  for {name, {_desc, code, _formula}} <- Nx.Shared.unary_math_funs() do
    @impl true
    def unquote(name)(out, tensor) do
      element_wise_unary_op(out, tensor, fn x -> unquote(code) end)
    end
  end

  @impl true
  def count_leading_zeros(out, %{type: {_, size}} = tensor) do
    element_wise_bit_op(out, tensor, &element_clz(&1, size))
  end

  @impl true
  def population_count(out, tensor) do
    element_wise_bit_op(out, tensor, &element_popcount(&1, 0))
  end

  defp element_wise_bit_op(out, %{type: {_, size}} = tensor, fun) do
    data =
      match_types [out.type] do
        for <<seg::unsigned-size(size)-native <- to_binary(tensor)>>, into: <<>> do
          <<write!(fun.(seg), 0)>>
        end
      end

    from_binary(out, data)
  end

  @impl true
  def abs(out, tensor), do: element_wise_unary_op(out, tensor, &Complex.abs/1)

  @impl true
  def conjugate(out, tensor), do: element_wise_unary_op(out, tensor, &Complex.conjugate/1)

  @impl true
  defdelegate real(out, tensor),
    to: Nx.BinaryBackend

  @impl true
  defdelegate imag(out, tensor),
    to: Nx.BinaryBackend

  @impl true
  def bitwise_not(out, tensor), do: element_wise_unary_op(out, tensor, &:erlang.bnot/1)

  @impl true
  defdelegate is_nan(out, tensor), to: Nx.BinaryBackend

  @impl true
  defdelegate is_infinity(out, tensor), to: Nx.BinaryBackend

  @impl true
  def ceil(out, tensor), do: element_wise_unary_op(out, tensor, &:erlang.ceil/1)

  @impl true
  def floor(out, tensor), do: element_wise_unary_op(out, tensor, &:erlang.floor/1)
  @impl true
  def negate(out, tensor), do: element_wise_unary_op(out, tensor, &Complex.negate/1)

  @impl true
  def round(out, tensor), do: element_wise_unary_op(out, tensor, &:erlang.round/1)

  @impl true
  def sign(out, tensor), do: element_wise_unary_op(out, tensor, &element_sign/1)

  defp element_sign(n) when n < 0, do: -1
  defp element_sign(n) when n > 0, do: 1
  defp element_sign(n), do: n

  # https://en.wikipedia.org/wiki/Hamming_weight
  # There are algorithms with faster worst case but they are size specific.
  # The implementation below is also the most efficient for low counts. Given
  # our integers are always 64 bits internally, we will have a lot of zeros
  # internally, so this should be the fastest.
  defp element_popcount(0, count), do: count
  defp element_popcount(n, count), do: element_popcount(n &&& n - 1, count + 1)

  defp element_wise_unary_op(out, tensor, fun) do
    data = binary_to_binary(to_binary(tensor), tensor.type, out.type, fun)
    from_binary(out, data)
  end

  defp element_clz(0, size), do: size
  defp element_clz(n, 64), do: element_clz64(n)
  defp element_clz(n, 32), do: element_clz32(n)
  defp element_clz(n, 16), do: element_clz16(n)
  defp element_clz(n, 8), do: element_clz8(n)

  defp element_clz64(num) do
    case num &&& 0xFFFFFFFF00000000 do
      0 -> 32 + element_clz32(num)
      _ -> element_clz32(num >>> 32)
    end
  end

  defp element_clz32(num) do
    case num &&& 0xFFFF0000 do
      0 -> 16 + element_clz16(num)
      _ -> element_clz16(num >>> 16)
    end
  end

  defp element_clz16(num) do
    case num &&& 0xFF00 do
      0 -> 8 + element_clz8(num)
      _ -> element_clz8(num >>> 8)
    end
  end

  defp element_clz8(num) do
    case num &&& 0xF0 do
      0 -> 4 + element_clz4(num)
      _ -> element_clz4(num >>> 4)
    end
  end

  defp element_clz4(num) do
    case num &&& 0xC do
      0 -> 2 + element_clz2(num)
      _ -> element_clz2(num >>> 2)
    end
  end

  defp element_clz2(0), do: 2
  defp element_clz2(1), do: 1
  defp element_clz2(_), do: 0

  @impl true
  defdelegate inspect(tensor, inspect_opts), to: Nx.BinaryBackend

  @impl true
  defdelegate conv(out, t, k, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate cholesky(out, tensor), to: Nx.BinaryBackend

  @impl true
  defdelegate qr(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate eigh(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate svd(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate lu(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate triangular_solve(out, a, b, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate all(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate any(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate sum(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate product(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate reduce_max(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate reduce_min(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate argmin(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate argmax(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate reduce(out, tensor, acc, opts, fun), to: Nx.BinaryBackend

  @impl true
  defdelegate window_reduce(out, tensor, acc, window_dimensions, opts, fun), to: Nx.BinaryBackend

  @impl true
  defdelegate window_sum(out, tensor, window_dimensions, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate window_max(out, tensor, window_dimensions, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate window_min(out, tensor, window_dimensions, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate window_product(out, tensor, window_dimensions, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate map(out, tensor, opts, fun), to: Nx.BinaryBackend

  @impl true
  defdelegate window_scatter_max(out, tensor, source, init_value, window_dimensions, opts),
    to: Nx.BinaryBackend

  @impl true
  defdelegate window_scatter_min(out, tensor, source, init_value, window_dimensions, opts),
    to: Nx.BinaryBackend

  @impl true
  defdelegate indexed_add(out, target, indices, updates), to: Nx.BinaryBackend

  @impl true
  defdelegate indexed_put(out, target, indices, updates), to: Nx.BinaryBackend

  @impl true
  defdelegate clip(out, tensor, min, max), to: Nx.BinaryBackend

  @impl true
  defdelegate slice(out, tensor, start_indices, lengths, strides), to: Nx.BinaryBackend

  @impl true
  defdelegate put_slice(
                out,
                tensor,
                start_indices,
                slice,
                combine_fn \\ fn _prev, new -> new end
              ),
              to: Nx.BinaryBackend

  @impl true
  defdelegate take(out, tensor, indices, axis), to: Nx.BinaryBackend

  @impl true
  defdelegate take_along_axis(output, tensor, indices, axis), to: Nx.BinaryBackend

  @impl true
  defdelegate gather(out, tensor, indices), to: Nx.BinaryBackend

  @impl true
  defdelegate concatenate(out, tensors, axis), to: Nx.BinaryBackend

  @impl true
  defdelegate as_type(out, tensor), to: Nx.BinaryBackend

  @impl true
  defdelegate bitcast(out, tensor), to: Nx.BinaryBackend

  @impl true
  defdelegate sort(output, t, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate argsort(output, t, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate fft(out, tensor, opts), to: Nx.BinaryBackend

  @impl true
  defdelegate ifft(out, tensor, opts), to: Nx.BinaryBackend

  ## Conversion helpers

  defp scalar_to_number(n) when is_number(n), do: n
  defp scalar_to_number(%Complex{} = n), do: n
  defp scalar_to_number(t), do: binary_to_number(to_binary(t), t.type)

  defp binary_to_number(bin, type) do
    match_types [type] do
      <<match!(value, 0)>> = bin
      read!(value, 0)
    end
  end

  defp binary_to_binary(binary, in_type, out_type, fun) do
    match_types [in_type, out_type] do
      for <<match!(seg, 0) <- binary>>, into: <<>> do
        <<write!(fun.(read!(seg, 0)), 1)>>
      end
    end
  end

  defp from_binary(t, binary) when is_binary(binary), do: %{t | data: %B{state: binary}}
  defp from_binary(t, other), do: %{t | data: %B{state: IO.iodata_to_binary(other)}}

  defp to_binary(%T{data: %{state: data}}), do: data

  defp broadcast_data(%{shape: shape} = t, shape),
    do: to_binary(t)

  defp broadcast_data(t, shape),
    do: broadcast_data(t, shape, Nx.Shape.broadcast_axes(t.shape, shape))

  defp broadcast_data(%T{shape: {}} = t, shape, []) do
    t
    |> to_binary()
    |> :binary.copy(Nx.size(shape))
  end

  defp broadcast_data(%T{shape: old_shape, type: {_, size}} = t, new_shape, axes) do
    chunk_size = size * Nx.size(old_shape)

    new_shape
    |> Tuple.to_list()
    |> unary_broadcast(0, old_shape, 0, axes, to_binary(t), chunk_size)
    |> IO.iodata_to_binary()
  end

  # Old and new match
  defp unary_broadcast([dim | dims], axis, old_shape, old_pos, [axis | axes], data, chunk_size)
       when elem(old_shape, old_pos) == dim do
    chunk_size = div(chunk_size, dim)

    for <<chunk::size(chunk_size)-bitstring <- data>> do
      unary_broadcast(dims, axis + 1, old_shape, old_pos + 1, axes, chunk, chunk_size)
    end
  end

  # Implicit broadcasting
  defp unary_broadcast([dim | dims], axis, old_shape, old_pos, [axis | axes], data, chunk_size)
       when elem(old_shape, old_pos) == 1 do
    for _ <- 1..dim do
      unary_broadcast(dims, axis + 1, old_shape, old_pos + 1, axes, data, chunk_size)
    end
  end

  # Explicit broadcasting (unmapped axes)
  defp unary_broadcast([dim | dims], axis, old_shape, old_pos, axes, data, chunk_size) do
    for _ <- 1..dim do
      unary_broadcast(dims, axis + 1, old_shape, old_pos, axes, data, chunk_size)
    end
  end

  defp unary_broadcast([], _axis, _old_shape, _old_pos, [], data, _chunk_size) do
    data
  end
end
