" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



function! s:run()
  let cmd = ["ls", '-la']
  let sub = vimproc#popen2(cmd)
  let res = ""
  while !sub.stdout.eof
    let res .= sub.stdout.read()
  endwhile
  " Newline conversion.
  let res = substitute(res, '\r\n', '\n', 'g')

  Ok sub.is_valid, "yet not closed"
  let [cond, status] = sub.waitpid()
  Ok !sub.is_valid, "closed"
  Is cond, "exit", "cond ==# exit"
  Is status+0, 0, "status ==# 0"

  Is res, system(join(cmd)), 'vimproc#popen2(' . string(cmd) . ') vs system(' . string(join(cmd)) . ')'
endfunction

call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
