defmodule PelemayBackendTest do
  use ExUnit.Case
  doctest PelemayBackend

  setup do
    Nx.default_backend(PelemayBackend)
    :ok
  end

  @unrelated_doctests [
    default_backend: 1
  ]

  doctest Nx,
    except:
      [:moduledoc] ++
        @unrelated_doctests
end
