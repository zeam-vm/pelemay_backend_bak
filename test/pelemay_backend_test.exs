defmodule PelemayBackendTest do
  use ExUnit.Case

  doctest PelemayBackend,
    except: [stream_cached?: 3, cached?: 3, jit: 2, jit_apply: 3, compile: 3]

  test "multiply scalar and vector(1000)" do
    input = Nx.iota({1000}, type: {:f, 32})
    fun = &Nx.multiply(&1, &2)
    assert fun.(2.0, input) == PelemayBackend.jit_apply(fun, [2.0, input])
  end
end
