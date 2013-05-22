" Tests for vesting.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Function.run()
  It tests kill
    let errmsg_save = v:exception
    ShouldEqual vimproc#kill(9999, 0), 1
    ShouldNotEqual errmsg_save, vimproc#get_last_errmsg()
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
