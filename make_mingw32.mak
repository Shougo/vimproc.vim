# for MinGW.

TARGET=autoload/vimproc_win32.dll
SRC=autoload/proc_w32.c
CFLAGS=-O2 -Wall -shared -m32
LDFLAGS+=-lwsock32
CC=mingw32-gcc

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
