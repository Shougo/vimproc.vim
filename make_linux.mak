
ifeq ($(PLATFORM),darwin)
    # for Mac.
    CFLAGS=-W -Wall -Wno-unused -ansi -pedantic -bundle
else
    CFLAGS=-W -Wall -Wno-unused -ansi -pedantic -shared
endif

# for FreeBSD's make
#.if defined(OS) && ${OS} == "Windows_NT"
#TARGET=autoload/proc.dll
#SRC=autoload/proc_w32.c
#CFLAGS+=-DWIN32
#LDFLAGS+=-lws2_32
#.else
#TARGET=autoload/proc.so
#SRC=autoload/proc.c
#CFLAGS+=-fPIC
#LDFLAGS+=-lutil
#.endif

ifeq ($(PLATFORM),win32)
    TARGET=autoload/proc.dll
    SRC=autoload/proc_w32.c
    CFLAGS+=-DWIN32
    LDFLAGS+=-lws2_32
else
    TARGET=autoload/proc.so
    SRC=autoload/proc.c
    CFLAGS+=-fPIC
    LDFLAGS+=-lutil
endif

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

