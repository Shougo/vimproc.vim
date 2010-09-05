" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


function! s:chdir(dir)
  let org_cwd = getcwd()
  lcd `=a:dir`

  let f = simpletap#finalizer()
  let f['1back_to_cwd'] = {'args': [org_cwd]}
  function f['1back_to_cwd'].fn(org_cwd)
    lcd `=a:org_cwd`
  endfunction
endfunction

function! s:run()
  let filename = "./test1.vim"
  let file = vimproc#fopen(filename, "O_RDONLY", 0)
  let res = file.read()

  Ok file.is_valid, "yet not closed"
  call file.close()
  Ok !file.is_valid, "closed"

  IsDeeply readfile(filename), split(res, '\r\n\|\r\|\n'), "readfile() vs vimproc#fopen()"
endfunction

call s:chdir(expand('<sfile>:p:h'))
call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
