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
      :is_use_operand,
      :bit_type_binary,
      :type_binary,
      :used_registers,
      :reserved,
      :rd,
      :rs1,
      :rs2,
      :rs3,
      :rs4,
      :rs5,
      :rs6,
      :rs7
    ]
  end

  @doc """
  Gets map instruction to code.
  """
  def instruction_code() do
    %{
      scal: 0x00,
      sscal: 0x01,
      copy: 0x02,
      dot: 0x03,
      axpy: 0x04,
      gemv: 0x10,
      gemm: 0x20,
      lds: 0x80,
      ldb: 0x81,
      ldt2: 0x82,
      ldt3: 0x83,
      release: 0x84,
      alloc: 0x85,
      send: 0x86,
    }
  end

  @doc """
  Gets opcode from keyword.
  """
  def opcode(keyword) do
    instruction = Keyword.get(keyword, :instruction, 0)
    is_use_operand = Keyword.get(keyword, :is_use_operand, 0)
    bit_type_binary = Keyword.get(keyword, :bit_type_binary, 0)
    type_binary = Keyword.get(keyword, :type_binary, 0)
    used_registers = Keyword.get(keyword, :used_registers, 0)
    reserved = Keyword.get(keyword, :reserved, 0)
    rd = Keyword.get(keyword, :rd, 0)
    rs1 = Keyword.get(keyword, :rs1, 0)
    rs2 = Keyword.get(keyword, :rs2, 0)
    rs3 = Keyword.get(keyword, :rs3, 0)
    rs4 = Keyword.get(keyword, :rs4, 0)
    rs5 = Keyword.get(keyword, :rs5, 0)
    rs6 = Keyword.get(keyword, :rs6, 0)
    rs7 = Keyword.get(keyword, :rs7, 0)

    <<opcode::size(64)>> =
      <<
        rs7::5,
        rs6::5,
        rs5::5,
        rs4::5,
        rs3::5,
        rs2::5,
        rs1::5,
        rd::5,
        reserved::8,
        used_registers::3,
        type_binary::3,
        bit_type_binary::2,
        is_use_operand::1,
        instruction::7
      >>

    opcode
  end

  @doc """
  Gets the mask of opcode.
  """
  def mask(key) do
    opcode(Keyword.put([], key, 0xffffffffffffffff))
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
    |> then(&
    """
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

    enum register_type {
      type_undefined,
      type_s64,
      type_u64,
      type_f64,
      type_complex,
      type_binary,
      type_tuple2,
      type_tuple3,
      type_pid,
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

    #define NUM_REGISTERS 32

    #endif // #{macro}
    """
  end

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
    |> Enum.map(&"(^ *#{&1} +(?<#{&1}>.*)$)")
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
    |> Stream.reject(& &1 == "")
    |> Stream.map(&Regex.named_captures(r, &1))
    |> Stream.map(&Map.reject(&1, fn {_k, v} -> v == "" end))
    |> Enum.reduce({[], binding}, fn map, {acc, binding} ->
      inst = Map.keys(map) |> hd()
      {args, binding} = Map.get(map, inst, "") |> Code.eval_string(binding)
      inst = String.to_atom(inst)
      {acc ++ [{inst, args, binding}], binding}
    end)
    |> elem(0)
    |> Stream.map(fn {inst, args, binding} ->
      encode(inst, args, binding)
    end)
    |> Enum.to_list()
  end

  defp encode(:scal, _args, _binding) do
    Logger.debug("scal")
  end

  defp encode(:sscal, _args, _binding) do
    Logger.debug("sscal")
  end

  defp encode(:copy, _args, _binding) do
    Logger.debug("scal")
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

  defp encode(:lds, _args, _binding) do
    Logger.debug("lds")
  end

  defp encode(:ldb, _args, _binding) do
    Logger.debug("ldb")
  end

  defp encode(:ldt2, _args, _binding) do
    Logger.debug("ldt2")
  end

  defp encode(:ldt3, _args, _binding) do
    Logger.debug("ldt3")
  end

  defp encode(:release, _args, _binding) do
    Logger.debug("release")
  end

  defp encode(:alloc, _args, _binding) do
    Logger.debug("alloc")
  end

  defp encode(:send, _args, _binding) do
    Logger.debug("send")
  end
end
