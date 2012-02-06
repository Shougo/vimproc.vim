scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

source spec/base.vim

Context Lexer.run()
  It tests lexer token
    let lex = vimproc#lexer#init_lexer('1234 5678')
    Should lex.advance()
    Should lex.token() == g:vimproc#lexer#token_type.int
    echomsg lex.token()

    Should lex.advance()
    Should lex.token() == g:vimproc#lexer#token_type.int
    echomsg lex.token()
  End

  It tests lexer value
    let lex = vimproc#lexer#init_lexer('1234 5678')
    Should lex.advance()
    Should lex.value() == 1234
    echomsg lex.value()

    Should lex.advance()
    Should lex.value() == 5678
    echomsg lex.value()
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
