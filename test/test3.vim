
let proc = proc#import()

let sock = proc.socket_open("www.yahoo.com", 80)
call sock.write("GET / HTTP/1.0\r\n\r\n")
let res = ""
while !sock.eof
  let res .= sock.read()
endwhile
call sock.close()

new
call append(0, split(res, '\r\n\|\r\|\n'))

