# for Mac.

TARGET=autoload/vimproc_mac.so
SRC=autoload/proc.c
CFLAGS=-O2 -W -Wall -Wno-unused -bundle -fPIC -arch i386 -arch x86_64
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

.PHONY : clean
clean:
	-rm -f $(TARGET)
