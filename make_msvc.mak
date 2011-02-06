
all: autoload/proc.dll

autoload/proc.dll: autoload/proc_w32.c autoload/vimstack.c
	cl /wd4996 /LD /Feautoload/proc.dll autoload/proc_w32.c ws2_32.lib advapi32.lib shell32.lib

clean:
	cmd /C "del autoload\proc.dll autoload\proc.lib autoload\proc.exp" /F /Q

