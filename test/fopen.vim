let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

let g:filename = 'test.txt'

function! s:suite.before_each()
  call writefile(['foo', 'bar'], g:filename, 'b')
endfunction

function! s:suite.after_each()
  if filereadable(g:filename)
    call delete(g:filename)
  endif
endfunction

function! s:suite.fopen()
  let file = vimproc#fopen(g:filename, 'O_RDONLY', 0)
  let res = file.read()

  call s:assert.true(file.is_valid)

  call file.close()

  call s:assert.false(file.is_valid)

  call s:assert.equals(
        \ readfile(g:filename),
        \ split(res, '\r\n\|\r\|\n'))

  let file = vimproc#fopen(g:filename, 'O_RDONLY', 0)
  let res2 = file.read_lines()

  call s:assert.true(file.is_valid)

  call file.close()

  call s:assert.false(file.is_valid)

  call s:assert.equals(
        \ readfile(g:filename, 'b'), res2)

  let file = vimproc#fopen(g:filename, 'O_RDONLY', 0)
  let res2 = []
  while !file.eof
    let res2 += [file.read_line()]
  endwhile

  call s:assert.true(file.is_valid)

  call file.close()

  call s:assert.false(file.is_valid)

  call s:assert.equals(readfile(g:filename), res2)
endfunction

" vim:foldmethod=marker:fen:
