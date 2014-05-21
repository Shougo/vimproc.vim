ifeq ($(OS),Windows_NT)
    # Fail if this is a windows platform
    $(error Windows is not supported by this makefile, please use appropriate .mak file)
else
    # Grab the output of `uname -s` and switch to set the platform
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        PLATFORM = unix
    endif
    ifeq ($(UNAME_S),FreeBSD)
        PLATFORM = unix
    endif
    ifeq ($(UNAME_S),NetBSD)
        PLATFORM = unix
    endif
    ifeq ($(UNAME_S),OpenBSD)
        PLATFORM = unix
    endif
    ifeq ($(UNAME_S),Darwin)
        PLATFORM = mac
    endif
    ifeq ($(UNAME_S),SunOS)
        PLATFORM = sunos
    endif

    # Verify that the PLATFORM was detected
    ifndef PLATFORM
        $(error Autodetection of platform failed, please use appropriate .mak file)
    endif
endif

# Invoke the platform specific make files
all:
	$(MAKE) -f make_$(PLATFORM).mak

clean:
	$(MAKE) -f make_$(PLATFORM).mak clean

