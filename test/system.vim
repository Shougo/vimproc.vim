let s:suite = themis#suite('system')
let s:assert = themis#helper('assert')

function! s:suite.system()
  if !executable('ls')
    echo 'ls command is not installed.'
    return
  endif

  call s:assert.equals(vimproc#system('ls'), system('ls'))
  call s:assert.equals(vimproc#system(['ls']), system('ls'))
  call s:assert.equals(vimproc#cmd#system('ls'), system('ls'))
  call s:assert.equals(vimproc#cmd#system(['ls']), system('ls'))
  call s:assert.equals(
        \ vimproc#cmd#system(['echo', '"Foo"']),
        \ system('echo "\"Foo\""'))
  call s:assert.equals(
        \ vimproc#system_passwd('echo -n "test"'),
        \ system('echo -n "test"'))
  call s:assert.equals(
        \ vimproc#system_passwd(['echo', '-n', 'test']),
        \ system('echo -n "test"'))
  call s:assert.equals(vimproc#system('ls&'), '')
  call s:assert.equals(vimproc#system('ls&'),
        \ vimproc#system_bg('ls'))
  call s:assert.equals(vimproc#system_bg('ls'), '')
  call s:assert.equals(vimproc#system_bg(['ls']), '')
  call s:assert.match(
        \ 'Enter passphrase for key ''.ssh/id_rsa''',
        \ g:vimproc_password_pattern)
endfunction

" vim:foldmethod=marker:fen:
