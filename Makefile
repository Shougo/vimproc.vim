ifeq ($(OS),Windows_NT)
    # Need to figure out if Cygwin/Mingw is installed
    SYS := $(shell gcc -dumpmachine)
    ifeq ($(findstring cygwin, $(SYS)),cygwin)
      PLATFORM = cygwin
    endif
    ifeq ($(findstring mingw32, $(SYS)),mingw32)
      PLATFORM = mingw32
    endif
    ifeq ($(findstring mingw64, $(SYS)),mingw64)
      PLATFORM = mingw64
    endif
else
    # Grab the output of `uname -s` and switch to set the platform
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        PLATFORM = unix
    endif
    ifeq ($(UNAME_S),FreeBSD)
        PLATFORM = unix
    endif
    ifeq ($(UNAME_S),DragonFly)
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
endif

# Verify that the PLATFORM was detected
ifndef PLATFORM
    $(error Autodetection of platform failed, please use appropriate .mak file)
endif

# Invoke the platform specific make files
all:
	$(MAKE) -f make_$(PLATFORM).mak

clean:
	$(MAKE) -f make_$(PLATFORM).mak clean

