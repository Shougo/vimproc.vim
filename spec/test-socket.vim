scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

source spec/base.vim

Context Fopen.run()
  let sock = vimproc#socket_open('www.yahoo.com', 80)
  call sock.write("GET / HTTP/1.0\r\n\r\n")
  let res = ''
  while !sock.eof
    let res .= sock.read()
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
