defmodule PelemayBackendTest do
  use ExUnit.Case
  doctest PelemayBackend,
    except:
      [stream_cached?: 3, cached?: 3, jit: 2, jit_apply: 3, compile: 3]
end
