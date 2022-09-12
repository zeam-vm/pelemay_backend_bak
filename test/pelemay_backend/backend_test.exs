defmodule PelemayBackend.BackendTest do
  use ExUnit.Case
  doctest PelemayBackend.Backend

  setup do
    Nx.default_backend(PelemayBackend.Backend)
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
