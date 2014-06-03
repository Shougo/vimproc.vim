# WINDOWS BUILD SETTINGS.
# For MSVC 11 you need to specify where the Win32.mak file is, e.g.:
#	SDK_INCLUDE_DIR=C:\Program Files\Microsoft SDKs\Windows\v7.1\Include
# for build win64 version:
# nmake -f make_msvc.mak CPU=AMD64

WINVER = 0x0500
APPVER = 5.0
TARGET = WINNT
_WIN32_IE = 0x0500
# CPU = AMD64

# Win32.mak requires that CPU be set appropriately.
# To cross-compile for Win64, set CPU=AMD64 or CPU=IA64.
!ifndef CPU
CPU = $(PROCESSOR_ARCHITECTURE)
! if ("$(CPU)" == "x86") || ("$(CPU)" == "X86")
CPU = i386
! endif
!endif

# Get all sorts of useful, standard macros from the Platform SDK.
!ifdef SDK_INCLUDE_DIR
!include $(SDK_INCLUDE_DIR)\Win32.mak
!else
!include <Win32.mak>
!endif

# CONTROL BUILD MODE

!IFDEF DEBUG
CFLAGS = $(CFLAGS) -D_DEBUG
!ELSE
CFLAGS = $(CFLAGS) -D_NDEBUG
!ENDIF

# VIMPROC SPECIFICS

!if "$(CPU)" == "AMD64"
VIMPROC=vimproc_win64
!else
VIMPROC=vimproc_win32
!endif

SRCS = autoload/proc_w32.c
OBJS = $(SRCS:.c=.obj)

DEFINES = -D_CRT_SECURE_NO_WARNINGS=1 -D_BIND_TO_CURRENT_VCLIBS_VERSION=1
CFLAGS = $(CFLAGS) $(DEFINES) /wd4100 /wd4127 /O2

# RULES

build: autoload\$(VIMPROC).dll

clean:
	-DEL /F /Q autoload\vimproc_win32.*
	-DEL /F /Q autoload\vimproc_win64.*
	-DEL /F /Q autoload\*.obj
	-DEL /F /Q autoload\*.pdb

autoload\$(VIMPROC).dll: $(OBJS)
	$(link) /NOLOGO $(ldebug) $(dlllflags) $(conlibsdll) $(LFLAGS) \
		/OUT:$@ $(OBJS) shell32.lib
	IF EXIST $@.manifest \
		mt -nologo -manifest $@.manifest -outputresource:$@;2

{autoload}.c{autoload}.obj::
	$(cc) $(cdebug) $(cflags) $(cvarsdll) $(CFLAGS) -Fdautoload\ \
		-Foautoload\ $<

autoload/proc_w32.obj: autoload/proc_w32.c autoload/vimstack.c

.PHONY: build clean
