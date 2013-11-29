" Resource leak checker version2(for process group).

let pwd = fnamemodify(expand('<sfile>'), ':p:h')

let process = vimproc#pgroup_open('python ' . pwd . '/fork.py')

call process.waitpid()

let process = vimproc#pgroup_open('python ' . pwd . '/fork.py')

call process.kill()

if executable('ps')
  echomsg string(split(system('ps aux | grep defunct'), '\n'))
endif
