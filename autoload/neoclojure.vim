let s:V = vital#of('neoclojure')
let s:PM = s:V.import('ProcessManager')
let s:L = s:V.import('Data.List')
let s:S = s:V.import('Data.String')
let s:_SFILEDIR = expand('<sfile>:p:h')


function! s:search(p, ns_declare, partial_methodname)
  let p = a:p
  call p.reserve_writeln(printf(
        \ '(println (search "%s" "%s"))',
        \ escape(a:ns_declare, '"'),
        \ escape(a:partial_methodname, '"')))
        \.reserve_read(['user=>'])

  while 1 " yes it is blocking for now
    let result = p.go_bulk()
    if result.fail
      call p.shutdown()
      " TODO of() is required
      " return s:search(p, a:ns_declare, a:partial_methodname)

      return [0, 'neoclojure: lein process had died. Please try again.']
    elseif result.done
      try
        let rtn = [1, eval(s:S.lines(result.out)[0])]
        return rtn " this let is vital for avoiding Vim script's bug
      catch
        return [0, string(result)]
      endtry
    endif
  endwhile
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

function! neoclojure#ns_declare(p, lines)
  call a:p.reserve_writeln(
        \ printf(
        \   '(let [first-expr (read-string "%s")] (if (= ''ns (first first-expr)) first-expr "(ns dummy)"))',
        \   escape(join(a:lines), '"')))
        \.reserve_read(['user=>'])
  while 1 " blocking!
    let result = a:p.go_bulk()
    if result.done && len(result.err)
      return [1, '(ns dummy)']
    elseif result.done
      return [1, result.out]
    elseif result.fail
      call a:p.shutdown()
      return [0, 'Process is dead']
    endif
  endwhile
endfunction

function! neoclojure#complete_timed(findstart, base)
  let t = reltime()
  let rtn = neoclojure#complete(a:findstart, a:base)
  echomsg string(reltimestr(reltime(t))) . 'sec'
  return rtn
endfunction

function! neoclojure#complete(findstart, base)
  let p = s:give_me_p(expand('%'))

  if a:findstart
    let line_before = getline('.')[0 : col('.') - 2]

    let instance_method = match(line_before, '.*\zs\.[^\s\(\)\[\]\{\}]*$')
    if instance_method != -1
      return instance_method
    endif

    let static_method = match(line_before, '\w\+/.*$')
    return static_method
  else
    " echomsg string([a:base])
    if a:base =~ '^\.\|\w\+/.*'
      let [success, ns_declare] = neoclojure#ns_declare(p, getline(1, '$'))
      if !success
        return []
      endif

      let [success, dict] = s:search(p, ns_declare, a:base)
      if success
        let candidates = []
        for [k, v] in items(dict)
          let rank = s:L.all('v:val =~ "^java\\.lang\\."', v) ? 0 : 1
          call add(candidates, {
                \ 'word': k, 'menu': join(v, ', '), 'rank': rank,
                \ 'icase': 1, 'kind': 'M'})
        endfor
        return s:L.sort_by(candidates, '-v:val["rank"]')
      else
        return []
      endif
    else
      return []
    endif
  endif
endfunction

function! neoclojure#test()
  let testfile = printf('%s/../test/src/cloft2/fast_dash.clj', s:_SFILEDIR)

  let p = s:give_me_p(testfile)

  let before = reltime()
  let [success, ns_dec] = neoclojure#ns_declare(p, readfile(testfile))
  if !success
    return 'process is dead'
  endif
  let expected = "(ns cloft2.fast-dash (:use [cloft2.lib :only (later sec)]) (:import [org.bukkit Bukkit Material]))\n\n"
  echo ['ns declare', ns_dec == expected ? 'ok' : 'wrong']
  echo ['ns declare took', reltimestr(reltime(before))]


  let before = reltime()
  let [success, dict] = s:search(p, ns_dec, '.getO')
  if success
    let expected_dict = {'.getOnlinePlayers': ['org.bukkit.Bukkit'], '.getOfflinePlayers': ['org.bukkit.Bukkit'], '.getOutputStream': ['java.lang.Process'], '.getOperators': ['org.bukkit.Bukkit'], '.getOfflinePlayer': ['org.bukkit.Bukkit'], '.getOnlineMode': ['org.bukkit.Bukkit']}
    echo ['instance methods', dict == expected_dict ? 'ok' : 'wrong']
    echo ['instance methods took', reltimestr(reltime(before))]
  else
    return 'instance method search failed'
  endif

  let [success, dict] = s:search(p, ns_dec, 'String/')
  if success
    let expect = {'String/valueOf': [''], 'String/format': [''], 'String/copyValueOf': ['']}
    echomsg string(['static methods', dict == expect])
  else
    return 'failed at instance method search'
  endif
  return 'success'
endfunction

echo neoclojure#test()
