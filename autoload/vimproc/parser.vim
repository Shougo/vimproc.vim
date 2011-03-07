"=============================================================================
" FILE: parser.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 07 Mar 2011.
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


let s:is_win = has('win32') || has('win64')

function! vimproc#parser#system(cmdline, ...)"{{{
  let l:args = vimproc#parser#parse_statements(a:cmdline)
  for l:arg in l:args
    let l:arg.statement = vimproc#parser#parse_pipe(l:arg.statement)
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
    let l:args = vimproc#parser#split_args(l:cmdline)
    return vimproc#system_bg(l:args)
  endif
endfunction"}}}

function! vimproc#parser#popen2(cmdline)"{{{
  return vimproc#popen2(vimproc#parser#split_args(a:cmdline))
endfunction"}}}
function! vimproc#parser#plineopen2(args)"{{{
  return vimproc#popen2(vimproc#parser#parse_pipe(a:args))
endfunction"}}}

function! vimproc#parser#popen3(cmdline)"{{{
  return vimproc#popen3(vimproc#parser#split_args(a:cmdline))
endfunction"}}}
function! vimproc#parser#plineopen3(args)"{{{
  return vimproc#popen3(vimproc#parser#parse_pipe(a:args))
endfunction"}}}

function! vimproc#parser#ptyopen(cmdline)"{{{
  return vimproc#ptyopen(vimproc#parser#split_args(a:cmdline))
endfunction"}}}

function! vimproc#parser#pgroup_open(cmdline)"{{{
  let l:statements = vimproc#parser#parse_statements(a:cmdline)
  for l:statement in l:statements
    let l:statement.statement = vimproc#parser#parse_pipe(l:statement.statement)
  endfor
  return vimproc#pgroup_open(l:statements)
endfunction"}}}

" For vimshell parser.
function! vimproc#parser#parse_pipe(statement)"{{{
  let l:commands = []
  for l:cmdline in vimproc#parser#split_pipe(a:statement)
    " Expand block.
    if l:cmdline =~ '{'
      let l:cmdline = s:parse_block(l:cmdline)
    endif

    " Expand tilde.
    if l:cmdline =~ '\~'
      let l:cmdline = s:parse_tilde(l:cmdline)
    endif

    " Expand filename.
    if l:cmdline =~ ' ='
      let l:cmdline = s:parse_equal(l:cmdline)
    endif

    " Expand variables.
    if l:cmdline =~ '\$'
      let l:cmdline = s:parse_variables(l:cmdline)
    endif

    " Expand wildcard.
    if l:cmdline =~ '[[*?]\|\\[()|]'
      let l:cmdline = s:parse_wildcard(l:cmdline)
    endif

    " Split args.
    let l:args = vimproc#parser#split_args(l:cmdline)

    " Parse redirection.
    if l:cmdline =~ '[<>]'
      let [l:fd, l:cmdline] = s:parse_redirection(l:cmdline)
    else
      let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    endif

    if l:fd.stdout != '' && l:fd.stdout !~ '^>'
      if l:fd.stdout ==# '/dev/clip'
        " Clear.
        let @+ = ''
      else
        if filereadable(l:fd.stdout)
          " Delete file.
          call delete(l:fd.stdout)
        endif

        " Create file.
        call writefile([], l:fd.stdout)
      endif
    endif

    call add(l:commands, {
          \ 'args' : vimproc#parser#split_args(l:cmdline),
          \ 'fd' : l:fd
          \})
  endfor

  return l:commands
