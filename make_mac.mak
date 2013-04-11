# for Mac.

# clang or llvm-gcc
LLVMCC=llvm-gcc

ifneq ($(shell which $(LLVMCC)),)
CC=$(LLVMCC)
else
CC=gcc
endif

TARGET=autoload/vimproc_mac.so
SRC=autoload/proc.c
ARCHS=i386 x86_64
CFLAGS=-O2 -W -Wall -Wno-unused -bundle -fPIC $(foreach ARCH,$(ARCHS),-arch $(ARCH))
LDFLAGS=

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

.PHONY : clean
clean:
	-rm -f $(TARGET)
