#ifndef PELEMAY_ENGINE_OPCODE_H
#define PELEMAY_ENGINE_OPCODE_H

#define MASK_INSTRUCTION 0x7F
#define SHIFT_INSTRUCTION 0

#define MASK_IS_USE_OPERAND 0x80
#define SHIFT_IS_USE_OPERAND 7

#define MASK_BIT_TYPE_BINARY 0x300
#define SHIFT_BIT_TYPE_BINARY 8

#define MASK_TYPE_BINARY 0x1C00
#define SHIFT_TYPE_BINARY 10

#define MASK_USED_REGISTERS 0xE000
#define SHIFT_USED_REGISTERS 13

#define MASK_RESERVED 0xFF0000
#define SHIFT_RESERVED 16

#define MASK_RD 0x1F000000
#define SHIFT_RD 24

#define MASK_RS1 0x3E0000000
#define SHIFT_RS1 29

#define MASK_RS2 0x7C00000000
#define SHIFT_RS2 34

#define MASK_RS3 0xF8000000000
#define SHIFT_RS3 39

#define MASK_RS4 0x1F00000000000
#define SHIFT_RS4 44

#define MASK_RS5 0x3E000000000000
#define SHIFT_RS5 49

#define MASK_RS6 0x7C0000000000000
#define SHIFT_RS6 54

#define MASK_RS7 0xF800000000000000
#define SHIFT_RS7 59


enum instruction {
    INST_SCAL = 0x0,
    INST_SSCAL = 0x1,
    INST_COPY = 0x2,
    INST_DOT = 0x3,
    INST_AXPY = 0x4,
    INST_GEMV = 0x10,
    INST_GEMM = 0x20,
    INST_LDS = 0x80,
    INST_LDB = 0x81,
    INST_LDT2 = 0x82,
    INST_LDT3 = 0x83,
    INST_RELEASE = 0x84,
    INST_ALLOC = 0x85,
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

#endif // PELEMAY_ENGINE_OPCODE_H
