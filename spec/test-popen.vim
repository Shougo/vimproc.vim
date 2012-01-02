scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

source spec/base.vim

Context Popen.popen2()
  let cmd = 'ls'
  let sub = vimproc#popen2([cmd])
  let res = ''
  while !sub.stdout.eof
    let res .= sub.stdout.read()
  endwhile
  " Newline conversion.
  let res = substitute(res, '\r\n', '\n', 'g')

  It yet not closed
    Should sub.is_valid
  End

  let [cond, status] = sub.waitpid()

  It equals "exit"
    Should cond ==# 'exit'
  End

  It equals zero
    Should status == 0
  End

  It closed
    Should !sub.is_valid
  End

  It is same system()
    Should res == system(cmd)
  End

  unlet cmd
  unlet sub

  let cmd = ['ls', '-la']
  let sub = vimproc#popen2(cmd)
  let res = ''
  while !sub.stdout.eof
    let res .= sub.stdout.read()
  endwhile
  " Newline conversion.
  let res = substitute(res, '\r\n', '\n', 'g')

  It yet not closed
    Should sub.is_valid
  End

  let [cond, status] = sub.waitpid()

  It equals "exit"
    Should cond ==# 'exit'
  End

  It equals zero
    Should status == 0
  End

  It closed
    Should !sub.is_valid
  End

  It is same to system()
    Should res == system(join(cmd))
  End

  unlet cmd
  unlet sub
End

Context Popen.popen3()
  let cmd = 'ls'
  let sub = vimproc#popen3([cmd])
  let res = ''
  while !sub.stdout.eof
    let res .= sub.stdout.read()
  endwhile
  " Newline conversion.
  let res = substitute(res, '\r\n', '\n', 'g')

  It yet not closed
    Should sub.is_valid
  End

  let [cond, status] = sub.waitpid()

  It equals "exit"
    Should cond ==# 'exit'
  End

  It equals zero
    Should status == 0
  End

  It closed
    Should !sub.is_valid
  End

  It is same to system()
    Should res == system(cmd)
  End

  It returns empty string
    Should sub.stderr.read() == ""
  End

  unlet cmd
  unlet sub
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
