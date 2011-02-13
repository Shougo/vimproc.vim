" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


function! s:run()
  let filename = "./test1.vim"
  let file = vimproc#fopen(filename, "O_RDONLY", 0)
  let res = file.read()

  Ok file.is_valid, "yet not closed"
  call file.close()
  Ok !file.is_valid, "closed"

  IsDeeply readfile(filename), split(res, '\r\n\|\r\|\n'), "readfile() vs vimproc#fopen().read()"

  let file = vimproc#fopen(filename, "O_RDONLY", 0)
  let res2 = []
  while !file.eof
    call add(res2, file.read_line())
  endwhile

  Ok file.is_valid, "yet not closed"
  call file.close()
  Ok !file.is_valid, "closed"

  IsDeeply readfile(filename), res2, "readfile() vs vimproc#fopen().read_line()"
endfunction

let s:org_cwd = getcwd()
lcd `=expand('<sfile>:p:h')`
try
    call s:run()
finally
    lcd `=s:org_cwd`
endtry
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
