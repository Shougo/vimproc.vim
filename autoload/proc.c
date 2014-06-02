/* vim:set sw=4 sts=4 et: */
/**
 * FILE:   proc.c
 * AUTHOR: Yukihiro Nakadaira <http://yukihiro.nakadaira.googlepages.com/#vimproc> (original)
 *         Nico Raffo <nicoraffo@gmail.com> (modified)
 */

#define _XOPEN_SOURCE 600

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <stddef.h>
#include <dlfcn.h>
#include <ctype.h>
#include <dirent.h>

#if !defined __APPLE__
# include <sys/types.h>
# include <sys/ioctl.h>
#endif
#include <signal.h>

#include <fcntl.h>

/* for poll() */
#if defined __APPLE__
#include "fakepoll.h"
#else
#include <poll.h>
#endif

/* for forkpty() / login_tty() */
#if (defined __linux__ || defined __CYGWIN__) && !defined __ANDROID__
# include <pty.h>
# include <utmp.h>
#elif defined __APPLE__ || defined __NetBSD__
# include <util.h>
#elif defined __sun__ || defined __ANDROID__
# include <termios.h>
int openpty(int *, int *, char *, struct termios *, struct winsize *);
int forkpty(int *, char *, struct termios *, struct winsize *);
#else
# include <termios.h>
# include <libutil.h>
#endif

/* for ioctl() */
#ifdef __APPLE__ 
# include <sys/ioctl.h>
#endif

/* for tc* and ioctl */
#include <sys/types.h>
#include <termios.h>
#ifndef TIOCGWINSZ
# include <sys/ioctl.h> /* 4.3+BSD requires this too */
#endif

/* for waitpid() */
#include <sys/types.h>
#include <sys/wait.h>
#if defined __NetBSD__
#define WIFCONTINUED(x) (_WSTATUS(x) == _WSTOPPED && WSTOPSIG(x) == 0x13)
#elif defined __ANDROID__
#define WIFCONTINUED(x) (WIFSTOPPED(x) && WSTOPSIG(x) == 0x13)
#endif

/* for socket */
#if defined __FreeBSD__
#define __BSD_VISIBLE 1
#include <arpa/inet.h>
#endif
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#include "vimstack.c"

const int debug = 0;

/* API */
const char *vp_dlopen(char *args);      /* [handle] (path) */
const char *vp_dlclose(char *args);     /* [] (handle) */
const char *vp_dlversion(char *args);   /* [version] () */

const char *vp_file_open(char *args);   /* [fd] (path, flags, mode) */
const char *vp_file_close(char *args);  /* [] (fd) */
const char *vp_file_read(char *args);   /* [hd, eof] (fd, nr, timeout) */
const char *vp_file_write(char *args);  /* [nleft] (fd, hd, timeout) */

const char *vp_pipe_open(char *args);   /* [pid, [fd] * npipe]
                                           (npipe, hstdin, hstdout, hstderr, argc, [argv]) */
const char *vp_pipe_close(char *args);  /* [] (fd) */
const char *vp_pipe_read(char *args);   /* [hd, eof] (fd, nr, timeout) */
const char *vp_pipe_write(char *args);  /* [nleft] (fd, hd, timeout) */

const char *vp_pty_open(char *args);
/* [pid, stdin, stdout, stderr]
   (npipe, width, height,hstdin, hstdout, hstderr, argc, [argv]) */
const char *vp_pty_close(char *args);   /* [] (fd) */
const char *vp_pty_read(char *args);    /* [hd, eof] (fd, nr, timeout) */
const char *vp_pty_write(char *args);   /* [nleft] (fd, hd, timeout) */
const char *vp_pty_get_winsize(char *args); /* [width, height] (fd) */
const char *vp_pty_set_winsize(char *args); /* [] (fd, width, height) */

const char *vp_kill(char *args);        /* [] (pid, sig) */
const char *vp_waitpid(char *args);     /* [cond, status] (pid) */

const char *vp_socket_open(char *args); /* [socket] (host, port) */
const char *vp_socket_close(char *args);/* [] (socket) */
const char *vp_socket_read(char *args); /* [hd, eof] (socket, nr, timeout) */
const char *vp_socket_write(char *args);/* [nleft] (socket, hd, timeout) */

