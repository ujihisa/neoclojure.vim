let s:PM = vital#of('vital').import('ProcessManager') " Just for now
let s:_SFILEDIR = expand('<sfile>:p:h')


function! s:java_instance_methods(p, ns_declare, partial_methodname)
  let p = a:p
  call p.reserve_writeln(printf(
        \ '(println (search "%s" "%s"))',
        \ escape(a:ns_declare, '"'),
        \ escape(a:partial_methodname, '"')))
        \.reserve_read(['user=>'])

  while 1 " yes it is blocking for now
    let result = p.go_bulk()
    echomsg string([result])
    if result.fail
      echomsg 'neoclojure: lein process had died. Restarting...'
      call p.shutdown()
      " TODO of() is required
      " return s:java_instance_methods(p, a:ns_declare, a:partial_methodname)

      return [0, {}]
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
  echo s:java_instance_methods('(ns hello (:import [java.util SortedMap]))', 'get')
  echo reltimestr(reltime(s:before))

  echo 'second'
  let s:before = reltime()
  echo s:java_instance_methods('(ns world (:import [java.net URI SocketException]))', 'get')
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
  let p = s:give_me_p('~/git/cloft2/client/src/cloft2/app.clj')

  let [success, dict] = s:java_instance_methods(p,
        \ '(ns hello (:import [org.bukkit.entity Player]))', '.get')
  if success
    echo dict
  else
    throw 'omg'
  endif
endfunction

function! s:give_me_p(fname)
  let [success, dirname] = neoclojure#project_root_path(a:fname)

  let cwd = getcwd()
  execute 'lcd' dirname
  if success
    let p = s:PM.of('neoclojure-' . dirname, 'lein trampoline run -m clojure.main/repl')
  else
    let p = s:PM.of('neoclojure-nonproject' , 'lein run -m clojure.main/repl')
  endif

  execute 'lcd' cwd

  if p.is_new()
    call p.reserve_wait(['.*=>'])
          \.reserve_writeln('(clojure.main/repl :prompt #(print "\nuser=>"))')
          \.reserve_wait(['user=>'])
          \.reserve_writeln(join(readfile(printf('%s/init.clj', s:_SFILEDIR)), ' '))
          \.reserve_wait(['user=>'])
  endif

  return p
endfunction

function! neoclojure#complete(findstart, base)
  let p = s:give_me_p(expand('%'))

  if a:findstart
    let line_before = getline('.')[0 : col('.') - 2]
    return match(line_before, '.*\zs\.\w*$')
  else
    if a:base =~ '^\.'
      let [success, dict] = s:java_instance_methods(p,
            \ '(ns hello #_(:import [org.bukkit.entity Player]))', a:base)
      if success
        let candidates = []
        for [k, v] in items(dict)
          call add(candidates, {'word': k, 'menu': join(v, ', ')})
        endfor
        return candidates
      else
        return []
      endif
    else
      return []
    endif
  endif
endfunction

" call s:main()
