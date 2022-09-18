#ifndef PELEMAY_ENGINE_OPCODE_H
#define PELEMAY_ENGINE_OPCODE_H

#define MASK_INSTRUCTION 0xFFFF
#define SHIFT_INSTRUCTION 0

#define MASK_RESERVED 0xFFFFFFFFFFFF0000
#define SHIFT_RESERVED 16


enum instruction {
    INST_SCAL = 0x0,
    INST_SSCAL = 0x1,
    INST_COPY = 0x2,
    INST_DOT = 0x3,
    INST_AXPY = 0x4,
    INST_GEMV = 0x1000,
    INST_GEMM = 0x2000,
};


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
#endif // PELEMAY_ENGINE_OPCODE_H
