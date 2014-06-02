CFLAGS=-W -O2 -Wall -Wno-unused -Wno-unused-parameter -std=gnu99 -pedantic -shared

ifneq (,$(findstring 64,$(shell arch)))
	TARGET=autoload/vimproc_unix64.so
else
	TARGET=autoload/vimproc_unix32.so
endif

SRC=autoload/proc.c
CFLAGS+=-fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