const char *vp_host_exists(char *args); /* [int] (host) */

const char *vp_decode(char *args);      /* [decoded_str] (encode_str) */

const char *vp_get_signals(char *args); /* [signals] () */
/* --- */

#define VP_READ_BUFSIZE 2048

static vp_stack_t _result = VP_STACK_NULL;

static void
close_fds(int fds[3][2])
{
    int i;

    for (i = 0; i < 6; ++i) {
        int fd = fds[i / 2][i % 2];

        if (fd > 0)
            close(fd);
    }
}

const char *
vp_dlopen(char *args)
{
    vp_stack_t stack;
    char *path;
    void *handle;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &path));

    handle = dlopen(path, RTLD_LAZY);
    if (handle == NULL)
        return dlerror();
    vp_stack_push_num(&_result, "%p", handle);
    return vp_stack_return(&_result);
}

const char *
vp_dlclose(char *args)
{
    vp_stack_t stack;
    void *handle;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%p", &handle));

    /* On FreeBSD6, to call dlclose() twice with same pointer causes SIGSEGV */
    if (dlclose(handle) == -1)
        return dlerror();
    vp_stack_free(&_result);
    return NULL;
}

const char *
vp_dlversion(char *args)
{
    vp_stack_push_num(&_result, "%2d%02d", 8, 0);
    return vp_stack_return(&_result);
}

const char *
vp_file_open(char *args)
{
    vp_stack_t stack;
    char *path;
    char *flags;
    int mode;  /* used when flags have O_CREAT */
    int f = 0;
    int fd;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &path));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &flags));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &mode));

#ifdef O_RDONLY
    if (strstr(flags, "O_RDONLY"))      f |= O_RDONLY;
#endif
#ifdef O_WRONLY
    if (strstr(flags, "O_WRONLY"))      f |= O_WRONLY;
#endif
#ifdef O_RDRW
    if (strstr(flags, "O_RDRW"))        f |= O_RDWR;
#endif
#ifdef O_NONBLOCK
    if (strstr(flags, "O_NONBLOCK"))    f |= O_NONBLOCK;
#endif
#ifdef O_APPEND
    if (strstr(flags, "O_APPEND"))      f |= O_APPEND;
#endif
#ifdef O_CREAT
    if (strstr(flags, "O_CREAT"))       f |= O_CREAT;
#endif
#ifdef O_EXCL
    if (strstr(flags, "O_EXCL"))        f |= O_EXCL;
#endif
#ifdef O_TRUNC
    if (strstr(flags, "O_TRUNC"))       f |= O_TRUNC;
#endif
#ifdef O_SHLOCK
    if (strstr(flags, "O_SHLOCK"))      f |= O_SHLOCK;
#endif
#ifdef O_EXLOCK
    if (strstr(flags, "O_EXLOCK"))      f |= O_EXLOCK;
#endif
#ifdef O_DIRECT
    if (strstr(flags, "O_DIRECT"))      f |= O_DIRECT;
#endif
#ifdef O_FSYNC
    if (strstr(flags, "O_FSYNC"))       f |= O_FSYNC;
#endif
#ifdef O_NOFOLLOW
    if (strstr(flags, "O_NOFOLLOW"))    f |= O_NOFOLLOW;
#endif
#ifdef O_TEMPORARY
    if (strstr(flags, "O_TEMPORARY"))   f |= O_TEMPORARY;
#endif
#ifdef O_RANDOM
    if (strstr(flags, "O_RANDOM"))      f |= O_RANDOM;
#endif
#ifdef O_SEQUENTIAL
    if (strstr(flags, "O_SEQUENTIAL"))  f |= O_SEQUENTIAL;
#endif
#ifdef O_BINARY
    if (strstr(flags, "O_BINARY"))      f |= O_BINARY;
#endif
#ifdef O_TEXT
    if (strstr(flags, "O_TEXT"))        f |= O_TEXT;
#endif
#ifdef O_INHERIT
    if (strstr(flags, "O_INHERIT"))     f |= O_INHERIT;
#endif
#ifdef _O_SHORT_LIVED
    if (strstr(flags, "O_SHORT_LIVED")) f |= _O_SHORT_LIVED;
