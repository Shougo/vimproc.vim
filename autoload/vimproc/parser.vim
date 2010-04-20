"=============================================================================
" FILE: parser.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 20 Apr 2010
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

function! vimproc#parser#system(cmdline, ...)"{{{
  let l:args = s:split_args(a:cmdline)
  return (a:0 == 0) ? vimproc#system(l:args) : vimproc#system(l:args, join(a:000))
endfunction"}}}

function! vimproc#parser#popen2(cmdline)"{{{
  return vimproc#popen2(s:split_args(a:cmdline))
endfunction"}}}
function! vimproc#parser#plineopen2(args)"{{{
  let l:commands = []
  for l:cmdline in s:split_pipe(a:args)
    let l:command = {
          \ 'args' : s:split_args(l:cmdline), 
          \ 'fd' : {}
          \}
    call add(l:commands, l:command)
  endfor
  
  return vimproc#popen2(l:commands)
endfunction"}}}

function! vimproc#parser#popen3(cmdline)"{{{
  return vimproc#popen3(s:split_args(a:cmdline))
endfunction"}}}
function! vimproc#parser#plineopen3(args)"{{{
  let l:commands = []
  for l:cmdline in s:split_pipe(a:args)
    let l:command = {
          \ 'args' : s:split_args(l:cmdline), 
          \ 'fd' : {}
          \}
    call add(l:commands, l:command)
  endfor
  
  return vimproc#popen3(l:commands)
endfunction"}}}

function! vimproc#parser#ptyopen(cmdline)"{{{
  call vimproc#ptyopen(s:split_args(a:cmdline))
endfunction"}}}

" Parse helper.
function! s:split_args(script)"{{{
  let l:script = a:script
  let l:max = len(l:script)
  let l:args = []
  let l:arg = ''
  let l:i = 0
  while l:i < l:max
    if l:script[l:i] == "'"
      " Single quote.
      let [l:arg_quote, l:i] = s:parse_single_quote(l:script, l:i)
      let l:arg .= l:arg_quote
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[l:i] == '"'
      " Double quote.
      let [l:arg_quote, l:i] = s:parse_double_quote(l:script, l:i)
      let l:arg .= l:arg_quote
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[l:i] == '`'
      " Back quote.
      let [l:arg_quote, l:i] = s:parse_back_quote(l:script, l:i)
      let l:arg .= l:arg_quote
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '\'
      " Escape.
      let l:i += 1

      if l:i > l:max
        throw 'Exception: Join to next line (\).'
      endif

      let l:arg .= l:script[i]
      let l:i += 1
    elseif l:script[i] == '#'
      " Comment.
      break
    elseif l:script[l:i] != ' '
      let l:arg .= l:script[l:i]
      let l:i += 1
    else
      " Space.
      if l:arg != ''
        call add(l:args, l:arg)
      endif

      let l:arg = ''

      let l:i += 1
    endif
  endwhile

  if l:arg != ''
    call add(l:args, l:arg)
  endif

  " Substitute modifier.
  let l:ret = []
  for l:arg in l:args
    if l:arg =~ '\%(:[p8~.htre]\)\+$'
      let l:modify = matchstr(l:arg, '\%(:[p8~.htre]\)\+$')
      let l:arg = fnamemodify(l:arg[: -len(l:modify)-1], l:modify)
    endif

    call add(l:ret, l:arg)
  endfor

  return l:ret
