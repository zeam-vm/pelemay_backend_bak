defmodule PelemayBackend.Engine do
  @moduledoc """
  Document for `PelemayBackend.Engine`.
  """
  import Bitwise
  require Logger

  @opcode_macro "PELEMAY_ENGINE_OPCODE_H"
  @opcode_header "nif_src/opcode.h"

  @type opcode :: non_neg_integer()
  @type operand :: any()

  @doc """
  Gets key of opcode.
  """
  def key_opcode() do
    [
      :instruction,
      :reserved
    ]
  end

  @doc """
  Gets map instruction to code.
  """
  def instruction_code() do
    %{
      scal: 0x0000,
      sscal: 0x0001,
      copy: 0x0002,
      dot: 0x0003,
      axpy: 0x0004,
      gemv: 0x1000,
      gemm: 0x2000,
      pusht: 0x8000,
      sendt: 0x8001
    }
  end

  @doc """
  Gets opcode from keyword.
  """
  def opcode(keyword) do
    instruction = Keyword.get(keyword, :instruction, 0)
    reserved = Keyword.get(keyword, :reserved, 0)

    <<opcode::size(64)>> = <<
      reserved::48,
      instruction::16
    >>

    opcode
  end

  @doc """
  Gets the mask of opcode.
  """
  def mask(key) do
    opcode(Keyword.put([], key, 0xFFFFFFFFFFFFFFFF))
  end

  @doc """
  Gets the mask hex string of opcode.
  """
  def hex_mask(key) do
    mask(key)
    |> Integer.to_string(16)
    |> then(&Kernel.<>("0x", &1))
  end

  @doc """
  Gets the shift value of opcode.
  """
  def shift(key) do
    shift_s(mask(key), 0)
  end

  defp shift_s(0, s), do: s

  defp shift_s(mask, s) do
    case band(mask, 1) do
      1 -> s
      0 -> shift_s(mask >>> 1, s + 1)
    end
  end

  @doc """
  Gets the name of the macro of the mask or shift from key.
  """
  def name_macro(key, :mask) do
    name_macro_s(key, "MASK")
  end

  def name_macro(key, :shift) do
    name_macro_s(key, "SHIFT")
  end

  def name_macro(key, :inst) do
    name_macro_s(key, "INST")
  end

  defp name_macro_s(key, prefix) do
    key
    |> Atom.to_string()
    |> String.upcase()
    |> then(&Enum.join([prefix, &1], "_"))
  end

  @doc """
  Gets c code of the masks and the shifts.
  """
  def c_code_masks_shifts() do
    key_opcode()
    |> Enum.map(fn key ->
      """
      #define #{name_macro(key, :mask)} #{hex_mask(key)}
      #define #{name_macro(key, :shift)} #{shift(key)}
      """
    end)
    |> Enum.join("\n")
  end

  @doc """
  Gets c code of `enum instruction`.
  """
  def c_enum_instruction() do
    instruction_code()
    |> Enum.sort(fn {_, c1}, {_, c2} -> c1 < c2 end)
    |> Enum.map(fn {inst, code} ->
      "    #{name_macro(inst, :inst)} = 0x#{Integer.to_string(code, 16)},"
    end)
    |> Enum.join("\n")
    |> then(
      &"""
      enum instruction {
      #{&1}
      };
      """
    )
  end

  @doc false
  def c_code(:mask), do: c_code_masks_shifts()
  def c_code(:inst), do: c_enum_instruction()

  @doc """
  Gets c header code.
  """
  def c_header_code(macro) do
    """
    #ifndef #{macro}
    #define #{macro}

    #{c_code(:mask)}

    #{c_code(:inst)}

    enum stack_type {
      type_undefined,
      type_tensor,
      type_error,
    };

    enum type_binary {
      tb_s = 0,
      tb_u = 1,
      tb_f = 2,
      tb_bf = 3,
      tb_c = 6,
    };

    enum bit_type_binary {
      btb_8 = 0,
      btb_16 = 1,
      btb_32 = 2,
      btb_64 = 3,
      btb_c16 = 0,
      btb_c32 = 1,
      btb_c64 = 2,
      btb_c128 = 3,
    };
    #endif // #{macro}
    """
  end

  @spec put_c_header(
          binary
          | maybe_improper_list(
              binary | maybe_improper_list(any, binary | []) | char,
              binary | []
            ),
          any
        ) :: :ok
  @doc """
  Puts c header code.
  """
  def put_c_header(file \\ @opcode_header, macro \\ @opcode_macro) do
    File.write!(file, c_header_code(macro))
  end

  @doc """
  Executes code for the engine.

  The code should be a list of tuples of an opcode and an operand.
  """
  @spec execute(list({opcode(), operand()})) :: :ok | {:error, String.t()}
  def execute(code) do
    PelemayBackend.NIF.execute_engine(code)
  end

  @doc """
  Gets Regex of instructions.
  """
  def regex_inst() do
    instruction_code()
    |> Map.keys()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.map(&"(^ *(?<#{&1}>#{&1}.*)$)")
    |> Enum.join("|")
    |> Regex.compile!()
  end

  @doc """
  Assemble code into
  """
  @spec assemble(String.t(), Code.binding()) :: list({opcode(), operand()})
  def assemble(code, binding \\ []) do
    r = regex_inst()

    String.split(code, "\n")
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Regex.named_captures(r, &1))
    |> Stream.reject(&is_nil/1)
    |> Stream.map(&Map.reject(&1, fn {_k, v} -> v == "" end))
    |> Enum.reduce({[], binding}, fn map, {acc, binding} ->
      inst = Map.keys(map) |> hd()

      {args, binding} =
        Map.get(map, inst, "")
        |> String.replace_prefix(inst, "")
        |> Code.eval_string(binding)

      inst = String.to_atom(inst)
      {acc ++ [{inst, args, binding}], binding}
    end)
    |> elem(0)
    |> Stream.map(fn {inst, args, binding} ->
      encode(inst, args, binding)
    end)
    |> Enum.to_list()
  end

  defp encode(:scal, args, _binding) do
    Logger.debug("scal #{inspect(args)}")

    code = {
      Map.get(instruction_code(), :scal),
      {
        Nx.type(args),
        Nx.to_binary(args),
        1
      }
    }

    Logger.debug("generated code of scal: #{inspect(code)}")

    code
  end

  defp encode(:sscal, _args, _binding) do
    Logger.debug("sscal")
  end

  defp encode(:copy, args, _binding) do
    Logger.debug("copy")

    code = {
      Map.get(instruction_code(), :copy),
      args
    }

    Logger.debug("generated code of copy: #{inspect(code)}")

    code
  end

  defp encode(:dot, _args, _binding) do
    Logger.debug("dot")
  end

  defp encode(:axpy, _args, _binding) do
    Logger.debug("axpy")
  end

  defp encode(:gemv, _args, _binding) do
    Logger.debug("gemv")
  end

  defp encode(:gemm, _args, _binding) do
    Logger.debug("gemm")
  end

  defp encode(:pusht, args, _binding) do
    Logger.debug("pusht #{inspect(args)}")

    code = {
      Map.get(instruction_code(), :pusht),
      {
        Nx.size(args),
        Nx.shape(args),
        Nx.type(args),
        Nx.to_binary(args)
      }
    }

    Logger.debug("generated code of pusht: #{inspect(code)}")

    code
  end

  defp encode(:sendt, args, _binding) do
    Logger.debug("sendt #{inspect(args)}")

    code = {
      Map.get(instruction_code(), :sendt),
      args
    }

    Logger.debug("generated code of sendt: #{inspect(code)}")

    code
  end
end
