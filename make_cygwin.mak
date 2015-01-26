CFLAGS+=-O2 -W -Wall -Wno-unused -Wno-unused-parameter -use=gnu99 -shared
TARGET=autoload/vimproc_cygwin.dll
SRC=autoload/proc.c
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