endfunction"}}}
function! vimproc#parser#parse_statements(script)"{{{
  if a:script =~ '^\s*:'
    return [ { 'statement' : a:script, 'condition' : 'always' } ]
  endif

  let l:max = len(a:script)
  let l:statements = []
  let l:statement = ''
  let i = 0
  while i < l:max
    if a:script[i] == ';'
      if l:statement != ''
        call add(l:statements,
              \ { 'statement' : l:statement,
              \   'condition' : 'always',
              \})
      endif
      let l:statement = ''
      let i += 1
    elseif a:script[i] == '&'
      if i+1 < len(a:script) && a:script[i+1] == '&'
        if l:statement != ''
          call add(l:statements,
                \ { 'statement' : l:statement,
                \   'condition' : 'true',
                \})
        endif
        let l:statement = ''
        let i += 2
      else
        let l:statement .= a:script[i]

        let i += 1
      endif
    elseif a:script[i] == '|'
      if i+1 < len(a:script) && a:script[i+1] == '|'
        if l:statement != ''
          call add(l:statements,
                \ { 'statement' : l:statement,
                \   'condition' : 'false',
                \})
        endif
        let l:statement = ''
        let i += 2
      else
        let l:statement .= a:script[i]

        let i += 1
      endif
    elseif a:script[i] == "'"
      " Single quote.
      let [l:string, i] = s:skip_single_quote(a:script, i)
      let l:statement .= l:string
    elseif a:script[i] == '"'
      " Double quote.
      let [l:string, i] = s:skip_double_quote(a:script, i)
      let l:statement .= l:string
    elseif a:script[i] == '`'
      " Back quote.
      let [l:string, i] = s:skip_back_quote(a:script, i)
      let l:statement .= l:string
    elseif a:script[i] == '\'
      " Escape.
      let i += 1

      if i >= len(a:script)
        throw 'Exception: Join to next line (\).'
      endif

      let l:statement .= '\' . a:script[i]
      let i += 1
    elseif a:script[i] == '#'
      " Comment.
      break
    else
      let l:statement .= a:script[i]
      let i += 1
    endif
  endwhile

  if l:statement != ''
    call add(l:statements,
          \ { 'statement' : l:statement,
          \   'condition' : 'always',
          \})
  endif

  return l:statements
endfunction"}}}

function! vimproc#parser#split_statements(script)"{{{
  return map(vimproc#parser#parse_statements(a:script),
        \ 'v:val.statement')
endfunction"}}}
function! vimproc#parser#split_args(script)"{{{
  let l:script = a:script
  let l:max = len(l:script)
  let l:args = []
  let l:arg = ''
  let i = 0
  while i < l:max
    if l:script[i] == "'"
      " Single quote.
      let [l:arg_quote, i] = s:parse_single_quote(l:script, i)
      let l:arg .= l:arg_quote
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '"'
      " Double quote.
      let [l:arg_quote, i] = s:parse_double_quote(l:script, i)
      let l:arg .= l:arg_quote
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '`'
      " Back quote.
      let [l:arg_quote, i] = s:parse_back_quote(l:script, i)
      let l:arg .= l:arg_quote
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '\'
      " Escape.
      let i += 1

      if i > l:max
        throw 'Exception: Join to next line (\).'
      endif

      let l:arg .= l:script[i]
      let i += 1
    elseif l:script[i] == '#'
      " Comment.
      break
    elseif l:script[i] != ' '
      let l:arg .= l:script[i]
      let i += 1
    else
      " Space.
      if l:arg != ''
        call add(l:args, l:arg)
      endif

      let l:arg = ''

      let i += 1
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
function! vimproc#parser#split_args_through(script)"{{{
  let l:script = a:script
  let l:max = len(l:script)
  let l:args = []
  let l:arg = ''
  let i = 0
  while i < l:max
    if l:script[i] == "'"
      " Single quote.
      let [l:string, i] = s:skip_single_quote(l:script, i)
      let l:arg .= l:string
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '"'
      " Double quote.
      let [l:string, i] = s:skip_double_quote(l:script, i)
      let l:arg .= l:string
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '`'
      " Back quote.
      let [l:string, i] = s:skip_back_quote(l:script, i)
      let l:arg .= l:string
      if l:arg == ''
        call add(l:args, '')
      endif
    elseif l:script[i] == '\'
      " Escape.
      let i += 1

      if i > l:max
        throw 'Exception: Join to next line (\).'
      endif

      let l:arg .= '\'.l:script[i]
      let i += 1
    elseif l:script[i] != ' '
      let l:arg .= l:script[i]
      let i += 1
    else
      " Space.
      if l:arg != ''
        call add(l:args, l:arg)
      endif

      let l:arg = ''

      let i += 1
    endif
  endwhile

  if l:arg != ''
    call add(l:args, l:arg)
  endif

  return l:args
