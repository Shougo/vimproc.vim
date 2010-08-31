" vim:foldmethod=marker:fen:
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
