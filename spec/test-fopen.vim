scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

source spec/base.vim

Context Fopen.run()
  let filename = 'spec/test-fopen.vim'
  let file = vimproc#fopen(filename, 'O_RDONLY', 0)
  let res = file.read()

  It yet not closed
    Should file.is_valid
  End

  call file.close()

  It closed
    Should !file.is_valid
  End

  It is same to readfile()
    Should readfile(filename) == split(res, '\r\n\|\r\|\n')
  End

  let file = vimproc#fopen(filename, 'O_RDONLY', 0)
  let res2 = []
  while !file.eof
    call add(res2, file.read_line())
  endwhile

  It yet not closed
    Should file.is_valid
  End

  call file.close()

  It closed
    Should !file.is_valid
  End

  It is same to readfile()
    Should readfile(filename) == res2
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
