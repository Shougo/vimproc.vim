# for Mac.

TARGET=autoload/proc.so
SRC=autoload/proc.c
CFLAGS=-W -Wall -Wno-unused -ansi -pedantic -bundle -fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

