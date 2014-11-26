let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

function! s:suite.socket()
  call s:assert.equals(vimproc#host_exists(
        \ 'www.yahoo.com'), 1)
  call s:assert.equals(vimproc#host_exists(
        \ 'https://www.yahoo.com'), 1)
  call s:assert.equals(vimproc#host_exists(
        \ 'https://www.yahoo.com/hoge/piyo'), 1)

  let sock = vimproc#socket_open('www.yahoo.com', 80)
  call sock.write("GET / HTTP/1.0\r\n\r\n", 100)
  let res = ''
  let out = sock.read(-1, 100)
  while !sock.eof && out != ''
    let out = sock.read(-1, 100)
    let res .= out
  endwhile

  call s:assert.equals(sock.is_valid, 1)

  call sock.close()

  call s:assert.equals(sock.is_valid, 0)

  echo res
endfunction

" vim:foldmethod=marker:fen:
