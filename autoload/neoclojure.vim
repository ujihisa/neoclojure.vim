let g:neoclojure_lein = get(g:, 'neoclojure_lein', 'lein')

let s:V = vital#of('neoclojure')
let s:PM = s:V.import('ProcessManager')
let s:L = s:V.import('Data.List')
call s:V.load('Process')
let s:_SFILEDIR = expand('<sfile>:p:h:gs?\\?/?g')

let s:_ps = get(s:, '_ps', []) " Don't initialize when you reload for development

" TODO move this to vital
function! s:is_root_directory(path)
  if a:path ==# '/'
    return 1
  endif
  return (has('win32') || has('win64')) && a:path =~ '^[a-zA-Z]:[/\\]$'
endfunction

function! neoclojure#is_available()
  return s:V.Process.has_vimproc() && executable(g:neoclojure_lein)
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

function! neoclojure#of(fname)
  let [success, dirname] = neoclojure#project_root_path(a:fname)

  let cwd = getcwd()
  silent execute 'lcd' dirname
  if success
    let p = s:PM.of('neoclojure-' . dirname, printf('%s trampoline run -m clojure.main/repl', g:neoclojure_lein))
  else
    let p = s:PM.of('neoclojure-nonproject' , printf('%s run -m clojure.main/repl', g:neoclojure_lein))
  endif

  silent execute 'lcd' cwd

  if p.is_new()
    call p.reserve_wait(['.*=>'])
          \.reserve_writeln('(clojure.main/repl :prompt #(print "\nuser=>"))')
          \.reserve_wait(['user=>'])
          \.reserve_writeln(printf(
          \   '(load-file "%s/neoclojure.clj")',
          \   escape(s:_SFILEDIR, '"')))
          \.reserve_wait(['user=>'])
          \.reserve_writeln("(ns neoclojure)")
          \.reserve_wait(['user=>'])
    call add(s:_ps, p)
  endif

  return p
endfunction

" new
function! neoclojure#of(fname)
  let [success, dirname] = neoclojure#project_root_path(a:fname)
  if !success
    let dirname = '.'
  endif

  let cwd = getcwd()
  silent execute 'lcd' printf('%s/../clojure/', s:_SFILEDIR)
  let p = s:PM.of('neoclojure-' . dirname, printf('%s trampoline run -m clojure.main/repl', g:neoclojure_lein))
  silent execute 'lcd' cwd

  if p.is_new()
    call p.reserve_wait(['.*=>'])
          \.reserve_writeln('(clojure.main/repl :prompt #(print "\nuser=>"))')
          \.reserve_wait(['user=>'])
          \.reserve_writeln(printf(
          \   '(do (require ''neoclojure.core)(neoclojure.core/initialize "%s"))',
          \   escape(dirname, '"')))
          \.reserve_wait(['user=>'])
          \.reserve_writeln(printf(
          \   '(load-file "%s/neoclojure.clj")',
          \   escape(s:_SFILEDIR, '"')))
          \.reserve_wait(['user=>'])
          \.reserve_writeln("(ns neoclojure)")
          \.reserve_wait(['user=>'])
    call add(s:_ps, p)
  endif

  return p
endfunction

function! neoclojure#ns_declare(p, lines)
  let to_write = printf(
        \   '(neoclojure/find-ns-declare "%s")',
        \   escape(join(a:lines, "\n"), '"\'))
  call a:p.reserve_writeln(to_write)
        \.reserve_read(['user=>'])
  while 1 " blocking!
    let result = a:p.go_bulk()
    if result.done && len(result.err)
      return [1, '(ns dummy)', result.err]
    elseif result.done
      return [1, result.out, result.err]
    elseif result.fail
      call a:p.shutdown()
      return [0, 'Process is dead', '']
    endif
  endwhile
endfunction

" Deprecated
function! neoclojure#complete(findstart, base)
  echomsg 'neoclojure#complete() is deprecated. Please use equivalent neoclojure#complete#omni() instead.'
  return neoclojure#complete#omni(a:findstart, a:base)
endfunction

function! neoclojure#killall()
  for p in s:_ps
    call p.shutdown()
  endfor
  let s:_ps = []
endfunction

function! neoclojure#dev_quickrun()
  let p = neoclojure#of(expand('%'))
  " check if this file is under src as well

  if !p.is_idle()
    echoerr 'Busy. Try again.'
    return
  endif

  " let ns = printf('%s.%s',
  "       \ expand('%:p:h:t'),
  "       \ substitute(expand('%:t:r'), '_', '-', 'g'))
  call p.reserve_writeln(printf('(load-file "%s")', escape(expand('%:p'), '"')))
        \.reserve_read(['user=>'])

  while 1
    let result = p.go_part()
    if result.done
      echomsg string([result])
      return
    elseif has(result, 'part')
      echomsg string(['part', result])
    elseif result.fail
      echoerr 'Restarting...'
      return neoclojure#quickrun()
    endif
  endwhile
endfunction
