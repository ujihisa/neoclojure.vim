function! unite#sources#outline#clojure#outline_info()
  return s:outline_info
endfunction

let s:Util = unite#sources#outline#import('Util')
let s:S = vital#of('neoclojure').import('Data.String')

"-----------------------------------------------------------------------------
" Outline Info

let s:outline_info = {
      \ 'heading-1': '^\s*;\+\s*[-=]\{10,}\s*$',
      \ 'heading'  : '^\s*(def\S*\s*',
      \
      \ 'skip': { 'header': '^;' },
      \ 'highlight_rules': [
      \   {'name': 'def', 'pattern': '/(def\S*/', 'highlight': 'Special'},
      \   {'name': 'def', 'pattern': '/\[.*/', 'highlight': 'Comment'},
      \ ],
      \}


function! s:outline_info.extract_headings(context)
  if a:context.trigger != 'user'
    return
  endif

  " a:context.buffer.path is relative path which doesn't work with clojure
  let fname = expand('%:p')
  let p = neoclojure#of(fname)

  call p.reserve_writeln(printf(
        \ '(do (require ''neoclojure.unite-outline) (neoclojure.unite-outline/run "%s"))',
        \ escape(fname, '"')))
        \.reserve_read(['user=>'])
  while 1
    let result = p.go_bulk()
    if result.done
      break
    elseif result.fail
      throw 'omg'
      return []
    endif
  endwhile

  let rtn = eval(s:S.lines(result.out)[0])
  return rtn
endfunction
