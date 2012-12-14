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
static vp_stack_t vp_stack_null = {0, NULL, NULL};

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
    unsigned num;

    VP_RETURN_IF_FAIL(vp_stack_pop_str(stack, buf));
    *size = 0;
    p = *buf;
    while (*p) {
        /* "%0.2x" is warned by gcc. */
        if (sscanf(p, "%2x", &num) != 1)
            return "vp_stack_pop_bin: sscanf error";
        (*buf)[*size] = (char)(num & 0xff);
        *size += 1;
        p += 2;
    }
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

    needsize = (stack->top - stack->buf) + (size * 2) + sizeof(VP_EOV_STR);
    VP_RETURN_IF_FAIL(vp_stack_reserve(stack, needsize));
    for (i = 0; i < size; ++i)
        /* is this slow? */
        stack->top += sprintf(stack->top, "%02X", buf[i] & 0xFF);
    *(stack->top++) = VP_EOV;
    return NULL;
}
