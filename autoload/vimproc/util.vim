"=============================================================================
" FILE: util.vim
" Last Modified: 26 Mar 2012.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:is_windows = has('win32') || has('win64')
let s:is_mac = !s:is_windows && (has('mac') || has('macunix')
      \ || has('gui_macvim') || system('uname') =~? '^darwin')

" iconv() wrapper for safety.
function! vimproc#util#iconv(expr, from, to)"{{{
  if !has('iconv')
        \ || a:expr == '' || a:from == ''
        \ || a:to == '' || a:from ==# a:to
    return a:expr
  endif

  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction"}}}
function! vimproc#util#termencoding()"{{{
  return 'char'
endfunction"}}}
function! vimproc#util#stdinencoding()"{{{
  return exists('g:stdinencoding') && type(g:stdinencoding) == type("") ?
        \ g:stdinencoding : vimproc#util#termencoding()
endfunction"}}}
function! vimproc#util#stdoutencoding()"{{{
  return exists('g:stdoutencoding') && type(g:stdoutencoding) == type("") ?
        \ g:stdoutencoding : vimproc#util#termencoding()
endfunction"}}}
function! vimproc#util#stderrencoding()"{{{
  return exists('g:stderrencoding') && type(g:stderrencoding) == type("") ?
        \ g:stderrencoding : vimproc#util#termencoding()
endfunction"}}}
function! vimproc#util#expand(path)"{{{
  return expand(escape(a:path,
        \ vimproc#util#is_windows() ? '*?"={}' : '*?"={}[]'), 1)
endfunction"}}}
function! vimproc#util#is_windows()"{{{
  return s:is_windows
endfunction"}}}
function! vimproc#util#is_mac()"{{{
  return s:is_mac
endfunction"}}}
function! vimproc#util#substitute_path_separator(path)"{{{
  return s:is_windows ? substitute(a:path, '\\', '/', 'g') : a:path
endfunction"}}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
" vim: foldmethod=marker
