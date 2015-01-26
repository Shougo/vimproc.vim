# for *nix platform.

ifneq (,$(wildcard /lib*/ld-linux*.so.2))
	SUFFIX=linux$(if $(wildcard /lib*/ld-linux*64.so.2),64,32)
else
	SUFFIX=unix
endif
TARGET=autoload/vimproc_$(SUFFIX).so

SRC=autoload/proc.c
CFLAGS+=-W -O2 -Wall -Wno-unused -Wno-unused-parameter -std=gnu99 -pedantic -shared -fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
