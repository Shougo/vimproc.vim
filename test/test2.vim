
let proc = proc#import()

let sub = proc.popen2(["/bin/ls"])
let res = ""
while !sub.stdout.eof
  let res .= sub.stdout.read()
endwhile
let [cond, status] = proc.api.vp_waitpid(sub.pid)

new
call append(0, split(res, '\r\n\|\r\|\n') + [string([cond, status])])