#endif

    fd = open(path, f, mode);
    if (fd == -1)
        return vp_stack_return_error(&_result, "open() error: %s",
                strerror(errno));
    vp_stack_push_num(&_result, "%d", fd);
    return vp_stack_return(&_result);
}

const char *
vp_file_close(char *args)
{
    vp_stack_t stack;
    int fd;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &fd));

    if (close(fd) == -1)
        return vp_stack_return_error(&_result, "close() error: %s",
                strerror(errno));
    return NULL;
}

const char *
vp_file_read(char *args)
{
    vp_stack_t stack;
    int fd;
    int nr;
    int timeout;
    int n;
    char buf[VP_READ_BUFSIZE];
    struct pollfd pfd = {0, POLLIN, 0};

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &fd));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &nr));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &timeout));

    pfd.fd = fd;
    vp_stack_push_str(&_result, ""); /* initialize */
    while (nr != 0) {
        n = poll(&pfd, 1, timeout);
        if (n == -1) {
            /* eof or error */
            vp_stack_push_num(&_result, "%d", 1);
            return vp_stack_return(&_result);
        } else if (n == 0) {
            /* timeout */
            break;
        }
        if (pfd.revents & POLLIN) {
            if (nr > 0)
                n = read(fd, buf,
                        (VP_READ_BUFSIZE < nr) ? VP_READ_BUFSIZE : nr);
            else
                n = read(fd, buf, VP_READ_BUFSIZE);
            if (n == -1) {
                return vp_stack_return_error(&_result, "read() error: %s",
                        strerror(errno));
            } else if (n == 0) {
                /* eof */
                vp_stack_push_num(&_result, "%d", 1);
                return vp_stack_return(&_result);
            }
            /* decrease stack top for concatenate. */
            _result.top--;
            vp_stack_push_bin(&_result, buf, n);
            if (nr > 0)
                nr -= n;
            /* try read more bytes without waiting */
            timeout = 0;
            continue;
        } else if (pfd.revents & (POLLERR | POLLHUP)) {
            /* eof or error */
            vp_stack_push_num(&_result, "%d", 1);
            return vp_stack_return(&_result);
        } else if (pfd.revents & POLLNVAL) {
            return vp_stack_return_error(&_result, "poll() POLLNVAL: %d",
                    pfd.revents);
        }
        /* DO NOT REACH HERE */
        return vp_stack_return_error(&_result, "poll() unknown status: %d",
                pfd.revents);
    }
    vp_stack_push_num(&_result, "%d", 0);
    return vp_stack_return(&_result);
}

const char *
vp_file_write(char *args)
{
    vp_stack_t stack;
    int fd;
    char *buf;
    size_t size;
    int timeout;
    size_t nleft;
    int n;
    struct pollfd pfd = {0, POLLOUT, 0};

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &fd));
    VP_RETURN_IF_FAIL(vp_stack_pop_bin(&stack, &buf, &size));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &timeout));

    pfd.fd = fd;
    nleft = 0;
    while (nleft < size) {
        n = poll(&pfd, 1, timeout);
        if (n == -1) {
            return vp_stack_return_error(&_result, "poll() error: %s",
                    strerror(errno));
        } else if (n == 0) {
            /* timeout */
            break;
        }
        if (pfd.revents & POLLOUT) {
            n = write(fd, buf + nleft, size - nleft);
            if (n == -1) {
                return vp_stack_return_error(&_result, "write() error: %s",
                        strerror(errno));
            }
            nleft += n;
            /* try write more bytes without waiting */
            timeout = 0;
            continue;
        } else if (pfd.revents & (POLLERR | POLLHUP)) {
            /* eof or error */
            break;
        } else if (pfd.revents & POLLNVAL) {
            return vp_stack_return_error(&_result, "poll() POLLNVAL: %d",
                    pfd.revents);
        }
        /* DO NOT REACH HERE */
        return vp_stack_return_error(&_result, "poll() unknown status: %s",
                pfd.revents);
    }
    vp_stack_push_num(&_result, "%zu", nleft);
    return vp_stack_return(&_result);
}

