all: autoload/vimproc_win64.dll

autoload/vimproc_win64.dll: autoload/proc_w32.c autoload/vimstack.c
	cl /wd4996 /O2 /LD /Feautoload/vimproc_win64.dll autoload/proc_w32.c ws2_32.lib advapi32.lib shell32.lib

clean:
	cmd /C "del autoload\vimproc_win64.dll autoload\vimproc_win64.lib autoload\vimproc_win64.exp" /F /Q

