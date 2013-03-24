" Tests for vesting.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Fopen.run()
  let answer = input('Want to execute socket test? ')
  if answer !~? 'y\%[es]'
    finish
  endif

  It checks host exists
    ShouldEqual vimproc#host_exists('www.yahoo.com'), 1
    ShouldEqual vimproc#host_exists('https://www.yahoo.com'), 1
    ShouldEqual vimproc#host_exists('https://www.yahoo.com/hoge/piyo'), 1
  End

  let sock = vimproc#socket_open('www.yahoo.com', 80)
  call sock.write("GET / HTTP/1.0\r\n\r\n", 100)
  let res = ''
  let out = sock.read(-1, 100)
  while !sock.eof && out != ''
    let out = sock.read(-1, 100)
    let res .= out
  endwhile

  It yet not closed
    Should sock.is_valid
  End

  call sock.close()

  It closed
    Should !sock.is_valid
  End

  echo res
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
