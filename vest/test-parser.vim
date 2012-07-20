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

  It tests quote exeption
    let is_catched = 0
    try
      call vimproc#parser#split_args('echo "\"')
    catch /^Exception: Quote/
      let is_catched = 1
    endtry
    Should is_catched
  End

  It tests join to next line exeption
    let is_catched = 0
    try
      call vimproc#parser#split_args('echo \')
    catch /^Exception: Join to next line/
      let is_catched = 1
    endtry
    Should is_catched
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
