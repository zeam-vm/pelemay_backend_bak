defmodule PelemayBackend.NIF do
  @moduledoc """
  Documentation for `PelemayBackend.NIF`.
  """
  require Logger

  @on_load :load_nif

  @doc false
  def load_nif do
    nif_file = ~c'#{Application.app_dir(:pelemay_backend, "priv/libnif")}'

    case :erlang.load_nif(nif_file, 0) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok
      {:error, reason} -> Logger.error("Failed to load NIF: #{inspect(reason)}")
    end
  end

  def execute_engine(_code), do: :erlang.nif_error(:not_loaded)

  @doc """
  Copys 32bit float.
  ## Examples

      iex> SampleNxOpenBlas.copy_f32(0)
      #Nx.Tensor<
        f32[1]
        [0.0]
      >

      iex> SampleNxOpenBlas.copy_f32(Nx.tensor([0, 1, 2, 3]))
      #Nx.Tensor<
        f32[4]
        [0.0, 1.0, 2.0, 3.0]
      >

  """
  def copy_f32(t), do: copy(t, {:f, 32})

  @doc false
  def copy(t, type) when is_struct(t, Nx.Tensor) do
    copy_sub(Nx.as_type(t, type), type)
  end

  @doc false
  def copy(t, type) when is_number(t) do
    copy(Nx.tensor([t]), type)
  end

  defp copy_sub(t, type) do
    Nx.from_binary(copy_sub_sub(Nx.size(t), Nx.shape(t), Nx.to_binary(t), type), type)
  end

  defp copy_sub_sub(size, shape, binary, {:f, 32}) do
    try do
      scopy_nif(size, shape, binary)
    rescue
      e in ErlangError -> raise RuntimeError, message: List.to_string(e.original)
    end
  end

  def scopy_nif(_size, _shape, _binary), do: :erlang.nif_error(:not_loaded)

  @doc """
  Copys 32bit float.
  ## Examples

      iex> SampleNxOpenBlas.copy_scal_f32(2.0, 1)
      #Nx.Tensor<
        f32[1]
        [2.0]
      >

      iex> SampleNxOpenBlas.copy_scal_f32(1.5, Nx.tensor([0, 1, 2, 3]))
      #Nx.Tensor<
        f32[4]
        [0.0, 1.5, 3.0, 4.5]
      >

  """
  def copy_scal_f32(alpha, t), do: copy_scal(alpha, t, {:f, 32})

  @doc false
  def copy_scal(alpha, t, type) when is_struct(t, Nx.Tensor) do
    copy_scal_sub(alpha, Nx.as_type(t, type), type)
  end

  @doc false
  def copy_scal(alpha, t, type) when is_number(t) do
    copy_scal(alpha, Nx.tensor([t]), type)
  end

  defp copy_scal_sub(alpha, t, type) do
    Nx.from_binary(copy_scal_sub_sub(alpha, Nx.size(t), Nx.shape(t), Nx.to_binary(t), type), type)
  end

  defp copy_scal_sub_sub(alpha, size, shape, binary, {:f, 32}) do
    try do
      scopy_sscal_nif(alpha, size, shape, binary)
    rescue
      e in ErlangError -> raise RuntimeError, message: List.to_string(e.original)
    end
  end

  def scopy_sscal_nif(_scholar, _size, _shape, _binary), do: :erlang.nif_error(:not_loaded)
end
