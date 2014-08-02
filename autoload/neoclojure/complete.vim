let s:V = vital#of('neoclojure')
let s:LX = s:V.import('Text.Lexer')
let s:L = s:V.import('Data.List')
let s:S = s:V.import('Data.String')
let s:_SFILEDIR = expand('<sfile>:p:h:gs?\\?/?g')

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

function! s:search(p, ns_declare, partial_methodname)
  let p = a:p
  call p.reserve_writeln(printf(
        \ '(println (neoclojure/complete-candidates "%s" "%s"))',
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
        return [0, string([v:exception, result])]
      endtry
    endif
  endwhile
endfunction

function! neoclojure#complete#omni(findstart, base)
  let p = neoclojure#of(expand('%'))

  " dirty hack; it should be done in config or in neocomplete
  if exists('*neocomplete#initialize') && synIDattr(synIDtrans(synID(line("."), col("."), 1)), 'name') ==# "String"
    return -1
  endif

  if a:findstart
    let line_before = getline('.')[0 : col('.') - 2]
    return s:findstart(line_before)
  else
    let [success, ns_declare, warn] = neoclojure#ns_declare(p, getline(1, '$'))
    if len(warn)
      echomsg warn
    endif
    if !success
      return []
    endif

    let [success, table] = s:search(p, ns_declare, a:base)
    if !success
      echomsg table
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

function! neoclojure#complete#test()
  if !neoclojure#is_available()
    return 'neoclojure#is_available() is false'
  endif

  let testfile = printf('%s/../../test/src/cloft2/fast_dash.clj', s:_SFILEDIR)

  let p = neoclojure#of(testfile)

  let before = reltime()
  let [success, ns_dec, warn] = neoclojure#ns_declare(p, readfile(testfile))
  if !success
    echo 'Process is dead. Auto-restarting...'
    return neoclojure#test()
  endif
  let expected = "(ns cloft2.fast-dash (:use [cloft2.lib :only (later sec)]) (:import [org.bukkit Bukkit Material]))"
  echo ['ns declare', substitute(ns_dec, '\(\r\?\n\)*$', '', '') == expected ? 'ok' : ns_dec, warn]
  echo ['ns declare took', reltimestr(reltime(before))]
  unlet! expected


  let before = reltime()
  let [success, table] = s:search(p, ns_dec, '.isF')
  if success
    let expected = [['M', {'.isFlammable': ['org.bukkit.Material']}], ['S', {}], ['P', {}], ['E', {}]]
    echo ['instance methods', table == expected ? 'ok' : table]
    echo ['instance methods took', reltimestr(reltime(before))]
  else
    return printf('instance method search failed: %s', table)
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

function! neoclojure#complete#test_findstart()
  echo s:findstart('') == 0
  echo s:findstart(' ') == 1
  echo s:findstart('aaa b') == 4
  echo s:findstart('(.') == 1
  echo s:findstart('aaa .g') == 4
  echo s:findstart('aaa .g s/') == 7
  echo s:findstart('aaa g.c.d.ws/k') == 4
endfunction

" main -- executed only when this file is executed as like :source %
if expand("%:p") == expand("<sfile>:p")
  " call neoclojure#killall()

  " echo '## neoclojure#test_findstart()'
  " call neoclojure#test_findstart()

  echo '## neoclojure#complete#test()'
  echo neoclojure#complete#test()
endif
