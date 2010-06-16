
let file = vimproc#fopen("./test1.vim", "O_RDONLY", 0)
let res = file.read()
call file.close()

new
call append(0, split(res, '\r\n\|\r\|\n'))

