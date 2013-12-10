/* 2006-06-23
 * vim:set sw=4 sts=4 et:
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdarg.h>
#include <errno.h>

/*
 * Argument and Result are Stack. Each value is EOV terminated String.
 * Number can be stored as String.
 * The result which is not terminated by EOV is error message, except NULL
 * is no value.
 */

/* End Of Value */
#define VP_EOV '\xFF'
#define VP_EOV_STR "\xFF"

#define VP_NUM_BUFSIZE 64
#define VP_NUMFMT_BUFSIZE 16
#define VP_INITIAL_BUFSIZE 512
#define VP_ERRMSG_SIZE 512

#if defined(_WIN64)
# define VP_RETURN_IF_FAIL(expr) \
    { const char *vp_err = (expr); if (vp_err != NULL) return vp_err; }
#else
# define VP_RETURN_IF_FAIL(expr)     \
    do {                            \
        const char *vp_err = expr;  \
        if (vp_err) return vp_err;  \
    } while (0)
#endif

/* buf:var|EOV|var|EOV|top:free buffer|buf+size */
typedef struct vp_stack_t {
    size_t size; /* stack size */
    char *buf;   /* stack bufffer */
    char *top;   /* stack top */
} vp_stack_t;

/* use for initialize */
#define VP_STACK_NULL {0, NULL, NULL}

static const char CHR2XD[0x100] = {
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x00 - 0x0F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x10 - 0x1F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x20 - 0x2F */
     0,  1,  2,  3,  4,  5,  6,  7,  8,  9, -1, -1, -1, -1, -1, -1, /* 0x30 - 0x3F */
    -1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x40 - 0x4F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x50 - 0x5F */
    -1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x60 - 0x6F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x70 - 0x7F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x80 - 0x8F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0x90 - 0x9F */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0xA0 - 0xAF */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0xB0 - 0xBF */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0xC0 - 0xCF */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0xD0 - 0xDF */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0xE0 - 0xEF */
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, /* 0xF0 - 0xFF */
};

static const char *XD2CHR =
    "00" "01" "02" "03" "04" "05" "06" "07" "08" "09" "0A" "0B" "0C" "0D" "0E" "0F"
    "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "1A" "1B" "1C" "1D" "1E" "1F"
    "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "2A" "2B" "2C" "2D" "2E" "2F"
    "30" "31" "32" "33" "34" "35" "36" "37" "38" "39" "3A" "3B" "3C" "3D" "3E" "3F"
    "40" "41" "42" "43" "44" "45" "46" "47" "48" "49" "4A" "4B" "4C" "4D" "4E" "4F"
    "50" "51" "52" "53" "54" "55" "56" "57" "58" "59" "5A" "5B" "5C" "5D" "5E" "5F"
    "60" "61" "62" "63" "64" "65" "66" "67" "68" "69" "6A" "6B" "6C" "6D" "6E" "6F"
    "70" "71" "72" "73" "74" "75" "76" "77" "78" "79" "7A" "7B" "7C" "7D" "7E" "7F"
    "80" "81" "82" "83" "84" "85" "86" "87" "88" "89" "8A" "8B" "8C" "8D" "8E" "8F"
    "90" "91" "92" "93" "94" "95" "96" "97" "98" "99" "9A" "9B" "9C" "9D" "9E" "9F"
    "A0" "A1" "A2" "A3" "A4" "A5" "A6" "A7" "A8" "A9" "AA" "AB" "AC" "AD" "AE" "AF"
    "B0" "B1" "B2" "B3" "B4" "B5" "B6" "B7" "B8" "B9" "BA" "BB" "BC" "BD" "BE" "BF"
    "C0" "C1" "C2" "C3" "C4" "C5" "C6" "C7" "C8" "C9" "CA" "CB" "CC" "CD" "CE" "CF"
    "D0" "D1" "D2" "D3" "D4" "D5" "D6" "D7" "D8" "D9" "DA" "DB" "DC" "DD" "DE" "DF"
    "E0" "E1" "E2" "E3" "E4" "E5" "E6" "E7" "E8" "E9" "EA" "EB" "EC" "ED" "EE" "EF"
    "F0" "F1" "F2" "F3" "F4" "F5" "F6" "F7" "F8" "F9" "FA" "FB" "FC" "FD" "FE" "FF";

static void vp_stack_free(vp_stack_t *stack);
static const char *vp_stack_from_args(vp_stack_t *stack, char *args);
static const char *vp_stack_return(vp_stack_t *stack);
static const char *vp_stack_return_error(vp_stack_t *stack, const char *fmt, ...);
static const char *vp_stack_reserve(vp_stack_t *stack, size_t needsize);
static const char *vp_stack_pop_num(vp_stack_t *stack, const char *fmt, void *ptr);
static const char *vp_stack_pop_str(vp_stack_t *stack, char **str);
static const char *vp_stack_pop_bin(vp_stack_t *stack, char **buf, size_t *size);
static const char *vp_stack_push_num(vp_stack_t *stack, const char *fmt, ...);
static const char *vp_stack_push_str(vp_stack_t *stack, const char *str);
static const char *vp_stack_push_bin(vp_stack_t *stack, const char *buf, size_t size);

static void
vp_stack_free(vp_stack_t *stack)
{
    if (stack->buf != NULL) {
        free((void *)stack->buf);
        stack->size = 0;
        stack->buf = NULL;
        stack->top = NULL;
    }
}