const char *
vp_pipe_open(char *args)
{
#define VP_GOTO_ERROR(_fmt) do { errfmt = (_fmt); goto error; } while(0)
    vp_stack_t stack;
    int npipe, hstdin, hstderr, hstdout;
    int argc;
    int fd[3][2] = {{0}};
    pid_t pid;
    int dummy;
    char *errfmt;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &npipe));
    if (npipe != 2 && npipe != 3)
        return vp_stack_return_error(&_result, "npipe range error. wrong pipes.");
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &hstdin));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &hstdout));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &hstderr));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &argc));

    if (hstdin > 0) {
        fd[0][0] = hstdin;
        fd[0][1] = 0;
    } else {
        if (pipe(fd[0]) < 0) {
            VP_GOTO_ERROR("pipe() error: %s");
        }
    }
    if (hstdout > 0) {
        fd[1][1] = hstdout;
        fd[1][0] = 0;
    } else {
        if (pipe(fd[1]) < 0) {
            VP_GOTO_ERROR("pipe() error: %s");
        }
    }
    if (hstderr > 0) {
        fd[2][1] = hstderr;
        fd[2][0] = 0;
    } else if (npipe == 3 && hstderr == 0) {
        if (pipe(fd[2]) < 0) {
            VP_GOTO_ERROR("pipe() error: %s");
        }
    }

    pid = fork();
    if (pid < 0) {
        VP_GOTO_ERROR("fork() error: %s");
    } else if (pid == 0) {
        /* child */
        char **argv;
        int i;

        /* Set process group. */
        setpgid(0, 0);

        if (fd[0][1] > 0) {
            close(fd[0][1]);
        }
        if (fd[1][0] > 0) {
            close(fd[1][0]);
        }
        if (fd[2][0] > 0) {
            close(fd[2][0]);
        }
        if (fd[0][0] > 0) {
            if (dup2(fd[0][0], STDIN_FILENO) != STDIN_FILENO) {
                goto child_error;
            }
            close(fd[0][0]);
        }
        if (fd[1][1] > 0) {
            if (dup2(fd[1][1], STDOUT_FILENO) != STDOUT_FILENO) {
                goto child_error;
            }
            close(fd[1][1]);
        }
        if (fd[2][1] > 0) {
            if (dup2(fd[2][1], STDERR_FILENO) != STDERR_FILENO) {
                goto child_error;
            }
            close(fd[2][1]);
        } else if (npipe == 2) {
            if (dup2(STDOUT_FILENO, STDERR_FILENO) != STDERR_FILENO) {
                goto child_error;
            }
        }

        {
#ifndef TIOCNOTTY
            setsid();
#else
            /* Ignore tty. */
            char name[L_ctermid];
            if (ctermid(name)[0] != '\0') {
                int tfd;
                if ((tfd = open(name, O_RDONLY)) != -1) {
                    ioctl(tfd, TIOCNOTTY, NULL);
                    close(tfd);
                }
            }
#endif
        }

        argv = malloc(sizeof(char *) * (argc+1));
        if (argv == NULL) {
            goto child_error;
        }
        for (i = 0; i < argc; ++i) {
            if (vp_stack_pop_str(&stack, &(argv[i]))) {
                free(argv);
                goto child_error;
            }
        }
        argv[argc] = NULL;

        execv(argv[0], argv);
        /* error */
        goto child_error;
    } else {
        /* parent */
        if (fd[0][0] > 0) {
            close(fd[0][0]);
        }
        if (fd[1][1] > 0) {
            close(fd[1][1]);
        }
        if (fd[2][1] > 0) {
            close(fd[2][1]);
        }

        vp_stack_push_num(&_result, "%d", pid);
        vp_stack_push_num(&_result, "%d", fd[0][1]);
        vp_stack_push_num(&_result, "%d", fd[1][0]);
        if (npipe == 3) {
            vp_stack_push_num(&_result, "%d", fd[2][0]);
        }
        return vp_stack_return(&_result);
    }
    /* DO NOT REACH HERE */
    return NULL;

    /* error */
error:
    close_fds(fd);
    return vp_stack_return_error(&_result, errfmt, strerror(errno));

child_error:
    dummy = write(STDOUT_FILENO, strerror(errno), strlen(strerror(errno)));
    _exit(EXIT_FAILURE);