endfunction"}}}
function! s:split_pipe(script)"{{{
  let l:script = ''

  let l:i = 0
  let l:max = len(a:script)
  let l:commands = []
  while l:i < l:max
    if a:script[l:i] == '|'
      " Pipe.
      call add(l:commands, l:script)

      " Search next command.
      let l:script = ''
      let l:i += 1
    elseif a:script[l:i] == "'"
      " Single quote.
      let [l:string, l:i] = s:skip_quote(a:script, l:i)
      let l:script .= l:string
    elseif a:script[l:i] == '"'
      " Double quote.
      let [l:string, l:i] = s:skip_double_quote(a:script, l:i)
      let l:script .= l:string
    elseif a:script[l:i] == '`'
      " Back quote.
      let [l:string, l:i] = s:skip_back_quote(a:script, l:i)
      let l:script .= l:string
    elseif a:script[l:i] == '\' && l:i + 1 < l:max
      " Escape.
      let l:script .= '\' . a:script[l:i+1]
      let l:i += 2
    else
      let l:script .= a:script[l:i]
      let l:i += 1
    endif
  endwhile
  
  call add(l:commands, l:script)

  return l:commands
endfunction"}}}
function! s:parse_single_quote(script, i)"{{{
  if a:script[a:i] != "'"
    return ['', a:i]
  endif

  let l:arg = ''
  let i = a:i + 1
  let l:max = len(a:script)
  while i < l:max
    if a:script[i] == "'"
      if i+1 < l:max && a:script[i+1] == "'"
        " Escape quote.
        let l:arg .= "'"
        let i += 2
      else
        " Quote end.
        return [l:arg, i+1]
      endif
    else
      let l:arg .= a:script[i]
      let i += 1
    endif
  endwhile

  throw 'Exception: Quote ('') is not found.'
endfunction"}}}
function! s:parse_double_quote(script, i)"{{{
  if a:script[a:i] != '"'
    return ['', a:i]
  endif

  let l:arg = ''
  let i = a:i + 1
  let l:max = len(a:script)
  while i < l:max
    if a:script[i] == '"'
      " Quote end.
      return [l:arg, i+1]
    elseif a:script[i] == '\'
      " Escape.
      let l:i += 1

      if l:i > l:max
        throw 'Exception: Join to next line (\).'
      endif

      let l:arg .= a:script[i]
      let l:i += 1
    else
      let l:arg .= a:script[i]
      let i += 1
    endif
  endwhile

  throw 'Exception: Quote (") is not found.'
endfunction"}}}
function! s:parse_back_quote(script, i)"{{{
  if a:script[a:i] != '`'
    return ['', a:i]
  endif
  
  let l:arg = ''
  let l:max = len(a:script)
  if i + 1 < l:max && a:script[a:i + 1] == '='
    " Vim eval quote.
    let i = a:i + 2
    
    while i < l:max
      if a:script[i] == '`'
        " Quote end.
        return [eval(l:arg), i+1]
      else
        let l:arg .= a:script[i]
        let i += 1
      endif
    endwhile
  else
    " Eval quote.
    let i = a:i + 1
    
    while i < l:max
      if a:script[i] == '`'
        " Quote end.
        return [l:arg, i+1]
      else
        let l:arg .= a:script[i]
        let i += 1
      endif
    endwhile
  endif

  throw 'Exception: Quote (`) is not found.'
endfunction"}}}

" Skip helper.
function! s:skip_single_quote(script, i)"{{{
  let l:end = matchend(a:script, "^'[^']*'", a:i)
  if l:end == -1
    throw 'Exception: Quote ('') is not found.'
  endif
  return [matchstr(a:script, "^'[^']*'", a:i), l:end]
endfunction"}}}
function! s:skip_double_quote(script, i)"{{{
  let l:end = matchend(a:script, '^"\%([^"]\|\"\)*"', a:i)
  if l:end == -1
    throw 'Exception: Quote (") is not found.'
  endif
  return [matchstr(a:script, '^"\%([^"]\|\"\)*"', a:i), l:end]
endfunction"}}}
function! s:skip_back_quote(script, i)"{{{
  let l:end = matchend(a:script, '^`[^`]*`', a:i)
  if l:end == -1
    throw 'Exception: Quote (`) is not found.'
  endif
  return [matchstr(a:script, '^`[^`]*`', a:i), l:end]
endfunction"}}}
