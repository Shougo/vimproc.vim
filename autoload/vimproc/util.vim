"=============================================================================
" FILE: util.vim
" Last Modified: 24 Feb 2011.
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

let s:is_win = has('win32') || has('win64')

" iconv() wrapper for safety.
function! vimproc#util#iconv(expr, from, to)"{{{
  if !has('iconv')
        \ || a:expr == '' || a:from == ''
        \ || a:to == '' || a:from ==# a:to
    return a:expr
  endif

  let l:result = iconv(a:expr, a:from, a:to)
  return l:result != '' ? l:result : a:expr
endfunction"}}}
function! vimproc#util#termencoding()"{{{
  return s:is_win && &termencoding == '' ?
        \ 'default' : &termencoding
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


" vim: foldmethod=marker
