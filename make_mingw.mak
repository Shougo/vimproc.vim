# for MinGW.

TARGET=autoload/proc.dll
SRC=autoload/proc_w32.c
CFLAGS=-O2 -Wall -shared
LDFLAGS+=-lwsock32

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
