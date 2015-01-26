# for Mac.

ifneq ($(shell which clang),)
CC=clang
else
ifneq ($(shell which llvm-gcc),)
CC=llvm-gcc
else
CC=gcc
endif
endif

TARGET=autoload/vimproc_mac.so
SRC=autoload/proc.c
ARCHS=
CFLAGS+=-O2 -W -Wall -Wno-unused -Wno-unused-parameter -bundle -fPIC $(foreach ARCH,$(ARCHS),-arch $(ARCH))
LDFLAGS=

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

.PHONY : clean
clean:
	-rm -f $(TARGET)
