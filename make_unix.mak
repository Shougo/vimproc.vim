CFLAGS=-W -O2 -Wall -Wno-unused -Wno-unused-parameter -std=gnu99 -pedantic -shared

TARGET=autoload/vimproc_unix.so
SRC=autoload/proc.c
CFLAGS+=-fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
