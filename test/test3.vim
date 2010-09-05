" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



function! s:run()
  let sock = vimproc#socket_open("www.yahoo.com", 80)
  call sock.write("GET / HTTP/1.0\r\n\r\n")
  let res = ""
  while !sock.eof
    let res .= sock.read()
  endwhile

  Ok sock.is_valid, "yet not closed"
  call sock.close()
  Ok !sock.is_valid, "closed"

  Diag res
endfunction

call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
