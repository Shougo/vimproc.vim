
all: autoload/proc.dll

autoload/proc.dll: autoload/proc_w32.c autoload/vimstack.c
	gcc -Wall -shared autoload/proc_w32.c autoload/vimstack.c -lwsock32 -o autoload/proc.dll

clean:
	rm -f $(TARGET)
