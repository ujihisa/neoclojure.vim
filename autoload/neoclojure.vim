let s:PM = vital#of('vital').import('ProcessManager') " Just for now
let s:_SFILEDIR = expand('<sfile>:p:h')


" TODO this always succeeds
function! s:search(p, ns_declare, partial_methodname)
  let p = a:p
  if p.is_new()
    call p.reserve_wait(['.*=>'])
          \.reserve_writeln('(clojure.main/repl :prompt #(print "\nuser=>"))')
          \.reserve_wait(['user=>'])
          \.reserve_writeln(join(readfile(printf('%s/init.clj', s:_SFILEDIR)), ' '))
          \.reserve_wait(['user=>'])
  endif
  call p.reserve_writeln(printf(
        \ '(println (search "%s" "%s"))',
        \ escape(a:ns_declare, '"'),
        \ escape(a:partial_methodname, '"')))
        \.reserve_read(['user=>'])

  while 1 " yes it is blocking for now
    let result = p.go_bulk()
    if result.fail
      echomsg 'neoclojure: lein process had died. Restarting...'
      call p.shutdown()
      " TODO of() is required
      " return s:search(p, a:ns_declare, a:partial_methodname)

      return [0, '']
    elseif result.done
      " return [1, result.out]
      return [1, eval(split(result.out, "\n")[0])]
    endif
  endwhile
endfunction

function! s:_old_main()
  " just for now
  echo 'first'
  let s:before = reltime()
  echo s:search('(ns hello (:import [java.util SortedMap]))', 'get')
  echo reltimestr(reltime(s:before))

  echo 'second'
  let s:before = reltime()
  echo s:search('(ns world (:import [java.net URI SocketException]))', 'get')
  echo reltimestr(reltime(s:before))
endfunction

function! neoclojure#project_root_path(fname)
  let dirname = fnamemodify(a:fname, ':p:h')
  while dirname !=# '/' " TODO windows?
    if filereadable(dirname . '/project.clj')
      return [1, dirname]
    endif
    let dirname = fnamemodify(dirname, ':p:h:h')
  endwhile
  return [0, '']
endfunction

function! s:main()
  let [success, dirname] = neoclojure#project_root_path('~/git/cloft2/client/src/cloft2/app.clj')
  if success
    " TODO this should be done in PM
    let cwd = getcwd()
    execute 'lcd' dirname
    let p = s:PM.of('neoclojure-' . dirname, 'lein repl')
    execute 'lcd' cwd

    " OK, p is ready.
    let [success, dict] = s:search(p,
          \ '(ns hello (:import [org.bukkit.entity Player]))', 'getL')
    if success
      echo dict
    endif
  endif
endfunction

call s:main()