#undef VP_GOTO_ERROR
}

const char *
vp_pipe_close(char *args)
{
    return vp_file_close(args);
}

const char *
vp_pipe_read(char *args)
{
    return vp_file_read(args);
}

const char *
vp_pipe_write(char *args)
{
    return vp_file_write(args);
}

const char *
vp_pty_open(char *args)
{
#define VP_GOTO_ERROR(_fmt) do { errfmt = (_fmt); goto error; } while(0)
    vp_stack_t stack;
    int argc;
    int fd[3][2] = {{0}};
    pid_t pid;
    struct winsize ws = {0, 0, 0, 0};
    int dummy;
    int hstdin, hstderr, hstdout;
    int fdm;
    int npipe;
    char *errfmt;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &npipe));
    if (npipe != 2 && npipe != 3)
        return vp_stack_return_error(&_result, "npipe range error. wrong pipes.");
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%hu", &(ws.ws_col)));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%hu", &(ws.ws_row)));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &hstdin));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &hstdout));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &hstderr));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &argc));

    /* Set pipe */
    if (hstdin > 0) {
        fd[0][0] = hstdin;
        fd[0][1] = 0;
    }
    if (hstdout > 1) {
        fd[1][1] = hstdout;
        fd[1][0] = 0;
    } else if (hstdout == 1) {
        if (pipe(fd[1]) < 0) {
            VP_GOTO_ERROR("pipe() error: %s");
        }
    }
    if (hstderr > 1) {
        fd[2][1] = hstderr;
        fd[2][0] = 0;
    } else if (npipe == 3) {
        if (hstderr == 1){
            if (pipe(fd[2]) < 0) {
                VP_GOTO_ERROR("pipe() error: %s");
            }
        } else if (hstderr == 0) {
            if (openpty(&fd[2][0], &fd[2][1], NULL, NULL, &ws) < 0) {
                VP_GOTO_ERROR("openpty() error: %s");
            }
        }
    }

    pid = forkpty(&fdm, NULL, NULL, &ws);
    if (pid < 0) {
        VP_GOTO_ERROR("fork() error: %s");
    } else if (pid == 0) {
        /* child */
        char **argv;
        int i;

        /* Close pipe */
        if (fd[1][0] > 0) {
            close(fd[1][0]);
        }
        if (fd[2][0] > 0) {
            close(fd[2][0]);
        }

        if (fd[0][0] > 0) {
            if (dup2(fd[0][0], STDIN_FILENO) != STDIN_FILENO) {
                goto child_error;
            }
            close(fd[0][0]);
        }

        if (fd[1][1] > 0) {
            if (dup2(fd[1][1], STDOUT_FILENO) != STDOUT_FILENO) {
                goto child_error;
            }
            close(fd[1][1]);
        }

        if (fd[2][1] > 0) {
            if (dup2(fd[2][1], STDERR_FILENO) != STDERR_FILENO) {
                goto child_error;
            }
            close(fd[2][1]);
        }

        argv = malloc(sizeof(char *) * (argc+1));
        if (argv == NULL) {
            goto child_error;
        }
        for (i = 0; i < argc; ++i) {
            if (vp_stack_pop_str(&stack, &(argv[i]))) {
                free(argv);
                goto child_error;
            }
        }
        argv[argc] = NULL;

        execv(argv[0], argv);
        /* error */
        goto child_error;
    } else {
        /* parent */
        if (fd[1][1] > 0) {
            close(fd[1][1]);
        }
        if (fd[2][1] > 0) {
            close(fd[2][1]);
        }

        if (hstdin == 0) {
            fd[0][1] = fdm;
        }
        if (hstdout == 0) {
            fd[1][0] = hstdin == 0 ? dup(fdm) : fdm;
        }

        vp_stack_push_num(&_result, "%d", pid);
        vp_stack_push_num(&_result, "%d", fd[0][1]);
        vp_stack_push_num(&_result, "%d", fd[1][0]);
        if (npipe == 3) {
            vp_stack_push_num(&_result, "%d", fd[2][0]);
        }
        return vp_stack_return(&_result);
    }
    /* DO NOT REACH HERE */
    return NULL;

    /* error */
