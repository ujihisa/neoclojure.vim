let s:V = vital#of('neoclojure')
let s:PM = s:V.import('ProcessManager')
let s:L = s:V.import('Data.List')
let s:S = s:V.import('Data.String')
let s:LX = s:V.import('Text.Lexer')
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

" TODO move this to vital
function! s:is_root_directory(path)
  if a:path ==# '/'
    return 1
  endif
  return (has('win32') || has('win64')) && a:path =~ '^[a-zA-Z]:[/\\]$'
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
          \.reserve_writeln(printf(
          \   '(load-file "%s/neoclojure.clj")',
          \   escape(s:_SFILEDIR, '"')))
          \.reserve_wait(['user=>'])
          \.reserve_writeln("(ns neoclojure)")
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

function! s:findstart(line_before)
  if a:line_before ==# ''
    return 0 " shows everything
  endif

  let lx = s:LX.lexer([
        \ ['id', '[[:alnum:]\$-]\+'],
        \ ['dot', '\.'],
        \ ['slash', '/'],
        \ ['spaces', '\s\+'],
        \ ['else', '.']])
  let tokens = reverse(lx.exec(a:line_before))

  if tokens[0].label == 'spaces' || tokens[0].label == 'else'
    return len(a:line_before)
  " elseif tokens[0].label == 'slash'
  "   let tokens = s:L.take_while('index(["id", "dot"], v:val.label) >= 0', tokens[1 :])
  "   return len(tokens) ? tokens[-1].col : -1
  else
    let tokens = s:L.take_while('v:val.label != "spaces" && v:val.label != "else"', tokens)
    return tokens[-1].col
  endif
endfunction

function! neoclojure#complete(findstart, base)
  let p = s:give_me_p(expand('%'))

  if a:findstart
    let line_before = getline('.')[0 : col('.') - 2]
    return s:findstart(line_before)
  else
    let [success, ns_declare] = neoclojure#ns_declare(p, getline(1, '$'))
    if !success
      return []
    endif

    let [success, dict] = s:search(p, ns_declare, a:base)
    if success
      let candidates = []
      for t in ['M', 'S', 'E', 'P']
        if !has_key(dict, t)
          continue
        endif
        for [k, v] in items(dict[t])
          let rank = s:L.all('v:val =~ "^java\\.lang\\."', v) ? 0 : 1
         call add(candidates, {
                \ 'word': k, 'menu': join(v, ', '), 'rank': rank,
                \ 'icase': 1, 'kind': t})
        endfor
      endfor
      return s:L.sort_by(candidates, '-v:val["rank"]')
    else
      return []
    endif
    else
  endif
endfunction

function! neoclojure#test()
  let testfile = printf('%s/../test/src/cloft2/fast_dash.clj', s:_SFILEDIR)

  let p = s:give_me_p(testfile)

  let before = reltime()
  let [success, ns_dec] = neoclojure#ns_declare(p, readfile(testfile))
  if !success
    echo 'Process is dead. Auto-restarting...'
    return neoclojure#test()
  endif
  let expected = "(ns cloft2.fast-dash (:use [cloft2.lib :only (later sec)]) (:import [org.bukkit Bukkit Material]))\n\n"
  echo ['ns declare', ns_dec == expected ? 'ok' : ns_dec]
  echo ['ns declare took', reltimestr(reltime(before))]


  let before = reltime()
  let [success, dict] = s:search(p, ns_dec, '.getO')
  if success
    unlet! expected
    let expected = {'P': {}, 'S': {}, 'E': {}, 'M': {'.getOnlinePlayers': ['org.bukkit.Bukkit'], '.getOfflinePlayers': ['org.bukkit.Bukkit'], '.getOutputStream': ['java.lang.Process'], '.getOperators': ['org.bukkit.Bukkit'], '.getOfflinePlayer': ['org.bukkit.Bukkit'], '.getOnlineMode': ['org.bukkit.Bukkit']}}
    echo ['instance methods', dict == expected ? 'ok' : dict]
    echo ['instance methods took', reltimestr(reltime(before))]
  else
    return 'instance method search failed'
  endif

  let [success, dict] = s:search(p, ns_dec, 'String/')
  if success
    let expected = {'P': {}, 'S': {'String/valueOf': [''], 'String/format': [''], 'String/copyValueOf': ['']}, 'E': {}, 'M': {}}
    echomsg string(['static methods', dict == expected ? 'ok' : dict])
  else
    return 'failed at instance method search'
  endif

  let [success, dict] = s:search(p, ns_dec, 'java.util.')
  let expected = {'P': {'java.util.concurrent.Callable': ['']}, 'S': {}, 'E': {}, 'M': {}}
  if success
    echomsg string(['java namespaces', dict == expected ? 'ok' : dict])
  else
    return 'failed at java namespaces'
  endif

  let [success, dict] = s:search(p, ns_dec, 'Thread$State/B')
  let expected = {'P': {}, 'S': {}, 'E': {'Thread$State/BLOCKED': ['java.lang']}, 'M': {}}
  if success
    echomsg string(['java enum constants', dict == expected ? 'ok' : dict])
  else
    return 'failed at java enum constants'
  endif

  return 'success'
endfunction

function! neoclojure#test_findstart()
  echo s:findstart('') == 0
  echo s:findstart(' ') == 1
  echo s:findstart('aaa b') == 4
  echo s:findstart('(.') == 1
  echo s:findstart('aaa .g') == 4
  echo s:findstart('aaa .g s/') == 7
endfunction

" main -- executed only when this file is executed as like :source %
if expand("%:p") == expand("<sfile>:p")
  call neoclojure#test_findstart()

  " echo neoclojure#test()
endif
