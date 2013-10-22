# For SunOS
CC=gcc

ifeq ($(CC),suncc)
CFLAGS=-errwarn -xc99 -xO3 -native -KPIC -D__EXTENSIONS__
LDFLAGS=-G
else # gcc
CFLAGS=-W -Wall -Wno-unused -Wno-unused-parameter -std=c99 -O2 -fPIC -pedantic -D__EXTENSIONS__
LDFLAGS=-shared
endif

TARGET=autoload/vimproc_unix.so
SRC=autoload/proc.c autoload/ptytty.c
INC=autoload/vimstack.c

all: $(TARGET)

$(TARGET): $(SRC) $(INC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
