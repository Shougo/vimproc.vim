# for Mac.

TARGET=autoload/proc.so
SRC=autoload/proc.c
CFLAGS=-W -Wall -Wno-unused -bundle -fPIC -arch i386 -arch x86_64 -arch ppc -arch ppc64
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	gcc $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

.PHONY : clean
clean:
	-rm -f $(TARGET)
