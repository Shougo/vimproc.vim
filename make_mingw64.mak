# for MinGW.

TARGET=autoload/vimproc_win64.dll
SRC=autoload/proc_w32.c
CFLAGS=-O2 -Wall -shared -m64
LDFLAGS+=-lwsock32

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
