CFLAGS=-W -Wall -Wno-unused -ansi -pedantic -shared

TARGET=autoload/proc.so
SRC=autoload/proc.c
CFLAGS+=-fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