error:
    close_fds(fd);
    return vp_stack_return_error(&_result, errfmt, strerror(errno));

child_error:
    dummy = write(STDOUT_FILENO, strerror(errno), strlen(strerror(errno)));
    _exit(EXIT_FAILURE);
#undef VP_GOTO_ERROR
}

const char *
vp_pty_close(char *args)
{
    return vp_file_close(args);
}

const char *
vp_pty_read(char *args)
{
    return vp_file_read(args);
}

const char *
vp_pty_write(char *args)
{
    return vp_file_write(args);
}

const char *
vp_pty_get_winsize(char *args)
{
    vp_stack_t stack;
    int fd;
    struct winsize ws = {0, 0, 0, 0};

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &fd));

    if (ioctl(fd, TIOCGWINSZ, &ws) < 0)
        return vp_stack_return_error(&_result, "ioctl() error: %s",
                strerror(errno));
    vp_stack_push_num(&_result, "%hu", ws.ws_col);
    vp_stack_push_num(&_result, "%hu", ws.ws_row);
    return vp_stack_return(&_result);
}
const char *
vp_pty_set_winsize(char *args)
{
    vp_stack_t stack;
    int fd;
    struct winsize ws = {0, 0, 0, 0};

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &fd));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%hu", &(ws.ws_col)));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%hu", &(ws.ws_row)));

    if (ioctl(fd, TIOCSWINSZ, &ws) < 0)
        return vp_stack_return_error(&_result, "ioctl() error: %s",
                strerror(errno));
    return NULL;
}

const char *
vp_kill(char *args)
{
    vp_stack_t stack;
    pid_t pid, pgid;
    int sig;
    int ret;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &pid));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &sig));

    ret = kill(pid, sig);
    if (ret < 0)
        return vp_stack_return_error(&_result, "kill() error: %s",
                strerror(errno));

    if (sig != 0) {
        /* Kill by the process group. */
        pgid = getpgid(pid);
        if (pgid > 0) {
            kill(-pgid, sig);
        }
    }

    vp_stack_push_num(&_result, "%d", ret);
    return vp_stack_return(&_result);
}

const char *
vp_waitpid(char *args)
{
    vp_stack_t stack;
    pid_t pid, pgid;
    pid_t n;
    int status;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_num(&stack, "%d", &pid));

    n = waitpid(pid, &status, WNOHANG | WUNTRACED);
    if (n == -1)
        return vp_stack_return_error(&_result, "waitpid() error: %s",
                strerror(errno));
    if (n == 0 || WIFCONTINUED(status)) {
        vp_stack_push_str(&_result, "run");
        vp_stack_push_num(&_result, "%d", 0);
    } else if (WIFEXITED(status)) {
        /* Kill by the process group. */
        pgid = getpgid(pid);
        if (pgid > 0) {
            kill(-pgid, 15);
        }

        vp_stack_push_str(&_result, "exit");
        vp_stack_push_num(&_result, "%d", WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        vp_stack_push_str(&_result, "signal");
        vp_stack_push_num(&_result, "%d", WTERMSIG(status));
    } else if (WIFSTOPPED(status)) {
        vp_stack_push_str(&_result, "stop");
        vp_stack_push_num(&_result, "%d", WSTOPSIG(status));
    } else {
        return vp_stack_return_error(&_result,
                "waitpid() unknown status: status=%d", status);
    }

    return vp_stack_return(&_result);
}

/*
 * This is based on socket.diff.gz written by Yasuhiro Matsumoto.
 * see: http://marc.theaimsgroup.com/?l=vim-dev&m=105289857008664&w=2
 */
const char *
vp_socket_open(char *args)
{
    vp_stack_t stack;
    char *host;
    char *port;
    char *p;
    int n;
    unsigned short nport;
    int sock;
    struct sockaddr_in sockaddr;
    struct hostent *hostent;
    struct servent *servent;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &host));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &port));

    n = strtol(port, &p, 10);
    if (p == port + strlen(port)) {
        nport = htons(n);
    } else {
        servent = getservbyname(port, NULL);
        if (servent == NULL)
            return vp_stack_return_error(&_result, "getservbyname() error: %s",
                    port);
        nport = servent->s_port;
    }

    sock = socket(PF_INET, SOCK_STREAM, 0);
    hostent = gethostbyname(host);
    sockaddr.sin_family = AF_INET;
    sockaddr.sin_port = nport;
    sockaddr.sin_addr = *((struct in_addr*)*hostent->h_addr_list);

    if (connect(sock, (struct sockaddr*)&sockaddr, sizeof(struct sockaddr_in))
            == -1)
        return vp_stack_return_error(&_result, "connect() error: %s",
                strerror(errno));

    vp_stack_push_num(&_result, "%d", sock);
    return vp_stack_return(&_result);
}

