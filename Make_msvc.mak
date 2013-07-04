# WINDOWS BUILD SETTINGS.

WINVER = 0x0500
APPVER = 5.0
TARGET = WINNT
_WIN32_IE = 0x0500
!INCLUDE <Win32.Mak>

# CONTROL BUILD MODE

!IFDEF DEBUG
CFLAGS = $(CFLAGS) -D_DEBUG
!ELSE
CFLAGS = $(CFLAGS) -D_NDEBUG
!ENDIF

# VIMPROC SPECIFICS

!if "$(PROCESSOR_ARCHITECTURE)" == "AMD64"
VIMPROC=vimproc_win64
!else
VIMPROC=vimproc_win32
!endif

SRCS = autoload/proc_w32.c
OBJS = $(SRCS:.c=.obj)

DEFINES = -D_CRT_SECURE_NO_WARNINGS=1 -D_BIND_TO_CURRENT_VCLIBS_VERSION=1
CFLAGS = $(CFLAGS) $(DEFINES) /wd4100 /O2

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

.PHONY: build clean
