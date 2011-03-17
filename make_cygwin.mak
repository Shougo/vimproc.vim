CFLAGS=-O2 -W -Wall -Wno-unused -use=gnu99 -shared
TARGET=autoload/proc_cygwin.dll
SRC=autoload/proc.c
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
