let g:neoclojure_lein = get(g:, 'neoclojure_lein', 'lein')

let s:V = vital#of('neoclojure')
let s:PM = s:V.import('ProcessManager')
let s:L = s:V.import('Data.List')
let s:S = s:V.import('Data.String')
let s:LX = s:V.import('Text.Lexer')
call s:V.load('Process')
let s:_SFILEDIR = expand('<sfile>:p:h:gs?\\?/?g')

let s:_ps = get(s:, '_ps', []) " Don't initialize when you reload for development

function! s:search(p, ns_declare, partial_methodname)
  let p = a:p
  call p.reserve_writeln(printf(
        \ '(println (search "%s" "%s"))',
        \ escape(a:ns_declare, '"\'),
        \ escape(a:partial_methodname, '"\')))
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

function! neoclojure#_give_me_p(fname)
  let [success, dirname] = neoclojure#project_root_path(a:fname)

  let cwd = getcwd()
  silent execute 'lcd' dirname
  if success
    let p = s:PM.of('neoclojure-' . dirname, printf('%s trampoline run -m clojure.main/repl', g:neoclojure_lein))
  else
    let p = s:PM.of('neoclojure-nonproject' , printf('%s run -m clojure.main/repl', g:neoclojure_lein))
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
    call add(s:_ps, p)
  endif

  return p
endfunction

function! neoclojure#ns_declare(p, lines)
  let to_write = printf(
        \   '(let [first-expr (read-string "%s")] (if (= ''ns (first first-expr)) first-expr ''(ns dummy)))',
        \   escape(join(a:lines, "\n"), '"\'))
  call a:p.reserve_writeln(to_write)
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
  let p = neoclojure#_give_me_p(expand('%'))

  if a:findstart
    let line_before = getline('.')[0 : col('.') - 2]
    return s:findstart(line_before)
  else
    let [success, ns_declare] = neoclojure#ns_declare(p, getline(1, '$'))
    if !success
      return []
    endif
    echomsg string([ns_declare])

    let [success, table] = s:search(p, ns_declare, a:base)
    if !success
      return []
    endif

    let candidates = []
    for [kind, dict_t] in table
      for [k, v] in items(dict_t)
        let rank = s:L.all('v:val =~ "^java\\.lang\\."', v) ? 0 : 1
        call add(candidates, {
              \ 'word': k, 'menu': join(v, ', '), 'rank': rank,
              \ 'icase': 1, 'kind': kind})
      endfor
    endfor
    return s:L.sort_by(candidates, '-v:val["rank"]')
  endif
endfunction

function! neoclojure#killall()
  for p in s:_ps
    call p.shutdown()
  endfor
  let s:_ps = []
endfunction

function! neoclojure#test()
  if !neoclojure#is_available()
    return 'neoclojure#is_available() is false'
  endif

  let testfile = printf('%s/../test/src/cloft2/fast_dash.clj', s:_SFILEDIR)

  let p = neoclojure#_give_me_p(testfile)

  let before = reltime()
  let [success, ns_dec] = neoclojure#ns_declare(p, readfile(testfile))
  if !success
    echo 'Process is dead. Auto-restarting...'
    return neoclojure#test()
  endif
  let expected = "(ns cloft2.fast-dash (:use [cloft2.lib :only (later sec)]) (:import [org.bukkit Bukkit Material]))"
  echo ['ns declare', substitute(ns_dec, '\(\r\?\n\)*$', '', '') == expected ? 'ok' : ns_dec]
  echo ['ns declare took', reltimestr(reltime(before))]


  let before = reltime()
  let [success, table] = s:search(p, ns_dec, '.isF')
  if success
    unlet! expected
    let expected = [['M', {'.isFlammable': ['org.bukkit.Material']}], ['S', {}], ['P', {}], ['E', {}]]
    echo ['instance methods', table == expected ? 'ok' : table]
    echo ['instance methods took', reltimestr(reltime(before))]
  else
    return 'instance method search failed'
  endif

  let [success, table] = s:search(p, ns_dec, 'String/')
  if success
    let expected = [['M', {}], ['S', {'String/valueOf': [''], 'String/format': [''], 'String/copyValueOf': ['']}], ['P', {}], ['E', {}]]
    echomsg string(['static methods', table == expected ? 'ok' : table])
  else
    return 'failed at instance method search'
  endif

  let [success, table] = s:search(p, ns_dec, 'java.lang.String/')
  if success
    let expected = [['M', {}], ['S', {'java.lang.String/format': [''], 'java.lang.String/copyValueOf': [''], 'java.lang.String/valueOf': ['']}], ['P', {}], ['E', {}]]
    echomsg string(['static methods fqdn', table == expected ? 'ok' : table])
  else
    return 'failed at instance method search'
  endif

  let [success, table] = s:search(p, ns_dec, 'java.util.')
  let expected = [['M', {}], ['S', {}], ['P', {'java.util.concurrent.Callable': ['']}], ['E', {}]]
  if success
    echomsg string(['java namespaces', table == expected ? 'ok' : table])
  else
    return 'failed at java namespaces'
  endif

  let [success, table] = s:search(p, ns_dec, 'Thread$State/B')
  let expected = [['M', {}], ['S', {}], ['P', {}], ['E', {'Thread$State/BLOCKED': ['java.lang']}]]
  if success
    echomsg string(['java enum constants', table == expected ? 'ok' : table])
  else
    return 'failed at java enum constants'
  endif

  return 'done'
endfunction

function! neoclojure#test_findstart()
  echo s:findstart('') == 0
  echo s:findstart(' ') == 1
  echo s:findstart('aaa b') == 4
  echo s:findstart('(.') == 1
  echo s:findstart('aaa .g') == 4
  echo s:findstart('aaa .g s/') == 7
  echo s:findstart('aaa g.c.d.ws/k') == 4
endfunction

function! neoclojure#dev_quickrun()
  let p = neoclojure#_give_me_p(expand('%'))
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

" main -- executed only when this file is executed as like :source %
if expand("%:p") == expand("<sfile>:p")
  " call neoclojure#killall()

  " echo '## neoclojure#test_findstart()'
  " call neoclojure#test_findstart()

  echo '## neoclojure#test()'
  echo neoclojure#test()
endif
