"=============================================================================
" FILE: parser.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Aug 2010
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

" Check vimshell."{{{
try
  let s:exists_vimshell_version = vimshell#version()
catch
  echoerr 'vimshell is not installed. Please install vimshell Ver.7.0 or above to use parser.'
  finish
endtry
if s:exists_vimshell_version < 700
  echoerr 'Please install vimshell Ver.7.0 or above.'
  finish
endif
"}}}

let s:is_win = has('win32') || has('win64')

function! vimproc#parser#system(cmdline, ...)"{{{
  let l:args = vimshell#parser#parse_statements(a:cmdline)
  for l:arg in l:args
    let l:arg.statement = vimshell#parser#parse_pipe(l:arg.statement)
  endfor
  
  if a:cmdline =~ '&\s*$'
    return vimproc#parser#system_bg(l:args)
  elseif a:0 == 0
    return vimproc#system(l:args)
  elseif a:0 == 1
    return vimproc#system(l:args, a:1)
  else
    return vimproc#system(l:args, a:1, a:2)
  endif
endfunction"}}}
function! vimproc#parser#system_bg(cmdline)"{{{
  let l:cmdline = (a:cmdline =~ '&\s*$')? a:cmdline[: match(a:cmdline, '&\s*$') - 1] : a:cmdline
  
  if s:is_win
    silent execute '!start' l:cmdline
    return ''
  else
    " Background execution.
    let l:args = vimshell#parser#split_args(l:cmdline)
    return vimproc#system_bg(l:args)
  endif
endfunction"}}}

function! vimproc#parser#popen2(cmdline)"{{{
  return vimproc#popen2(vimshell#parser#split_args(a:cmdline))
endfunction"}}}
function! vimproc#parser#plineopen2(args)"{{{
  return vimproc#popen2(vimshell#parser#parse_pipe(a:args))
endfunction"}}}

function! vimproc#parser#popen3(cmdline)"{{{
  return vimproc#popen3(vimshell#parser#split_args(a:cmdline))
endfunction"}}}
function! vimproc#parser#plineopen3(args)"{{{
  return vimproc#popen3(vimshell#parser#parse_pipe(a:args))
endfunction"}}}

function! vimproc#parser#ptyopen(cmdline)"{{{
  return vimproc#ptyopen(vimshell#parser#split_args(a:cmdline))
endfunction"}}}

function! vimproc#parser#pgroup_open(cmdline)"{{{
  let l:statements = vimshell#parser#parse_statements(a:cmdline)
  for l:statement in l:statements
    let l:statement.statement = vimshell#parser#parse_pipe(l:statement.statement)
  endfor
  return vimproc#pgroup_open(l:statements)
endfunction"}}}