endfunction"}}}
function! vimproc#parser#split_pipe(script)"{{{
  let l:script = ''

  let i = 0
  let l:max = len(a:script)
  let l:commands = []
  while i < l:max
    if a:script[i] == '|'
      " Pipe.
      call add(l:commands, l:script)

      " Search next command.
      let l:script = ''
      let i += 1
    elseif a:script[i] == "'"
      " Single quote.
      let [l:string, i] = s:skip_single_quote(a:script, i)
      let l:script .= l:string
    elseif a:script[i] == '"'
      " Double quote.
      let [l:string, i] = s:skip_double_quote(a:script, i)
      let l:script .= l:string
    elseif a:script[i] == '`'
      " Back quote.
      let [l:string, i] = s:skip_back_quote(a:script, i)
      let l:script .= l:string
    elseif a:script[i] == '\' && i + 1 < l:max
      " Escape.
      let l:script .= '\' . a:script[i+1]
      let i += 2
    else
      let l:script .= a:script[i]
      let i += 1
    endif
  endwhile

  call add(l:commands, l:script)

  return l:commands
endfunction"}}}
function! vimproc#parser#split_commands(script)"{{{
  let l:script = a:script
  let l:max = len(l:script)
  let l:commands = []
  let l:command = ''
  let i = 0
  while i < l:max
    if l:script[i] == '\'
      " Escape.
      let l:command .= l:script[i]
      let i += 1

      if i > l:max
        throw 'Exception: Join to next line (\).'
      endif

      let l:command .= l:script[i]
      let i += 1
    elseif l:script[i] == '|'
      if l:command != ''
        call add(l:commands, l:command)
      endif
      let l:command = ''

      let i += 1
    else

      let l:command .= l:script[i]
      let i += 1
    endif
  endwhile

  if l:command != ''
    call add(l:commands, l:command)
  endif

  return l:commands
endfunction"}}}
function! vimproc#parser#expand_wildcard(wildcard)"{{{
  " Check wildcard.
  let i = 0
  let l:max = len(a:wildcard)
  let l:script = ''
  let l:found = 0
  while i < l:max
    if a:wildcard[i] == '*' || a:wildcard[i] == '?' || a:wildcard[i] == '['
      let l:found = 1
      break
    else
      let [l:script, i] = s:skip_else(l:script, a:wildcard, i)
    endif
  endwhile

  if !l:found
    return [ a:wildcard ]
  endif

  let l:wildcard = a:wildcard

  " Exclude wildcard.
  let l:exclude = matchstr(l:wildcard, '\\\@<!\~\zs.\+$')
  let l:exclude_wilde = []
  if l:exclude != ''
    " Truncate wildcard.
    let l:wildcard = l:wildcard[: len(l:wildcard)-len(l:exclude)-2]
    let l:exclude_wilde = vimproc#parser#expand_wildcard(l:exclude)
  endif

  " Modifier.
  let l:modifier = matchstr(l:wildcard, '\\\@<!(\zs.\+\ze)$')
  if l:modifier != ''
    " Truncate wildcard.
    let l:wildcard = l:wildcard[: len(l:wildcard)-len(l:modifier)-3]
  endif

  " Expand wildcard.
  let l:expanded = split(escape(substitute(glob(l:wildcard), '\\', '/', 'g'), ' '), '\n')
  if !empty(l:exclude_wilde)
    " Check exclude wildcard.
    let l:candidates = l:expanded
    let l:expanded = []
    for candidate in l:candidates
      let l:found = 0

      for ex in l:exclude_wilde
        if candidate ==# ex
          let l:found = 1
          break
        endif
      endfor

      if !l:found
        call add(l:expanded, candidate)
      endif
    endfor
  endif

  if l:modifier != ''
    " Check file modifier.
    let i = 0
    let l:max = len(l:modifier)
    while i < l:max
      if l:modifier[i] ==# '/'
        " Directory.
        let l:expr = 'getftype(v:val) ==# "dir"'
      elseif l:modifier[i] ==# '.'
        " Normal.
        let l:expr = 'getftype(v:val) ==# "file"'
      elseif l:modifier[i] ==# '@'
        " Link.
        let l:expr = 'getftype(v:val) ==# "link"'
      elseif l:modifier[i] ==# '='
        " Socket.
        let l:expr = 'getftype(v:val) ==# "socket"'
      elseif l:modifier[i] ==# 'p'
        " FIFO Pipe.
        let l:expr = 'getftype(v:val) ==# "pipe"'
      elseif l:modifier[i] ==# '*'
        " Executable.
        let l:expr = 'getftype(v:val) ==# "pipe"'
      elseif l:modifier[i] ==# '%'
        " Device.

        if l:modifier[i:] =~# '^%[bc]'
          if l:modifier[i] ==# 'b'
            " Block device.
            let l:expr = 'getftype(v:val) ==# "bdev"'
          else
            " Character device.
            let l:expr = 'getftype(v:val) ==# "cdev"'
          endif

          let i += 1
        else
          let l:expr = 'getftype(v:val) ==# "bdev" || getftype(v:val) ==# "cdev"'
        endif
      else
        " Unknown.
        return []
      endif

      call filter(l:expanded, l:expr)
      let i += 1
    endwhile
  endif

  return filter(l:expanded, 'v:val != "." && v:val != ".."')
