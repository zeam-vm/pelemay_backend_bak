#include <stdbool.h>
#include <stdint.h>
#include <erl_nif.h>

#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 1
#endif

#include <cblas.h>

#define BITMASK_NEXT   0x1
#define BITMASK_OPCODE 0x000000ff
#define BITMASK_RD     0x0000ff00
#define BITMASK_RS1    0x00ff0000
#define BITMASK_RS2    0xff000000
#define BITMASK_RESERVED 0xffffffff00000000
#define NUM_REGISTERS 256

typedef struct code {
    ErlNifUInt64 opcode;
    ERL_NIF_TERM operand[3];
} code_t;

bool getcode(ErlNifEnv *env, ERL_NIF_TERM list, code_t **code, unsigned *length, ERL_NIF_TERM *exception)
{
    if(__builtin_expect(!enif_get_list_length(env, list, length), false)) {
        *exception = enif_make_badarg(env);
        return false;
    }
    *code = enif_alloc(*length * sizeof(code_t));
    if(__builtin_expect(*code == NULL, false)) {
        *exception = enif_raise_exception(env, enif_make_string(env, "Fail to alloc memory", ERL_NIF_LATIN1));
        return false;
    }
    ERL_NIF_TERM tail = list;
    code_t *code_p = *code;
    while(*length > 0) {
        list = tail;
        ERL_NIF_TERM head;
        if(__builtin_expect(!enif_get_list_cell(env, list, &head, &tail), false)) {
            enif_free(*code);
            *exception = enif_raise_exception(env, enif_make_string(env, "Should be list", ERL_NIF_LATIN1));
            return false;
        }
        int arity;
        const ERL_NIF_TERM *array;
        if(__builtin_expect(!enif_get_tuple(env, head, &arity, &array) || arity != 4, false)) {
            enif_free(*code);
            *exception = enif_raise_exception(env, enif_make_string(env, "Should be list of tuple4", ERL_NIF_LATIN1));
            return false;
        }
        if(__builtin_expect(!enif_get_uint64(env, array[0], &code_p->opcode), false)) {
            enif_free(*code);
            *exception = enif_raise_exception(env, enif_make_string(env, "Invalid opcode", ERL_NIF_LATIN1));
            return false;
        }
        code_p->operand[0] = array[1];
        code_p->operand[1] = array[2];
        code_p->operand[2] = array[3];
        code_p++;
        (*length)--;
    }
    return true;
}

bool execute(ErlNifEnv *env, code_t *code, unsigned code_length, ERL_NIF_TERM *reason)
{
    ERL_NIF_TERM registers[NUM_REGISTERS];
    for(code_t *code_p = code; code_length > 0; code_length--, code_p++) {
        if(__builtin_expect(code_p->opcode & BITMASK_RESERVED, 0)) {
            *reason = enif_make_string(env, "reserved bit of opcode should be zero", ERL_NIF_LATIN1);
            return false;
        }
        
    }
    return true;
}

static ERL_NIF_TERM execute_engine(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    if(__builtin_expect(argc != 1, false)) {
        return enif_make_badarg(env);
    }
    ERL_NIF_TERM tail = argv[0];
    unsigned length;
    code_t *code;
    ERL_NIF_TERM exception;

    if(__builtin_expect(!getcode(env, argv[0], &code, &length, &exception), false)) {
        return exception;
    }
    code_t *code_p = code;
    unsigned code_length = length;
    ERL_NIF_TERM reason;
    if(execute(env, code, code_length, &reason)) {
        enif_free(code);
        return enif_make_atom(env, "ok");
    } else {
        enif_free(code);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), reason);
    }
}

static ERL_NIF_TERM scopy_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    if(__builtin_expect(argc != 3, false)) {
        return enif_make_badarg(env);
    }
    ErlNifUInt64 size;
    if(__builtin_expect(!enif_get_uint64(env, argv[0], &size), false)) {
        return enif_make_badarg(env);
    }
    ErlNifBinary bin1;
    if(__builtin_expect(!enif_inspect_binary(env, argv[2], &bin1), false)) {
        return enif_make_badarg(env);
    }
    ErlNifBinary bin2;
    if(__builtin_expect(!enif_alloc_binary(size * sizeof(float), &bin2), false)) {
        return enif_raise_exception(env, enif_make_string(env, "Fail to alloc memory", ERL_NIF_LATIN1));
    }
    cblas_scopy(size, (float *)bin1.data, 1, (float *)bin2.data, 1);
    return enif_make_binary(env, &bin2);
}

static ERL_NIF_TERM scopy_sscal_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    if(__builtin_expect(argc != 4, false)) {
        return enif_make_badarg(env);
    }
    double scholar;
    if(__builtin_expect(!enif_get_double(env, argv[0], &scholar), false)) {
        return enif_make_badarg(env);
    }
    ErlNifUInt64 size;
    if(__builtin_expect(!enif_get_uint64(env, argv[1], &size), false)) {
        return enif_make_badarg(env);
    }
    ErlNifBinary bin1;
    if(__builtin_expect(!enif_inspect_binary(env, argv[3], &bin1), false)) {
        return enif_make_badarg(env);
    }
    ErlNifBinary bin2;
    if(__builtin_expect(!enif_alloc_binary(size * sizeof(float), &bin2), false)) {
        return enif_raise_exception(env, enif_make_string(env, "Fail to alloc memory", ERL_NIF_LATIN1));
    }
    cblas_scopy(size, (float *)bin1.data, 1, (float *)bin2.data, 1);
    cblas_sscal(size, (float)scholar, (float *)bin2.data, 1);
    return enif_make_binary(env, &bin2);
}

static ErlNifFunc nif_funcs [] =
{
    {"execute_engine", 1, execute_engine},
    {"scopy_nif", 3, scopy_nif},
    {"scopy_sscal_nif", 4, scopy_sscal_nif},
};

ERL_NIF_INIT(Elixir.PelemayBackend.NIF, nif_funcs, NULL, NULL, NULL, NULL)