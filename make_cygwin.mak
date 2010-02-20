CFLAGS=-W -Wall -Wno-unused -ansi -shared
TARGET=autoload/proc.dll
SRC=autoload/proc.c
CFLAGS+=-fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)