endfunction"}}}

" Parse helper.
function! s:parse_block(script)"{{{
  let l:script = ''

  let i = 0
  let l:max = len(a:script)
  while i < l:max
    if a:script[i] == '{'
      " Block.
      let l:head = matchstr(a:script[: i-1], '[^[:blank:]]*$')
      " Truncate l:script.
      let l:script = l:script[: -len(l:head)-1]
      let l:block = matchstr(a:script, '{\zs.*[^\\]\ze}', i)
      if l:block == ''
        throw 'Exception: Block is not found.'
      elseif l:block =~ '^\d\+\.\.\d\+$'
        " Range block.
        let l:start = matchstr(l:block, '^\d\+')
        let l:end = matchstr(l:block, '\d\+$')
        let l:zero = len(matchstr(l:block, '^0\+'))
        let l:pattern = '%0' . l:zero . 'd'
        for l:b in range(l:start, l:end)
          " Concat.
          let l:script .= l:head . printf(l:pattern, l:b) . ' '
        endfor
      else
        " Normal block.
        for l:b in split(l:block, ',', 1)
          " Concat.
          let l:script .= l:head . escape(l:b, ' ') . ' '
        endfor
      endif
      let i = matchend(a:script, '{.*[^\\]}', i)
    else
      let [l:script, i] = s:skip_else(l:script, a:script, i)
    endif
  endwhile

  return l:script
endfunction"}}}
function! s:parse_tilde(script)"{{{
  let l:script = ''

  let i = 0
  let l:max = len(a:script)
  while i < l:max
    if a:script[i] == ' ' && a:script[i+1] == '~'
      " Tilde.
      " Expand home directory.
      let l:script .= ' ' . escape(substitute($HOME, '\\', '/', 'g'), '\ ')
      let i += 2
    elseif i == 0 && a:script[i] == '~'
      " Tilde.
      " Expand home directory.
      let l:script .= escape(substitute($HOME, '\\', '/', 'g'), '\ ')
      let i += 1
    else
      let [l:script, i] = s:skip_else(l:script, a:script, i)
    endif
  endwhile

  return l:script
endfunction"}}}
function! s:parse_equal(script)"{{{
  let l:script = ''

  let i = 0
  let l:max = len(a:script)
  while i < l:max - 1
    if a:script[i] == ' ' && a:script[i+1] == '='
      " Expand filename.
      let l:prog = matchstr(a:script, '^=\zs[^[:blank:]]*', i+1)
      if l:prog == ''
        let [l:script, i] = s:skip_else(l:script, a:script, i)
      else
        let l:filename = vimproc#get_command_path(l:prog)
        if l:filename == ''
          throw printf('Error: File "%s" is not found.', l:prog)
        else
          let l:script .= l:filename
        endif

        let i += matchend(a:script, '^=[^[:blank:]]*', i+1)
      endif
    else
      let [l:script, i] = s:skip_else(l:script, a:script, i)
    endif
  endwhile

  return l:script
endfunction"}}}
function! s:parse_variables(script)"{{{
  let l:script = ''

  let i = 0
  let l:max = len(a:script)
  try
    while i < l:max
      if a:script[i] == '$'
        " Eval variables.
        if exists('b:vimshell')
          " For vimshell.
          if match(a:script, '^$\l', i) >= 0
            let l:script .= string(eval(printf("b:vimshell.variables['%s']", matchstr(a:script, '^$\zs\l\w*', i))))
          elseif match(a:script, '^$$', i) >= 0
            let l:script .= string(eval(printf("b:vimshell.system_variables['%s']", matchstr(a:script, '^$$\zs\h\w*', i))))
          else
            let l:script .= string(eval(matchstr(a:script, '^$\h\w*', i)))
          endif
        else
          let l:script .= string(eval(matchstr(a:script, '^$\h\w*', i)))
        endif

        let i = matchend(a:script, '^$$\?\h\w*', i)
      else
        let [l:script, i] = s:skip_else(l:script, a:script, i)
      endif
    endwhile
  catch /^Vim\%((\a\+)\)\=:E15/
    " Parse error.
    return a:script
  endtry

  return l:script
