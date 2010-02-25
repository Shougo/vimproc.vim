let sub = vimproc#popen2(["ls", '-la'])
let res = ""
while !sub.stdout.eof
  let res .= sub.stdout.read()
endwhile
let [cond, status] = sub.waitpid()

new
call append(0, split(res, '\r\n\|\r\|\n') + [string([cond, status])])

