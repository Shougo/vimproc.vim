all: autoload/vimproc_win32.dll

autoload/vimproc_win32.dll: autoload/proc_w32.c autoload/vimstack.c
	cl /wd4996 /LD /Feautoload/vimproc_win32.dll autoload/proc_w32.c ws2_32.lib advapi32.lib shell32.lib

clean:
	cmd /C "del autoload\vimproc_win32.dll autoload\vimproc_win32.lib autoload\vimproc_win32.exp" /F /Q

