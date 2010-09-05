" vim:foldmethod=marker:fen:sw=2:sts=2
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



function! s:run()
  Is vimproc#system('ls'), system("ls"), "vimproc#system() vs system()"
  Is vimproc#system('ls&'), '', "vimproc#system('ls&') calls vimproc#system_bg() implicitly"
  Is vimproc#system('ls&'), vimproc#system_bg('ls'), "vimproc#system() "
  Is vimproc#system_bg('ls'), '', 'vimproc#system_bg() returns always empty string'
  Is vimproc#system_bg('ls&'), '', 'vimproc#system_bg() returns always empty string'
  Is vimproc#system_bg(['ls']), '', 'vimproc#system_bg() returns always empty string'
endfunction

call s:run()
Done


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
