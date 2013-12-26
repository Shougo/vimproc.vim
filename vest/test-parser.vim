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
    Should vimproc#parser#split_args('echo "\`test\`"')
          \ == ['echo', '`test`']
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

  It tests vimproc#parser#parse_statements()
    let statements =
          \ vimproc#parser#split_statements(
          \ '"/usr/bin/clang++" --std=c++0x `pkg-config'.
          \ ' --libs opencv` "/home/me/opencv/capture.cpp"'.
          \ ' -o "/home/me/opencv/capture" && "/home/me/opencv/capture"')
    Should statements == ['"/usr/bin/clang++" --std=c++0x `pkg-config'.
          \ ' --libs opencv` "/home/me/opencv/capture.cpp"'.
          \ ' -o "/home/me/opencv/capture" ', ' "/home/me/opencv/capture"'
          \ ]
  End

  It tests backquote
    ShouldEqual vimproc#parser#split_args('echo `echo "hoge" "piyo" "hogera"`'),
          \ [ 'echo', 'hoge', 'piyo', 'hogera' ]
    ShouldEqual vimproc#parser#split_args(
          \ 'echo "`curl -fs https://gist.github.com/raw/4349265/sudden-vim.py`"'),
          \ [ 'echo', system('curl -fs https://gist.github.com/raw/4349265/sudden-vim.py')]

  End

  It tests slash convertion
    " For Vital.DateTime
    ShouldEqual vimproc#parser#split_args(printf('reg query "%s" /v Bias',
          \ 'HKLM\System\CurrentControlSet\Control\TimeZoneInformation')),
          \ ['reg', 'query',
          \  'HKLM\System\CurrentControlSet\Control\TimeZoneInformation',
          \  '/v', 'Bias']
  End

  It tests {} convertion
    ShouldEqual vimproc#parser#parse_pipe(
          \ 'grep -inH --exclude-dir={foo} -R vim .')[0].args,
          \ ['grep', '-inH', '--exclude-dir=foo', '-R', 'vim', '.']
    ShouldEqual vimproc#parser#parse_pipe(
          \ 'grep -inH --exclude-dir={foo,bar,baz} -R vim .')[0].args,
          \ ['grep', '-inH', '--exclude-dir=foo', '--exclude-dir=bar',
          \  '--exclude-dir=baz', '-R', 'vim', '.']
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