const char *
vp_socket_close(char *args)
{
    return vp_file_close(args);
}

const char *
vp_socket_read(char *args)
{
    return vp_file_read(args);
}

const char *
vp_socket_write(char *args)
{
    return vp_file_write(args);
}

/*
 * Added by Richard Emberson
 * Check to see if a host exists.
 */
const char *
vp_host_exists(char *args)
{
    vp_stack_t stack;
    char *host;
    struct hostent *hostent;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &host));

    hostent = gethostbyname(host);
    if (hostent) {
        vp_stack_push_num(&_result, "%d", 1);
    } else {
        vp_stack_push_num(&_result, "%d", 0);
    }

    return vp_stack_return(&_result);
}

const char *
vp_readdir(char *args)
{
    vp_stack_t stack;
    char *dirname;
    char buf[1024];

    DIR *dir;
    struct dirent *dp;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &dirname));

    if ((dir=opendir(dirname)) == NULL) {
        return vp_stack_return_error(&_result, "opendir() error: %s",
                strerror(errno));
    }

    if (strcmp(dirname, "/") == 0) {
        dirname[0] = '\0';
    }

    for (dp = readdir(dir); dp != NULL; dp = readdir(dir)) {
        if (strcmp(dp->d_name, ".") && strcmp(dp->d_name, "..")) {
            snprintf(buf, sizeof(buf), "%s/%s", dirname, dp->d_name);
            vp_stack_push_str(&_result, buf);
        }
    }
    closedir(dir);

    return vp_stack_return(&_result);
}

const char *
vp_decode(char *args)
{
    vp_stack_t stack;
    size_t len;
    char *str;
    char *p, *q;

    VP_RETURN_IF_FAIL(vp_stack_from_args(&stack, args));
    VP_RETURN_IF_FAIL(vp_stack_pop_str(&stack, &str));

    len = strlen(str);
    if (len % 2 != 0) {
        return "vp_decode: invalid data length";
    }

    VP_RETURN_IF_FAIL(vp_stack_reserve(&_result,
            (_result.top - _result.buf) + (len / 2) + sizeof(VP_EOV_STR)));

    for (p = str, q = _result.top; p < str + len; ) {
        char hb, lb;

        hb = CHR2XD[(int)*(p++)];
        lb = CHR2XD[(int)*(p++)];
        if (hb >= 0 && lb >= 0) {
            *(q++) = (char)((hb << 4) | lb);
        }
    }
    *(q++) = VP_EOV;
    *q = '\0';
    _result.top = q;

    return vp_stack_return(&_result);
}

const char *
vp_get_signals(char *args)
{
#define VP_STACK_PUSH_SIGNAME(_signame) \
    vp_stack_push_num(&_result, #_signame ":%d", (_signame))
#define VP_STACK_PUSH_ALTSIGNAME(_signame, _altsig) \
    vp_stack_push_num(&_result, #_signame ":%d", (_altsig))

#ifdef SIGABRT
    VP_STACK_PUSH_SIGNAME(SIGABRT);
#else
#error "SIGABRT is undefined, contrary to ISO C standard."
#endif
#ifdef SIGFPE
    VP_STACK_PUSH_SIGNAME(SIGFPE);
#else
#error "SIGFPE is undefined, contrary to ISO C standard."
#endif
#ifdef SIGILL
    VP_STACK_PUSH_SIGNAME(SIGILL);
#else
#error "SIGILL is undefined, contrary to ISO C standard."
#endif
#ifdef SIGINT
    VP_STACK_PUSH_SIGNAME(SIGINT);
#else
#error "SIGINT is undefined, contrary to ISO C standard."
#endif
#ifdef SIGSEGV
    VP_STACK_PUSH_SIGNAME(SIGSEGV);
#else
#error "SIGSEGV is undefined, contrary to ISO C standard."
#endif
#ifdef SIGTERM
    VP_STACK_PUSH_SIGNAME(SIGTERM);
#else
#error "SIGTERM is undefined, contrary to ISO C standard."
#endif
#ifdef SIGALRM
    VP_STACK_PUSH_SIGNAME(SIGALRM);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGALRM, SIGTERM);
#endif
#ifdef SIGBUS
    VP_STACK_PUSH_SIGNAME(SIGBUS);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGBUS, SIGABRT);
#endif
#ifdef SIGCHLD
    VP_STACK_PUSH_SIGNAME(SIGCHLD);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGCHLD, 0);
