
let proc = proc#import()

let sub = proc.popen2(["cat"])
let lis = range(256)
let hd = proc.list2hd(lis)
call proc.api.vp_pipe_write(sub.stdin.fd, hd, -1)
call sub.stdin.close()
let [res, eof] = ["", 0]
while !eof
  let [hd, eof] = proc.api.vp_pipe_read(sub.stdout.fd, -1, -1)
  let res .= hd
endwhile
call sub.stdout.close()
let [cond, status] = proc.api.vp_waitpid(sub.pid)

new
call append(0, proc.hd2list(res) + [string([cond, status])])

