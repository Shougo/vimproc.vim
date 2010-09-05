" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



function! s:run()
  let cmd = 'ls'
  let sub = vimproc#popen3([cmd])

  let res = ""
  while !sub.stdout.eof
    let res .= sub.stdout.read()
  endwhile
  " Newline conversion.
  let res = substitute(res, '\r\n', '\n', 'g')

  let [cond, status] = sub.waitpid()
  Is cond, "exit", "cond ==# exit"
  Is status+0, 0, "status ==# 0"

  Is res, system(cmd), 'vimproc#popen3(' . string(cmd) . ') vs system(' . string(cmd) . ')'
  Is sub.stderr.read(), "", "sub.stderr.read() returns empty string"
endfunction

call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
