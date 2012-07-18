" Tests for vesting.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Lexer.run()
  It tests lexer token
    let lex = vimproc#lexer#init_lexer('1234 5678')
    Should lex.advance()
    Should lex.token() == g:vimproc#lexer#token_type.int

    Should lex.advance()
    Should lex.token() == g:vimproc#lexer#token_type.int
  End

  It tests lexer value
    let lex = vimproc#lexer#init_lexer('1234 5678')
    Should lex.advance()
    Should lex.value() == 1234

    Should lex.advance()
    Should lex.value() == 5678
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
