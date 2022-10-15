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

TARGET=lib/vimproc_mac.so
SRC=src/proc.c
ARCHS=x86_64 arm64e
CFLAGS+=-O2 -W -Wall -Wno-unused -Wno-unused-parameter -bundle -fPIC $(foreach ARCH,$(ARCHS),-arch $(ARCH))
LDFLAGS=

all: $(TARGET)

$(TARGET): $(SRC) src/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

.PHONY : clean
clean:
	-rm -f $(TARGET)