/* make readonly stack from arguments */
static const char *
vp_stack_from_args(vp_stack_t *stack, char *args)
{
    if (args == NULL || args[0] == '\0') {
        stack->size = 0;
        stack->buf = NULL;
        stack->top = NULL;
    } else {
        stack->size = strlen(args); /* don't count end of NUL. */
        stack->buf = args;
        stack->top = stack->buf + stack->size;
        if (stack->top[-1] != VP_EOV)
            return "vp_stack_from_buf: no EOV";
    }
    return NULL;
}

/* clear stack top and return stack buffer */
static const char *
vp_stack_return(vp_stack_t *stack)
{
    /* make sure *top == '\0' because the previous value can not be
     * cleared when no value is assigned. */
    if (stack->top != NULL)
        stack->top[0] = '\0';
    stack->top = stack->buf;
    return stack->buf;
}

/* push error message and return */
static const char *
vp_stack_return_error(vp_stack_t *stack, const char *fmt, ...)
{
    va_list ap;
    size_t needsize;

    needsize = (stack->top - stack->buf) + VP_ERRMSG_SIZE;
    if (vp_stack_reserve(stack, needsize) != NULL)
        return fmt;

    va_start(ap, fmt);
    stack->top += vsnprintf(stack->top,
            stack->size - (stack->top - stack->buf), fmt, ap);
    va_end(ap);
    return vp_stack_return(stack);
}

/* ensure stack buffer is needsize or more bytes */
static const char *
vp_stack_reserve(vp_stack_t *stack, size_t needsize)
{
    if (needsize > stack->size) {
        size_t newsize;
        char *newbuf;

        newsize = (stack->size == 0) ? VP_INITIAL_BUFSIZE : (stack->size * 2);
        while (needsize > newsize) {
            newsize *= 2;
            if (newsize <= stack->size) /* paranoid check */
                return "vp_stack_reserve: too big";
        }
        if ((newbuf = (char *)realloc(stack->buf, newsize)) == NULL)
            return "vp_stack_reserve: NOMEM";
        stack->top = newbuf + (stack->top - stack->buf);
        stack->buf = newbuf;
        stack->size = newsize;
    }
    return NULL;
}

static const char *
vp_stack_pop_num(vp_stack_t *stack, const char *fmt, void *ptr)
{
    char fmtbuf[VP_NUMFMT_BUFSIZE];
    int n;
    char *top;

    if (stack->buf == stack->top)
        return "vp_stack_pop_num: stack over flow";

    top = stack->top - 1;
    while (top != stack->buf && top[-1] != VP_EOV)
        --top;

    strcpy(fmtbuf, fmt);
    strcat(fmtbuf, "%n");

    if (sscanf(top, fmtbuf, ptr, &n) != 1 || top[n] != VP_EOV)
        return "vp_stack_pop_num: sscanf error";

    stack->top = top;
    return NULL;
}

/* str will be invalid after vp_stack_push_*() */
static const char *
vp_stack_pop_str(vp_stack_t *stack, char **str)
{
    char *top;

    if (stack->buf == stack->top)
        return "vp_stack_pop_str: stack over flow";

    top = stack->top - 1;
    while (top != stack->buf && top[-1] != VP_EOV)
        --top;

    *str = top;
    stack->top[-1] = '\0';
    stack->top = top;
    return NULL;
}

/* bin is hexdump */
static const char *
vp_stack_pop_bin(vp_stack_t *stack, char **buf, size_t *size)
{
    char *p;
    char ub, lb;
    size_t gain = 0;

    VP_RETURN_IF_FAIL(vp_stack_pop_str(stack, buf));
    p = *buf;
    while (*p) {
        ub = CHR2XD[(unsigned char)*(p++)];
        lb = CHR2XD[(unsigned char)*(p++)];
        if (ub < 0 || lb < 0)
            return "vp_stack_pop_bin: sscanf error";
        (*buf)[gain++] = (char)((ub << 4) | (lb << 0));
    }
    *size = gain;
    return NULL;
}

static const char *
vp_stack_push_num(vp_stack_t *stack, const char *fmt, ...)
{
    va_list ap;
    char buf[VP_NUM_BUFSIZE];

    va_start(ap, fmt);
    if (vsprintf(buf, fmt, ap) < 0) {
        va_end(ap);
        return "vp_stack_push_num: vsprintf error";
    }
    va_end(ap);
    return vp_stack_push_str(stack, buf);
}

static const char *
vp_stack_push_str(vp_stack_t *stack, const char *str)
{
    size_t needsize;

    needsize = (stack->top - stack->buf) + strlen(str) + sizeof(VP_EOV_STR);
    VP_RETURN_IF_FAIL(vp_stack_reserve(stack, needsize));
    stack->top += sprintf(stack->top, "%s%c", str, VP_EOV);
    return NULL;
}

static const char *
vp_stack_push_bin(vp_stack_t *stack, const char *buf, size_t size)
{
    size_t needsize;
    size_t i;
    char *bs;

    needsize = (stack->top - stack->buf) + (size * 2) + sizeof(VP_EOV_STR);
    VP_RETURN_IF_FAIL(vp_stack_reserve(stack, needsize));
    for (i = 0; i < size; ++i) {
        bs = (char *)&XD2CHR[(unsigned char)(buf[i]) * 2];
        *(stack->top++) = bs[0];
        *(stack->top++) = bs[1];
    }
    *(stack->top++) = VP_EOV;
    return NULL;
}