endfunction"}}}
function! s:parse_wildcard(script)"{{{
  let l:script = ''
  for l:arg in vimproc#parser#split_args_through(a:script)
    let l:script .= join(vimproc#parser#expand_wildcard(l:arg)) . ' '
  endfor

  return l:script
endfunction"}}}
function! s:parse_redirection(script)"{{{
  let l:script = ''
  let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }

  let i = 0
  let l:max = len(a:script)
  while i < l:max
    if a:script[i] == '<'
      " Input redirection.
      let l:fd.stdin = matchstr(a:script, '<\s*\zs\f*', i)
      let i = matchend(a:script, '<\s*\zs\f*', i)
    elseif a:script[i] =~ '^[12]' && a:script[i :] =~ '^[12]>' 
      " Output redirection.
      let i += 2
      if a:script[i-2] == 1
        let l:fd.stdout = matchstr(a:script, '^\s*\zs\f*', i)
      else
        let l:fd.stderr = matchstr(a:script, '^\s*\zs\f*', i)
      endif

      let i = matchend(a:script, '^\s*\zs\f*', i)
    elseif a:script[i] == '>'
      " Output redirection.
      if a:script[i :] =~ '^>&'
        " Output stderr.
        let i += 2
        let l:fd.stderr = matchstr(a:script, '^\s*\zs\f*', i)
      elseif a:script[i :] =~ '^>>'
        " Append stdout.
        let i += 2
        let l:fd.stdout = '>' . matchstr(a:script, '^\s*\zs\f*', i)
      else
        " Output stdout.
        let i += 1
        let l:fd.stdout = matchstr(a:script, '^\s*\zs\f*', i)
      endif

      let i = matchend(a:script, '^\s*\zs\f*', i)
    else
      let [l:script, i] = s:skip_else(l:script, a:script, i)
    endif
  endwhile

  return [l:fd, l:script]
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

  let l:escape_sequences = {
        \ 'a' : "\<C-g>", 'b' : "\<BS>",
        \ 't' : "\<Tab>", 'r' : "\<CR>",
        \ 'n' : "\<LF>",  'e' : "\<Esc>",
        \ '\' : '\',  '?' : '?',
        \ '"' : '"',  "'" : "'",
        \}
  let l:arg = ''
  let i = a:i + 1
  let l:max = len(a:script)
  while i < l:max
    if a:script[i] == '"'
      " Quote end.
      return [l:arg, i+1]
    elseif a:script[i] == '\'
      " Escape.
      let i += 1

      if i > l:max
        throw 'Exception: Join to next line (\).'
      endif

      if a:script[i] == 'x'
        let l:num = matchstr(a:script, '^\x\+', i+1)
        let l:arg .= nr2char(str2nr(l:num, 16))
        let i += len(l:num)
      elseif has_key(l:escape_sequences, a:script[i])
        let l:arg .= l:escape_sequences[a:script[i]]
      else
        let l:arg .= '\' . a:script[i]
      endif
      let i += 1
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
  if a:i + 1 < l:max && a:script[a:i + 1] == '='
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
        return [substitute(vimproc#system(l:arg), '\n$', '', ''), i+1]
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
function! s:skip_else(args, script, i)"{{{
  if a:script[a:i] == "'"
    " Single quote.
    let [l:string, i] = s:skip_single_quote(a:script, a:i)
    let l:script = a:args . l:string
  elseif a:script[a:i] == '"'
    " Double quote.
    let [l:string, i] = s:skip_double_quote(a:script, a:i)
    let l:script = a:args . l:string
  elseif a:script[a:i] == '`'
    " Back quote.
    let [l:string, i] = s:skip_back_quote(a:script, a:i)
    let l:script = a:args . l:string
  elseif a:script[a:i] == '\'
    " Escape.
    let l:script = a:args . '\' . a:script[a:i+1]
    let i = a:i + 2
  else
    let l:script = a:args . a:script[a:i]
    let i = a:i + 1
  endif

  return [l:script, i]
endfunction"}}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
" vim:foldmethod=marker:fen:sw=2:sts=2
