" Tests for vesting.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Lexer.run()
  It tests escape
    Should vimproc#parser#split_args('echo "\""')
          \ == ['echo', '"']
  End

  It tests vimproc#shellescape()
    Should vimproc#shellescape('hoge') == "'hoge'"
    Should vimproc#shellescape('ho''ge') == "'ho''ge'"
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
