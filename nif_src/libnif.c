#include <stdbool.h>
#include <stdint.h>
#include <erl_nif.h>
#include <cblas.h>

#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 1
#endif

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
    {"scopy_nif", 3, scopy_nif},
    {"scopy_sscal_nif", 4, scopy_sscal_nif},
};

ERL_NIF_INIT(Elixir.PelemayBackend.NIF, nif_funcs, NULL, NULL, NULL, NULL)