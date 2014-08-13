let s:save_cpo = &cpo
set cpo&vim

let s:source = {'name': 'neoclojure'}  " {{{1

function! s:source.available()
  return neoclojure#is_available()
endfunction

function! s:source.get_body(query)
  return 'done'
  let query = a:query
  let classpath = $CLASSPATH
  let $CLASSPATH = s:classpath()
  let pre = s:precode()
  try
    if query =~ '^#".*"$'
      let query = query[2 : -2]
    else
      let res = s:clj(printf('%s(doc %s)', pre, query))
      if res.stderr == '' && res.stdout != ''
        let body = res.stdout
        let query = matchstr(body, '^-*\n\zs.\{-}\ze\n')
        return query != '' ? {'body': body, 'query': query} : body
      endif
    endif
    let res = s:clj(printf('%s(find-doc "%s")', pre, escape(query, '"')))
    if res.stdout != ''
      return s:to_overview(res.stdout)
    endif
  finally
    let $CLASSPATH = classpath
  endtry
  throw printf('No document found for "%s"', query)
endfunction

function! s:source.opened(query)
  call s:syntax()
endfunction

function! s:source.get_keyword()
  let isk = &l:iskeyword
  setlocal iskeyword+=?,-,*,!,+,/,=,<,>,.,:
  let keyword = expand('<cword>')
  let &l:iskeyword = isk
  if &l:filetype ==# 'ref-clojure' && keyword =~ '.\.$'
    " This is maybe a period of the end of sentence.
    let keyword = keyword[: -2]
  endif
  return keyword
endfunction


" functions. {{{1
function! s:clj(code)
  return ref#system(ref#to_list(g:ref_clojure_cmd, '-'), a:code)
endfunction

function! s:to_overview(body)
  let parts = split(a:body, '-\{25}\n')[1 :]
  return map(parts, 'join(split(v:val, "\n")[0 : 1], "   ")')
endfunction

function! s:precode()
  let given = get(g:, 'ref_clojure_precode', '')
  \         . get(b:, 'ref_clojure_precode', '')
  return given ==# '' ?
        \ '(ns vim-ref (:use [clojure.repl :only (doc find-doc)]))' :
        \ given
endfunction

function! s:syntax()
  if exists('b:current_syntax') && b:current_syntax == 'ref-clojure'
    return
  endif

  syntax clear
  syntax match refClojureDelimiter "^-\{25}\n" nextgroup=refClojureFunc
  syntax match refClojureFunc "^.\+$" contained

  highlight default link refClojureDelimiter Delimiter
  highlight default link refClojureFunc Function

  let b:current_syntax = 'ref-clojure'
endfunction

function! ref#neoclojure#define()
  return copy(s:source)
endfunction

call ref#register_detection('clojure', 'neoclojure')

let &cpo = s:save_cpo
unlet s:save_cpo
