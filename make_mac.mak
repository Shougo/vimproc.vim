# for Mac.

ifeq ($(shell which clang),)
LLVMCC=llvm-gcc
else
LLVMCC=clang
endif


ifneq ($(shell which $(LLVMCC)),)
CC=$(LLVMCC)
else
CC=gcc
endif

TARGET=autoload/vimproc_mac.so
SRC=autoload/proc.c
ARCHS=i386 x86_64
CFLAGS=-O2 -W -Wall -Wno-unused -Wno-unused-parameter -bundle -fPIC $(foreach ARCH,$(ARCHS),-arch $(ARCH))
LDFLAGS=

all: $(TARGET)

$(TARGET): $(SRC) autoload/vimstack.c
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

.PHONY : clean
clean:
	-rm -f $(TARGET)
