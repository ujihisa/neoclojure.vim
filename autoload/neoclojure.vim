let g:neoclojure_lein = get(g:, 'neoclojure_lein', 'lein')

let s:V = vital#of('neoclojure')
let s:CP = s:V.import('ConcurrentProcess')
let s:L = s:V.import('Data.List')
let s:_SFILEDIR = expand('<sfile>:p:h:gs?\\?/?g')

let s:_ps = get(s:, '_ps', []) " Don't initialize when you reload for development

" TODO move this to vital
function! s:is_root_directory(path)
  if a:path ==# '/'
    return 1
  endif
  return (has('win32') || has('win64')) && a:path =~ '^[a-zA-Z]:[/\\]$'
endfunction

" Returns a tuple of (success/fail, fullpath of dir name)
" e.g. [0, '']
"      [1, '/home/ujihisa/aaa/bbb']
function! neoclojure#is_available()
  return s:CP.is_available() && executable(g:neoclojure_lein)
endfunction

function! neoclojure#project_root_path(fname)
  let dirname = fnamemodify(a:fname, ':p:h')
  while !s:is_root_directory(dirname)
    if filereadable(dirname . '/project.clj')
      return [1, dirname]
    endif
    let dirname = fnamemodify(dirname, ':p:h:h')
  endwhile
  return [0, '']
endfunction

function! neoclojure#of(fname) abort
  let [success, dirname] = neoclojure#project_root_path(a:fname)
  if !success
    let dirname = '.'
  endif

  let label = s:CP.of(
        \ printf('%s trampoline run -m clojure.main/repl', g:neoclojure_lein),
        \ printf('%s/../clojure/', s:_SFILEDIR),
        \ [
        \   ['*read*', '_', '.*=>\s*'],
        \   ['*writeln*', '(clojure.main/repl :prompt #(print "\nuser=>"))'],
        \   ['*read*', '_', 'user=>'],
        \   ['*writeln*', '(ns neoclojure (:require [neoclojure.core] [neoclojure.search]))'],
        \   ['*read*', '_', 'user=>'],
        \   ['*writeln*', printf(
        \     '(neoclojure.core/initialize "%s")',
        \     escape(dirname, '"'))],
        \   ['*read*', '_', 'user=>']])
  let s:_ps = s:L.uniq(s:_ps + [label])

  return label
endfunction

function! neoclojure#ns_declare(label, lines)
  let to_write = printf(
        \   '(neoclojure.search/find-ns-declare "%s")',
        \   escape(join(a:lines, "\n"), '"\'))
  call s:CP.queue(a:label, [
        \ ['*writeln*', to_write],
        \ ['*read*', 'ns_declare', 'user=>']])
  let [out, err, timedout_p] = s:CP.consume_all_blocking(a:label, 'ns_declare', 60)
  if len(err) || timedout_p
    return [1, '(ns dummy)', err]
  else
    return [1, out, err]
  endif
endfunction

" Deprecated
function! neoclojure#complete(findstart, base)
  echomsg 'neoclojure#complete() is deprecated. Please use equivalent neoclojure#complete#omni() instead.'
  return neoclojure#complete#omni(a:findstart, a:base)
endfunction

function! neoclojure#killall()
  for label in s:_ps
    call s:CP.shutdown(label)
  endfor
  let s:_ps = []
endfunction

function! neoclojure#warmup(fname) abort
  let label = neoclojure#of(a:fname)
  " of() does it, so no need to run tick()
  " call s:CP.tick(label)
endfunction

function! neoclojure#debug() abort
  let label = neoclojure#of(expand('%'))
  call s:CP.log_dump(label)
endfunction
