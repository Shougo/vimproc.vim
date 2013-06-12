" Tests for vesting.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Fopen.run()
  if !executable('ls')
    echo 'ls command is not installed.'
    finish
  endif

  It equals to system() result
    Should vimproc#system('ls') == system('ls')

    Should vimproc#system(['ls']) == system('ls')

    if vimproc#util#is_windows()
      Should vimproc#cmd#system(['ls']) == system('ls')
      Should vimproc#cmd#system('ls') == system('ls')
      Should vimproc#cmd#system('echo', '"Foo"') == system('echo ""Foo""')
    endif

    Should vimproc#system_passwd('echo -n "test"')
          \ == system('echo -n "test"')
    Should vimproc#system_passwd(['echo', '-n', 'test'])
          \ == system('echo -n "test"')
  End

  It calls vimproc#system_bg() implicitly
    Should vimproc#system('ls&') == ''
    Should vimproc#system('ls&') == vimproc#system_bg('ls')
  End

  It returns always empty string
    Should vimproc#system_bg('ls') == ''
    Should vimproc#system_bg(['ls']) == ''
  End

  It matches password string
    Should 'Enter passphrase for key ''.ssh/id_rsa'''
          \ =~# g:vimproc_password_pattern
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
