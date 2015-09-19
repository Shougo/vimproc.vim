# for *BSD platform.

SUFFIX!=uname -sm | tr '[:upper:]' '[:lower:]' | sed -e 's/ /_/'

TARGET=autoload/vimproc_$(SUFFIX).so

SRC=autoload/proc.c
CFLAGS+=-W -O2 -Wall -Wno-unused -Wno-unused-parameter -std=gnu99 -pedantic -shared -fPIC
LDFLAGS+=-lutil

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
