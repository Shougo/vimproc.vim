scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

source spec/base.vim

Context Fopen.run()
  It equals to system() result
    Should vimproc#system('ls') == system('ls')
  End

  It calls vimproc#system_bg() implicitly
    Should vimproc#system('ls&') == ''
    Should vimproc#system('ls&') == vimproc#system_bg('ls')
  End

  It returns always empty string
    Should vimproc#system_bg('ls') == ''
    Should vimproc#system_bg(['ls']) == ''
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
