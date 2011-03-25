"=============================================================================
" FILE: vimproc.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com> (Modified)
"          Yukihiro Nakadaira <yukihiro.nakadaira at gmail.com> (Original)
" Last Modified: 25 Mar 2011.
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
" Version: 5.1, for Vim 7.0
"=============================================================================

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:is_win = has('win32') || has('win64')
let s:is_mac = !s:is_win && (has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin')

" MacVim trouble shooter {{{
if s:is_mac && !&encoding
  set encoding=utf-8
endif
"}}}
function! vimproc#version()
  return str2nr(printf('%2d%02d', 5, 1))
endfunction

let s:last_status = 0

" Global options definition."{{{
if !exists('g:vimproc_dll_path')
  let g:vimproc_dll_path = expand("<sfile>:p:h") . (has('win32') || has('win64')? '/proc.dll' : has('win32unix') ? '/proc_cygwin.dll' : '/proc.so')
endif
"}}}

let g:vimproc_dll_path = vimproc#util#iconv(g:vimproc_dll_path, &encoding, vimproc#util#termencoding())

if !filereadable(g:vimproc_dll_path)
  echoerr printf('vimproc''s DLL: "%s" is not found. Please read :help vimproc and make it.', g:vimproc_dll_path)
  finish
endif

"-----------------------------------------------------------
" API

function! vimproc#open(filename)"{{{
  let l:filename = vimproc#util#iconv(fnamemodify(a:filename, ':p'), &encoding, vimproc#util#termencoding())

  " Detect desktop environment.
  if s:is_win
    " For URI only.
    "execute '!start rundll32 url.dll,FileProtocolHandler' l:filename

    call s:libcall('vp_open', [l:filename])
  elseif has('win32unix')
    " Cygwin.
    call vimproc#system(['cygstart', l:filename])
  elseif executable('xdg-open')
    " Linux.
    call vimproc#system_bg(['xdg-open', l:filename])
  elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
    " KDE.
    call vimproc#system_bg(['kioclient', 'exec', l:filename])
  elseif exists('$GNOME_DESKTOP_SESSION_ID')
    " GNOME.
    call vimproc#system_bg(['gnome-open', l:filename])
  elseif executable('exo-open')
    " Xfce.
    call vimproc#system_bg(['exo-open', l:filename])
  elseif s:is_mac && executable('open')
    " Mac OS.
    call vimproc#system_bg(['open', l:filename])
  else
    " Give up.
    throw 'vimproc#open: Not supported.'
  endif
endfunction"}}}

function! vimproc#get_command_name(command, ...)"{{{
  if a:0 > 3
    throw 'vimproc#get_command_name: Invalid argument.'
  endif

  if a:0 >= 1
    let l:path = a:1
  else
    let l:path = $PATH
  endif

  " Expand path.
  let l:path = substitute(l:path, (s:is_win ? ';' : ':'), ',', 'g')
  if s:is_win
    let l:path = substitute(l:path, '\\', '/', 'g')
  endif

  " Escape ' ' and ".
  let l:path = escape(l:path, ' "')

  let l:count = a:0 < 2 ? 1 : a:2

  let l:command = expand(a:command)

  let l:pattern = printf('[/~]\?\f\+[%s]\f*$', s:is_win ? '/\\' : '/')
  if l:command =~ l:pattern && (!s:is_win || fnamemodify(l:command, ':e') != '')
    if !executable(l:command)
      let l:command = resolve(l:command)
    endif

    if !filereadable(l:command)
      throw printf('vimproc#get_command_name: File "%s" is not found.', l:command)
    elseif !s:is_win && !executable(l:command)
      throw printf('vimproc#get_command_name: File "%s" is not executable.', l:command)
    endif

    return l:count < 0 ? [ l:command ] : l:command
  endif

  " Command search.
  let l:suffixesadd_save = &l:suffixesadd
  if s:is_win
    " On Windows, findfile() search a file which don't have file extension
    " also. When there are 'perldoc', 'perldoc.bat' in your $PATH,
    " executable('perldoc')  return 1 cause by you have 'perldoc.bat'.
    " But findfile('perldoc', $PATH, 1) return whether file exist there.
    if fnamemodify(l:command, ':e') == ''
      let &l:suffixesadd = ''
      " for l:ext in split($PATHEXT.';.LNK', ';')
      "   let l:file = findfile(l:command . l:ext, l:path, l:count)
      if l:command =~ '[/\\]'
        " Absolute path.
        let l:path = fnamemodify(l:command, ':h')
        let l:command = fnamemodify(l:command, ':t')
      else
        " substitute ,, -> ,
        let l:path = substitute(l:path, ',\{2,}', ',', 'g')
      endif

      let l:file = l:count < 0 ? [] : ''
      for l:head in split(l:path, ',')
        for l:ext in split($PATHEXT.';.LNK', ';')
          let l:findfile = findfile(l:command . tolower(l:ext), l:head, l:count)
          if l:count >= 0 && l:findfile != ''
            let l:file = l:findfile
            break
          elseif l:count < 0 && !empty(l:findfile)
            let l:file += l:findfile
          endif
        endfor

        if l:count >= 0 && l:file != ''
          break
        endif
      endfor
    else
      let &l:suffixesadd = substitute($PATHEXT.';.LNK', ';', ',', 'g')
      let l:file = findfile(l:command, l:path, l:count)
    endif
  else
    let &l:suffixesadd = ''
    let l:file = findfile(l:command, l:path, l:count)
  endif
  let &l:suffixesadd = l:suffixesadd_save

  if l:count < 0
    return map(filter(l:file, 'executable(v:val)'), 'fnamemodify(v:val, ":p")')
  else
    if l:file != ''
      let l:file = fnamemodify(l:file, ':p')
    endif

    if !executable(l:command)
      let l:file = resolve(l:file)
    endif

    if l:file == ''
      throw printf('vimproc#get_command_name: File "%s" is not found.', l:command)
    elseif !s:is_win && !executable(l:file)
      throw printf('vimproc#get_command_name: File "%s" is not executable.', l:file)
    endif
  endif

  return l:file
endfunction"}}}

function! vimproc#system(cmdline, ...)"{{{
  if type(a:cmdline) == type('')
    if a:cmdline =~ '&\s*$'
      return vimproc#system_bg(a:cmdline)
    elseif (!has('unix') || a:cmdline !~ '^\s*man ')
      return call('vimproc#parser#system', [a:cmdline]+a:000)
    endif
  endif

  if empty(a:cmdline)
    let s:last_status = 0
    let s:last_errmsg = ''
    return ''
  endif

  let l:timeout = a:0 >= 2 ? a:2 : 0

  " Open pipe.
  let l:subproc = (type(a:cmdline[0]) == type('')) ?
        \ vimproc#popen3(a:cmdline) : vimproc#pgroup_open(a:cmdline)

  if !empty(a:000)
    " Write input.
    call l:subproc.stdin.write(a:1)
  endif
  call l:subproc.stdin.close()

  if l:timeout > 0 && has('reltime') && v:version >= 702
    let l:start = reltime()
  else
    let l:timeout = 0
  endif

  let l:output = ''
  let s:last_errmsg = ''
  while !l:subproc.stdout.eof || !l:subproc.stderr.eof
    if l:timeout > 0
      " Check timeout.
      let l:end = split(reltimestr(reltime(l:start)))[0] * 1000
      if l:end > l:timeout && !l:subproc.stdout.eof
        " Kill process.
        " 15 == SIGTERM
        try
          call l:subproc.kill(15)
          call l:subproc.waitpid()
        catch
          " Ignore error.
        endtry

        return ''
      endif
    endif

    if !l:subproc.stdout.eof
      let l:output .= l:subproc.stdout.read(-1, 40)
    endif

    if !l:subproc.stderr.eof
      let s:last_errmsg .= l:subproc.stderr.read(-1, 40)
    endif
  endwhile

  let [l:cond, l:status] = l:subproc.waitpid()

  " Newline convert.
  if s:is_mac
    let l:output = substitute(l:output, '\r', '\n', 'g')
  elseif has('win32') || has('win64')
    let l:output = substitute(l:output, '\r\n', '\n', 'g')
  endif

  return l:output
endfunction"}}}
function! vimproc#system2(...)"{{{
  if !empty(a:000)
    let l:args = deepcopy(a:000)
    let l:args[1] = vimproc#util#iconv(l:args[1], &encoding, vimproc#util#stdinencoding())
  else
    let l:args = a:000
  endif
  let l:output = call('vimproc#system', l:args)

  " This function converts application encoding to &encoding.
  let l:output = vimproc#util#iconv(l:output, vimproc#util#stdoutencoding(), &encoding)
  let s:last_errmsg = vimproc#util#iconv(s:last_errmsg, vimproc#util#stderrencoding(), &encoding)

  return l:output
endfunction"}}}
function! vimproc#system_bg(cmdline)"{{{
  " Open pipe.
  let l:subproc = vimproc#popen3(a:cmdline)
  let s:bg_processes[l:subproc.pid] = l:subproc.pid

  return ''
endfunction"}}}

function! vimproc#get_last_status()"{{{
  return s:last_status
endfunction"}}}
function! vimproc#get_last_errmsg()"{{{
  return s:last_errmsg
endfunction"}}}

function! vimproc#fopen(path, flags, ...)"{{{
  let l:mode = get(a:000, 0, 0)
  let l:fd = s:vp_file_open(a:path, a:flags, l:mode)
  let l:proc = s:fdopen(l:fd, 'vp_file_close', 'vp_file_read', 'vp_file_write')
  return l:proc
endfunction"}}}

function! vimproc#popen2(args)"{{{
  if type(a:args) == type('')
    return vimproc#parser#popen2(a:args)
  endif

  return s:popen(3, a:args)
endfunction"}}}
function! vimproc#popen3(args)"{{{
  if type(a:args) == type('')
    return vimproc#parser#popen3(a:args)
  endif

  return s:popen(3, a:args)
endfunction"}}}
function! s:popen(npipe, args)"{{{
  let l:pipe = s:vp_pipe_open(a:npipe, 0, 0, 0, s:convert_args(a:args))
  if a:npipe == 3
    let [l:pid, l:fd_stdin, l:fd_stdout, l:fd_stderr] = l:pipe
  else
    let [l:pid, l:fd_stdin, l:fd_stdout] = l:pipe
  endif

  let l:proc = {}
  let l:proc.pid = l:pid
  let l:proc.stdin = s:fdopen(l:fd_stdin, 'vp_pipe_close', 'vp_pipe_read', 'vp_pipe_write')
  let l:proc.stdout = s:fdopen(l:fd_stdout, 'vp_pipe_close', 'vp_pipe_read', 'vp_pipe_write')
  if a:npipe == 3
    let l:proc.stderr = s:fdopen(l:fd_stderr, 'vp_pipe_close', 'vp_pipe_read', 'vp_pipe_write')
  endif
  let l:proc.kill = s:funcref('vp_kill')
  let l:proc.waitpid = s:funcref('vp_waitpid')
  let l:proc.is_valid = 1

  return proc
endfunction"}}}

function! vimproc#plineopen2(commands)"{{{
  if type(a:commands) == type('')
    return vimproc#parser#plineopen2(a:commands)
  endif

  return s:plineopen(2, a:commands)
endfunction"}}}
function! vimproc#plineopen3(commands)"{{{
  if type(a:commands) == type('')
    return vimproc#parser#plineopen3(a:commands)
  endif

  return s:plineopen(3, a:commands)
endfunction"}}}
function! s:plineopen(npipe, commands)"{{{
  let l:pid_list = []
  let l:stdin_list = []
  let l:stdout_list = []
  let l:stderr_list = []

  " Open input.
  let l:hstdin = (empty(a:commands) || a:commands[0].fd.stdin == '')?
        \ 0 : vimproc#fopen(a:commands[0].fd.stdin, "O_RDONLY").fd

  for l:command in a:commands
    let l:mode = 'O_WRONLY | O_CREAT'
    if l:command.fd.stdout =~ '^>'
      let l:mode .= ' | O_APPEND'
      let l:command.fd.stdout = l:command.fd.stdout[1:]
    endif
    let l:hstdout = l:command.fd.stdout == '' ?
          \ 0 : vimproc#fopen(l:command.fd.stdout, l:mode).fd

    let l:mode = 'O_WRONLY | O_CREAT'
    if l:command.fd.stderr =~ '^>'
      let l:mode .= ' | O_APPEND'
      let l:command.fd.stderr = l:command.fd.stderr[1:]
    endif
    let l:hstderr = l:command.fd.stderr == '' ?
          \ 0 : vimproc#fopen(l:command.fd.stderr, l:mode).fd

    let l:pipe = s:vp_pipe_open(a:npipe, l:hstdin, l:hstdout, l:hstderr,
          \ s:convert_args(l:command.args))
    if a:npipe == 3
      let [l:pid, l:fd_stdin, l:fd_stdout, l:fd_stderr] = l:pipe
    else
      let [l:pid, l:fd_stdin, l:fd_stdout] = l:pipe
    endif

    call add(l:pid_list, l:pid)
    call add(l:stdin_list, s:fdopen(l:fd_stdin, 'vp_pipe_close', 'vp_pipe_read', 'vp_pipe_write'))
    call add(l:stdout_list, s:fdopen(l:fd_stdout, 'vp_pipe_close', 'vp_pipe_read', 'vp_pipe_write'))
    if a:npipe == 3
      call add(l:stderr_list, s:fdopen(l:fd_stderr, 'vp_pipe_close', 'vp_pipe_read', 'vp_pipe_write'))
    endif

    let l:hstdin = l:stdout_list[-1].fd
  endfor

  let l:proc = {}
  let l:proc.pid_list = l:pid_list
  let l:proc.pid = l:pid_list[-1]
  let l:proc.stdin = s:fdopen_pipes(l:stdin_list, 'vp_pipes_front_close', 'read_pipes', 'write_pipes')
  let l:proc.stdout = s:fdopen_pipes(l:stdout_list, 'vp_pipes_back_close', 'read_pipes', 'write_pipes')
  if a:npipe == 3
    let l:proc.stderr = s:fdopen_pipes(l:stderr_list, 'vp_pipes_back_close', 'read_pipes', 'write_pipes')
  endif
  let l:proc.get_winsize = s:funcref('vp_get_winsize')
  let l:proc.set_winsize = s:funcref('vp_set_winsize')
  let l:proc.kill = s:funcref('vp_kill')
  let l:proc.waitpid = s:funcref('vp_waitpid')
  let l:proc.is_valid = 1
  let l:proc.is_pty = 0

  return proc
endfunction"}}}

function! vimproc#pgroup_open(statements)"{{{
  if type(a:statements) == type('')
    return vimproc#parser#pgroup_open(a:statements)
  endif

  let l:proc = {}
  let l:proc.current_proc = vimproc#plineopen3(a:statements[0].statement)

  let l:proc.pid = l:proc.current_proc.pid
  let l:proc.pid_list = l:proc.current_proc.pid_list
  let l:proc.condition = a:statements[0].condition
  let l:proc.statements = a:statements[1:]
  let l:proc.stdin = s:fdopen_pgroup(l:proc, l:proc.current_proc.stdin, 'vp_pgroup_close', 'read_pgroup', 'write_pgroup')
  let l:proc.stdout = s:fdopen_pgroup(l:proc, l:proc.current_proc.stdout, 'vp_pgroup_close', 'read_pgroup', 'write_pgroup')
  let l:proc.stderr = s:fdopen_pgroup(l:proc, l:proc.current_proc.stderr, 'vp_pgroup_close', 'read_pgroup', 'write_pgroup')
  let l:proc.kill = s:funcref('vp_pgroup_kill')
  let l:proc.waitpid = s:funcref('vp_pgroup_waitpid')
  let l:proc.is_valid = 1

  return proc
endfunction"}}}

function! vimproc#ptyopen(args)"{{{
  if type(a:args) == type('')
    return vimproc#parser#ptyopen(a:args)
  endif

  if s:is_win
    let [l:pid, l:fd_stdin, l:fd_stdout] = s:vp_pipe_open(2, 0, 0, 0,
          \ s:convert_args(a:args))
    let l:ttyname = ''

    let l:proc = s:fdopen_pty(l:fd_stdin, l:fd_stdout, 'vp_pty_close', 'vp_pty_read', 'vp_pty_write')
  else
    let [l:pid, l:fd, l:ttyname] = s:vp_pty_open(winwidth(0)-5, winheight(0), s:convert_args(a:args))

    let l:proc = s:fdopen(l:fd, 'vp_pty_close', 'vp_pty_read', 'vp_pty_write')
  endif

  let l:proc.pid = l:pid
  let l:proc.ttyname = l:ttyname
  let l:proc.get_winsize = s:funcref('vp_get_winsize')
  let l:proc.set_winsize = s:funcref('vp_set_winsize')
  let l:proc.kill = s:funcref('vp_kill')
  let l:proc.waitpid = s:funcref('vp_waitpid')
  let l:proc.is_valid = 1
  let l:proc.is_pty = 1

  return l:proc
endfunction"}}}

function! vimproc#socket_open(host, port)"{{{
  let l:fd = s:vp_socket_open(a:host, a:port)
  return s:fdopen(l:fd, 'vp_socket_close', 'vp_socket_read', 'vp_socket_write')
endfunction"}}}

function! vimproc#kill(pid, sig)"{{{
  call s:libcall('vp_kill', [a:pid, a:sig])
endfunction"}}}

function! vimproc#decode_signal(signal)"{{{
  if a:signal == 2
    return 'SIGINT'
  elseif a:signal == 3
    return 'SIGQUIT'
  elseif a:signal == 4
    return 'SIGILL'
  elseif a:signal == 6
    return 'SIGABRT'
  elseif a:signal == 8
    return 'SIGFPE'
  elseif a:signal == 9
    return 'SIGKILL'
  elseif a:signal == 11
    return 'SIGSEGV'
  elseif a:signal == 13
    return 'SIGPIPE'
  elseif a:signal == 14
    return 'SIGALRM'
  elseif a:signal == 15
    return 'SIGTERM'
  elseif a:signal == 10
    return 'SIGUSR1'
  elseif a:signal == 12
    return 'SIGUSR2'
  elseif a:signal == 17
    return 'SIGCHLD'
  elseif a:signal == 18
    return 'SIGCONT'
  elseif a:signal == 19
    return 'SIGSTOP'
  elseif a:signal == 20
    return 'SIGTSTP'
  elseif a:signal == 21
    return 'SIGTTIN'
  elseif a:signal == 22
    return 'SIGTTOU'
  else
    return 'UNKNOWN'
  endif
endfunction"}}}

function! vimproc#write(filename, string, ...)"{{{
  if a:string == ''
    return
  endif

  let l:mode = get(a:000, 0,
        \ a:filename =~ '^>' ? 'a' : 'w')

  let l:filename = a:filename =~ '^>' ?
        \ a:filename[1:] : a:filename

  if l:filename ==# '/dev/null'
    " Nothing.
  elseif l:filename ==# '/dev/clip'
    " Write to clipboard.

    if l:mode =~ 'a'
      let @+ .= a:string
    else
      let @+ = a:string
    endif
  else
    " Write file.

    let l:mode = 'O_WRONLY | O_CREAT'
    if l:mode =~ 'a'
      " Append mode.
      let l:mode .= '| O_APPEND'
    endif

    let l:hfile = vimproc#fopen(l:filename, l:mode)
    call l:hfile.write(a:string)
    call l:hfile.close()
  endif
endfunction"}}}

function! s:close() dict"{{{
  if self.is_valid
    call self.f_close()
  endif

  let self.is_valid = 0
  let self.eof = 1
  let self.fd = -1
endfunction"}}}
function! s:read(...) dict"{{{
  let l:output = self.buffer
  if self.__eof
    return l:output
  endif

  let l:number = get(a:000, 0, -1)
  let l:timeout = get(a:000, 1, s:read_timeout)
  let [l:hd, l:eof] = self.f_read(l:number, l:timeout)
  let self.eof = l:eof
  let self.__eof = l:eof

  let l:output .= s:hd2str([l:hd])
  return l:output
endfunction"}}}
function! s:read_line() dict
  let l:output = ''
  let l:res = ''
  while l:res !~ '\r\?\n'
    let l:res = self.read(256)
    let l:output .= l:res
  endwhile

  let l:pos = match(l:output, '\v%(\r?\n|$)\zs')
  let l:line = matchstr(l:output[: l:pos - 1], '.\{-}\ze\r\?\n$')
  let self.buffer = l:output[l:pos :]
  let self.eof = (self.buffer != '') ? 0 : self.__eof

  return l:line
endfunction

function! s:write(str, ...) dict"{{{
  let l:timeout = get(a:000, 0, s:write_timeout)
  let l:hd = s:str2hd(a:str)
  return self.f_write(l:hd, l:timeout)
endfunction"}}}

function! s:fdopen(fd, f_close, f_read, f_write)"{{{
  return {
        \ 'fd' : a:fd,
        \ 'eof' : 0, '__eof' : 0, 'is_valid' : 1, 'buffer' : '',
        \ 'f_close' : s:funcref(a:f_close), 'f_read' : s:funcref(a:f_read), 'f_write' : s:funcref(a:f_write),
        \ 'close' : s:funcref('close'), 'read' : s:funcref('read'), 'write' : s:funcref('write'),
        \ 'read_line' : s:funcref('read_line'),
        \}
endfunction"}}}
function! s:fdopen_pty(fd_stdin, fd_stdout, f_close, f_read, f_write)"{{{
  return {
        \ 'eof' : 0, '__eof' : 0, 'is_valid' : 1, 'buffer' : '',
        \ 'fd_stdin' : a:fd_stdin, 'fd_stdout' : a:fd_stdout,
        \ 'f_close' : s:funcref(a:f_close), 'f_read' : s:funcref(a:f_read), 'f_write' : s:funcref(a:f_write), 
        \ 'close' : s:funcref('close'), 'read' : s:funcref('read'), 'write' : s:funcref('write')
        \}
endfunction"}}}
function! s:fdopen_pipes(fd, f_close, f_read, f_write)"{{{
  return {
        \ 'eof' : 0, '__eof' : 0, 'is_valid' : 1, 'buffer' : '',
        \ 'fd' : a:fd,
        \ 'f_close' : s:funcref(a:f_close),
        \ 'close' : s:funcref('close'), 'read' : s:funcref(a:f_read), 'write' : s:funcref(a:f_write)
        \}
endfunction"}}}
function! s:fdopen_pgroup(proc, fd, f_close, f_read, f_write)"{{{
  return {
        \ 'eof' : 0, '__eof' : 0, 'is_valid' : 1, 'buffer' : '',
        \ 'proc' : a:proc, 'fd' : a:fd,
        \ 'f_close' : s:funcref(a:f_close),
        \ 'close' : s:funcref('close'), 'read' : s:funcref(a:f_read), 'write' : s:funcref(a:f_write)
        \}
endfunction"}}}

function! s:garbage_collect()"{{{
  for pid in values(s:bg_processes)
    " Check processes.
    try
      let [l:cond, l:status] = s:waitpid(pid)
      " echomsg string([pid, l:cond, l:status])
      if l:cond !=# 'run'
        if l:cond !=# 'exit'
          " Kill process.
          " 15 == SIGTERM
          call vimproc#kill(pid, 15)
        endif

        call remove(s:bg_processes, pid)
      endif
    catch /waitpid() error:\|kill() error:/
      " Ignore error.
    endtry
  endfor
endfunction"}}}

"-----------------------------------------------------------
" UTILS

function! s:str2hd(str)
  return join(map(range(len(a:str)), 'printf("%02X", char2nr(a:str[v:val]))'), '')
endfunction

function! s:hd2str(hd)
  " Since Vim can not handle \x00 byte, remove it.
  " do not use nr2char()
  " nr2char(255) => "\xc3\xbf" (utf8)
  "
  " a:hd is a list because to avoid copying the value.
  return join(map(split(a:hd[0], '..\zs'), 'v:val == "00" ? "" : eval(''"\x'' . v:val . ''"'')'), '')
endfunction

function! s:str2list(str)
  return map(range(len(a:str)), 'char2nr(a:str[v:val])')
endfunction

function! s:list2str(lis)
  return s:hd2str(s:list2hd([a:lis]))
endfunction

function! s:hd2list(hd)
  return map(split(a:hd, '..\zs'), 'str2nr(v:val, 16)')
endfunction

function! s:list2hd(lis)
  return join(map(a:lis, 'printf("%02X", v:val)'), '')
endfunction

function! s:convert_args(args)"{{{
  if empty(a:args)
    return []
  endif

  return s:analyze_shebang(vimproc#get_command_name(a:args[0])) + a:args[1:]
endfunction"}}}

function! s:analyze_shebang(filename)"{{{
  if s:is_mac
    " Mac OS X's shebang support is incomplete. :-(
    if getfsize(a:filename) > 100000

      " Maybe a binary file.
      return [a:filename]
    endif
  elseif !s:is_win || '.'.fnamemodify(a:filename, ':e') !~?
        \ '^' . substitute($PATHEXT, ';', '$\\|^', 'g') . '$'
    return [a:filename]
  endif

  let l:lines = readfile(a:filename, '', 1)
  if empty(l:lines) || l:lines[0] !~ '^#!.\+'
    " Shebang not found.
    return [a:filename]
  endif

  " Get shebang line.
  let l:shebang = split(matchstr(l:lines[0], '^#!\zs.\+'))

  " Convert command name.
  if s:is_win && l:shebang[0] =~ '^/'
    let l:shebang[0] = vimproc#get_command_name(fnamemodify(l:shebang[0], ':t'))
  endif

  return l:shebang + [a:filename]
endfunction"}}}

"-----------------------------------------------------------
" LOW LEVEL API

augroup vimproc
  autocmd!
  autocmd VimLeave * call s:finalize()
  autocmd CursorHold * call s:garbage_collect()
augroup END

" Initialize.
let s:lasterr = []
let s:read_timeout = 100
let s:write_timeout = 100
let s:bg_processes = {}

function! s:libcall(func, args)"{{{
  " End Of Value
  let l:EOV = "\xFF"
  let l:args = empty(a:args) ? '' : (join(reverse(copy(a:args)), l:EOV) . l:EOV)
  let l:stack_buf = libcall(g:vimproc_dll_path, a:func, l:args)
  let l:result = split(l:stack_buf, '[\xFF]', 1)
  if !empty(l:result) && l:result[-1] != ''
    let s:lasterr = l:result
    let l:msg = vimproc#util#iconv(string(l:result), vimproc#util#termencoding(), &encoding)

    throw printf('proc: %s: %s', a:func, l:msg)
  endif
  return l:result[:-2]
endfunction"}}}

function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

function! s:print_error(string)
  echohl Error | echomsg a:string | echohl None
endfunction

" Get funcref.
function! s:funcref(funcname)
  return function(s:SID_PREFIX().a:funcname)
endfunction

function! s:finalize()
  if exists('s:dll_handle')
    call s:vp_dlclose(s:dll_handle)
  endif
endfunction

function! s:vp_dlopen(path)
  let [handle] = s:libcall('vp_dlopen', [a:path])
  return handle
endfunction

function! s:vp_dlclose(handle)
  call s:libcall('vp_dlclose', [a:handle])
endfunction

function! s:vp_file_open(path, flags, mode)
  let [l:fd] = s:libcall('vp_file_open', [a:path, a:flags, a:mode])
  return l:fd
endfunction

function! s:vp_file_close() dict
  if self.fd != 0
    call s:libcall('vp_file_close', [self.fd])
    let self.fd = 0
  endif
endfunction

function! s:vp_file_read(number, timeout) dict
  let self.buffer = ''
  let [l:hd, l:eof] = s:libcall('vp_file_read', [self.fd, a:number, a:timeout])
  let l:hd = self.buffer . l:hd
  return [l:hd, l:eof]
endfunction

function! s:vp_file_write(hd, timeout) dict
  let [l:nleft] = s:libcall('vp_file_write', [self.fd, a:hd, a:timeout])
  return l:nleft
endfunction

function! s:vp_pipe_open(npipe, hstdin, hstdout, hstderr, argv)"{{{
  if s:is_win
    let l:cmdline = ''
    for arg in a:argv
      let l:cmdline .= '"' . substitute(arg, '"', '\\"', 'g') . '" '
    endfor
    let [l:pid; l:fdlist] = s:libcall('vp_pipe_open',
          \ [a:npipe, a:hstdin, a:hstdout, a:hstderr, l:cmdline])
  else
    let [l:pid; l:fdlist] = s:libcall('vp_pipe_open',
          \ [a:npipe, a:hstdin, a:hstdout, a:hstderr, len(a:argv)] + a:argv)
  endif

  if a:npipe != len(l:fdlist)
    echoerr 'Bug behavior is detected!'
    echoerr printf('a:npipe = %d, a:argv = %s', a:npipe, string(a:argv))
    echoerr printf('l:fdlist = %s', string(l:fdlist))
  endif

  return [l:pid] + l:fdlist
endfunction"}}}

function! s:vp_pipe_close() dict
  if self.fd != 0
    call s:libcall('vp_pipe_close', [self.fd])
    let self.fd = 0
  endif
endfunction

function! s:vp_pipes_front_close() dict
  call self.fd[0].close()
endfunction

function! s:vp_pipes_back_close() dict
  call self.fd[-1].close()
endfunction

function! s:vp_pgroup_close() dict
  call self.fd.close()
endfunction

function! s:vp_pipe_read(number, timeout) dict
  if self.fd == 0
    return ['', 1]
  endif

  let [l:hd, l:eof] = s:libcall('vp_pipe_read', [self.fd, a:number, a:timeout])
  return [l:hd, l:eof]
endfunction

function! s:vp_pipe_write(hd, timeout) dict
  if self.fd == 0
    return 0
  endif

  let [l:nleft] = s:libcall('vp_pipe_write', [self.fd, a:hd, a:timeout])
  return l:nleft
endfunction

function! s:read_pipes(...) dict"{{{
  let l:number = get(a:000, 0, -1)
  let l:timeout = get(a:000, 1, s:read_timeout)

  if self.fd[-1].eof
    return ''
  endif

  let l:output = self.fd[-1].read(l:number, l:timeout)
  let self.eof = self.fd[-1].eof

  return l:output
endfunction"}}}

function! s:write_pipes(str, ...) dict"{{{
  let l:timeout = get(a:000, 0, s:write_timeout)

  if self.fd[0].eof
    return 0
  endif

  " Write data.
  let l:nleft = self.fd[0].write(a:str, l:timeout)
  let self.eof = self.fd[0].eof

  return l:nleft
endfunction"}}}

function! s:read_pgroup(...) dict"{{{
  let l:number = get(a:000, 0, -1)
  let l:timeout = get(a:000, 1, s:read_timeout)

  let l:output = ''
  let l:eof = 0

  if !self.fd.eof
    let l:output = self.fd.read(l:number, l:timeout)
  endif

  if self.proc.current_proc.stdout.eof && self.proc.current_proc.stderr.eof
    " Get status.
    let [l:cond, l:status] = self.proc.current_proc.waitpid()

    if empty(self.proc.statements)
          \ || (self.proc.condition ==# 'true' && l:status)
          \ || (self.proc.condition ==# 'false' && !l:status)
      let self.proc.statements = []

      " Exit.
      let self.proc.stdout.eof = 1
      let self.proc.stderr.eof = 1

      " Caching status.
      let self.proc.cond = l:cond
      let self.proc.status = l:status
    else
      " Initialize next statement.
      let l:proc = vimproc#plineopen3(self.proc.statements[0].statement)
      let self.proc.current_proc = l:proc

      let self.pid = l:proc.pid
      let self.pid_list = l:proc.pid_list
      let self.proc.condition = self.proc.statements[0].condition
      let self.proc.statements = self.proc.statements[1:]

      let self.proc.stdin = s:fdopen_pgroup(self.proc, l:proc.stdin, 'vp_pgroup_close', 'read_pgroup', 'write_pgroup')
      let self.proc.stdout = s:fdopen_pgroup(self.proc, l:proc.stdout, 'vp_pgroup_close', 'read_pgroup', 'write_pgroup')
      let self.proc.stderr = s:fdopen_pgroup(self.proc, l:proc.stderr, 'vp_pgroup_close', 'read_pgroup', 'write_pgroup')
    endif
  endif

  return l:output
endfunction"}}}

function! s:write_pgroup(str, ...) dict"{{{
  let l:timeout = get(a:000, 0, s:write_timeout)

  let l:nleft = 0
  if !self.fd.eof
    " Write data.
    let l:nleft = self.fd.write(a:str, l:timeout)
  endif

  return l:nleft
endfunction"}}}

if s:is_win
  " For Windows.
  function! s:vp_pty_open(width, height, argv)
    let l:cmdline = ''
    for arg in a:argv
      let l:cmdline .= '"' . substitute(arg, '"', '\\"', 'g') . '" '
    endfor
    let [l:pid, l:fd_stdin, l:fd_stdout, l:ttyname] = s:libcall('vp_pty_open',
          \ [a:width, a:height, l:cmdline])
    return [l:pid, l:fd_stdin, l:fd_stdout, l:ttyname]
  endfunction

  function! s:vp_pty_close() dict
    if self.fd_stdin != 0
      call s:libcall('vp_pipe_close', [self.fd_stdin])
      call s:libcall('vp_pipe_close', [self.fd_stdout])
      let self.fd_stdin = 0
      let self.fd_stdout = 0
    endif
  endfunction

  function! s:vp_pty_read(number, timeout) dict
    let [l:hd, l:eof] = s:libcall('vp_pipe_read', [self.fd_stdout, a:number, a:timeout])
    return [l:hd, l:eof]
  endfunction

  function! s:vp_pty_write(hd, timeout) dict
    let [l:nleft] = s:libcall('vp_pipe_write', [self.fd_stdin, a:hd, a:timeout])
    return l:nleft
  endfunction
else
  function! s:vp_pty_open(width, height, argv)
    let [l:pid, l:fd, l:ttyname] = s:libcall('vp_pty_open',
          \ [a:width, a:height, len(a:argv)] + a:argv)
    return [l:pid, l:fd, l:ttyname]
  endfunction

  function! s:vp_pty_close() dict
    call s:libcall('vp_pty_close', [self.fd])
  endfunction

  function! s:vp_pty_read(number, timeout) dict
    let [l:hd, l:eof] = s:libcall('vp_pty_read', [self.fd, a:number, a:timeout])
    return [l:hd, l:eof]
  endfunction

  function! s:vp_pty_write(hd, timeout) dict
    let [l:nleft] = s:libcall('vp_pty_write', [self.fd, a:hd, a:timeout])
    return l:nleft
  endfunction

endif

function! s:vp_get_winsize() dict
  let [width, height] = self.is_pty && !s:is_win
        \ s:libcall('vp_pty_get_winsize', [self.fd]) :
        \ [winwidth(0)-5, winheight(0)]

  return [width, height]
endfunction

function! s:vp_set_winsize(width, height) dict
  if s:is_win
    " Not implemented.
    return
  endif

  if self.is_pty
    call s:libcall('vp_pty_set_winsize', [self.fd, a:width-5, a:height])
  endif

  " Send SIGWINCH = 28 signal.
  call vimproc#kill(self.pid, 28)
endfunction

function! s:vp_kill(sig) dict
  if has_key(self, 'stdin')
    call self.stdin.close()
  endif
  if has_key(self, 'stdout')
    call self.stdout.close()
  endif
  if has_key(self, 'stderr')
    call self.stdout.close()
  endif
  if has_key(self, 'ttyname')
    call self.close()
  endif

  let self.is_valid = 0

  if has_key(self, 'pid_list')
    for pid in self.pid_list
      call vimproc#kill(pid, a:sig)
    endfor
  else
    call vimproc#kill(self.pid, a:sig)
  endif
endfunction

function! s:vp_pgroup_kill(sig) dict
  if has_key(self, 'stdin')
    call self.stdin.close()
  endif
  if has_key(self, 'stdout')
    call self.stdout.close()
  endif
  if has_key(self, 'stderr')
    call self.stdout.close()
  endif
  if has_key(self, 'ttyname')
    call self.close()
  endif

  call self.current_proc.kill(a:sig)

  let self.is_valid = 0
endfunction

function! s:waitpid(pid)
  try
    let [l:cond, l:status] = s:libcall('vp_waitpid', [a:pid])
    if l:cond ==# 'run'
      " Add process list.
      let s:bg_processes[a:pid] = a:pid

      let [l:cond, l:status] = ['exit', '0']
    endif

    let s:last_status = l:status
  catch /waitpid() error:/
    let [l:cond, l:status] = ['exit', '0']
  endtry

  return [l:cond, str2nr(l:status)]
endfunction

function! s:vp_waitpid() dict
  if has_key(self, 'stdin')
    call self.stdin.close()
  endif
  if has_key(self, 'stdout')
    call self.stdout.close()
  endif
  if has_key(self, 'stderr')
    call self.stdout.close()
  endif
  if has_key(self, 'ttyname')
    call self.close()
  endif

  let self.is_valid = 0

  while 1
    if has_key(self, 'pid_list')
      for pid in self.pid_list
        let [l:cond, l:status] = s:waitpid(pid)
      endfor
    else
      let [l:cond, l:status] = s:waitpid(self.pid)
    endif

    " echomsg string([l:cond, l:status])
    " For zombie process.
    if !(l:cond ==# 'signal' && vimproc#decode_signal(l:status) != 'UNKNOWN')
      break
    endif
  endwhile

  return [l:cond, l:status]
endfunction

function! s:vp_pgroup_waitpid() dict
  let self.is_valid = 0

  let [l:cond, l:status] = self.current_proc.waitpid()

  return [l:cond, str2nr(l:status)]
endfunction

function! s:vp_socket_open(host, port)
  let [socket] = s:libcall('vp_socket_open', [a:host, a:port])
  return socket
endfunction

function! s:vp_socket_close() dict
  call s:libcall('vp_socket_close', [self.fd])
  let self.is_valid = 0
endfunction

function! s:vp_socket_read(number, timeout) dict
  let [l:hd, l:eof] = s:libcall('vp_socket_read', [self.fd, a:number, a:timeout])
  return [l:hd, l:eof]
endfunction

function! s:vp_socket_write(hd, timeout) dict
  let [l:nleft] = s:libcall('vp_socket_write', [self.fd, a:hd, a:timeout])
  return l:nleft
endfunction

" Initialize.
if !exists('s:dll_handle')
  let s:dll_handle = s:vp_dlopen(g:vimproc_dll_path)
endif

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
" vim:foldmethod=marker:fen:sw=2:sts=2
