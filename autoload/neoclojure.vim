let s:PM = vital#of('vital').import('ProcessManager') " Just for now

function! s:search(ns_declare, partial_methodname)
  let p = s:PM.of('search', 'clojure-1.6')
  if p.is_new()
    call p.reserve_wait(['user=>'])
          \.reserve_writeln('(clojure.main/repl :prompt #(print "\nuser=>"))')
          \.reserve_wait(['user=>'])
          \.reserve_writeln(join(readfile(printf('%s/init.clj', expand('<sfile>:p:h'))), ' '))
          \.reserve_wait(['user=>'])
  endif
  call p.reserve_writeln(printf(
        \ '(search "%s" "%s")',
        \ escape(a:ns_declare, '"'),
        \ escape(a:partial_methodname, '"')))
        \.reserve_read(['user=>'])

  while 1 " yes it is blocking for now
    let result = p.go_bulk()
    if result.fail
      call p.shutdown()
      return s:search(a:ns_declare, a:partial_methodname)
    elseif result.done
      return result.out
    endif
  endwhile
endfunction

" just for now
echo 'first'
let s:before = reltime()
echo s:search('(ns hello (:import [java.util SortedMap]))', 'get')
echo reltimestr(reltime(s:before))

echo 'second'
let s:before = reltime()
echo s:search('(ns world (:import [java.net URI SocketException]))', 'get')
echo reltimestr(reltime(s:before))