#endif
#ifdef SIGCONT
    VP_STACK_PUSH_SIGNAME(SIGCONT);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGCONT, 0);
#endif
#ifdef SIGHUP
    VP_STACK_PUSH_SIGNAME(SIGHUP);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGHUP, SIGTERM);
#endif
#ifdef SIGKILL
    VP_STACK_PUSH_SIGNAME(SIGKILL);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGKILL, SIGTERM);
#endif
#ifdef SIGPIPE
    VP_STACK_PUSH_SIGNAME(SIGPIPE);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGPIPE, SIGTERM);
#endif
#ifdef SIGQUIT
    VP_STACK_PUSH_SIGNAME(SIGQUIT);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGQUIT, SIGTERM);
#endif
#ifdef SIGSTOP
    VP_STACK_PUSH_SIGNAME(SIGSTOP);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGSTOP, 0);
#endif
#ifdef SIGTSTP
    VP_STACK_PUSH_SIGNAME(SIGTSTP);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGTSTP, 0);
#endif
#ifdef SIGTTIN
    VP_STACK_PUSH_SIGNAME(SIGTTIN);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGTTIN, 0);
#endif
#ifdef SIGTTOU
    VP_STACK_PUSH_SIGNAME(SIGTTOU);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGTTOU, 0);
#endif
#ifdef SIGUSR1
    VP_STACK_PUSH_SIGNAME(SIGUSR1);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGUSR1, SIGTERM);
#endif
#ifdef SIGUSR2
    VP_STACK_PUSH_SIGNAME(SIGUSR2);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGUSR2, SIGTERM);
#endif
#ifdef SIGPOLL
    VP_STACK_PUSH_SIGNAME(SIGPOLL);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGPOLL, SIGTERM);
#endif
#ifdef SIGPROF
    VP_STACK_PUSH_SIGNAME(SIGPROF);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGPROF, SIGTERM);
#endif
#ifdef SIGSYS
    VP_STACK_PUSH_SIGNAME(SIGSYS);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGSYS, SIGABRT);
#endif
#ifdef SIGTRAP
    VP_STACK_PUSH_SIGNAME(SIGTRAP);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGTRAP, SIGABRT);
#endif
#ifdef SIGURG
    VP_STACK_PUSH_SIGNAME(SIGURG);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGURG, 0);
#endif
#ifdef SIGVTALRM
    VP_STACK_PUSH_SIGNAME(SIGVTALRM);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGVTALRM, SIGTERM);
#endif
#ifdef SIGXCPU
    VP_STACK_PUSH_SIGNAME(SIGXCPU);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGXCPU, SIGABRT);
#endif
#ifdef SIGXFSZ
    VP_STACK_PUSH_SIGNAME(SIGXFSZ);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGXFSZ, SIGABRT);
#endif
#ifdef SIGEMT
    VP_STACK_PUSH_SIGNAME(SIGEMT);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGEMT, SIGTERM);
#endif
#ifdef SIGWINCH
    VP_STACK_PUSH_SIGNAME(SIGWINCH);
#else
    VP_STACK_PUSH_ALTSIGNAME(SIGWINCH, 0);
#endif
    return vp_stack_return(&_result);

#undef VP_STACK_PUSH_SIGNAME
#undef VP_STACK_PUSH_ALTSIGNAME
}

/* 
 * vim:set sw=4 sts=4 et:
 */
