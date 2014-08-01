" quickrun: runner/neoclojure
" Author:  ujihisa <ujihisa at gmail com>
let s:save_cpo = &cpo
set cpo&vim

let s:runner = {}

augroup plugin-quickrun-neoclojure
augroup END

function! s:runner.validate()
  if !neoclojure#is_available()
    throw 'Needs lein and vimproc.'
  endif
endfunction

function! s:runner.run(commands, input, session)
  let p = neoclojure#_give_me_p(expand('%'))
  " if !p.is_idle()
  "   echoerr 'Busy. Try again.'
  "   return
  " endif

  let message = a:session.build_command('(load-file "%S")')
  call p.reserve_writeln(message)
        \.reserve_read(['user=>'])

  let key = a:session.continue()

  let self._autocmd = 1
  let self._updatetime = &updatetime
  let &updatetime = 50
  augroup plugin-quickrun-neoclojure
    execute 'autocmd! CursorHold,CursorHoldI * call'
          \ printf('s:receive(%s, %s)', string(key), string(expand('%')))
  augroup END
endfunction

function! s:receive(key, fname)
  if s:_is_cmdwin()
    return 0
  endif
  call feedkeys(mode() ==# 'i' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')

  let session = quickrun#session(a:key)
  let p = neoclojure#_give_me_p(a:fname)

  let result = p.go_part()
  if result.fail
    call g:quickrun#V.Vim.Message.warn('The process is inactive. Restarting...')
    call p.shutdown()
    autocmd! plugin-quickrun-neoclojure
    call session.finish()
    return session.run()
  elseif has_key(result, 'part')
    call session.output(result.part.out . (result.part.err ==# '' ? '' : printf('!!!%s!!!', err)))
    return 0
  elseif result.done
    call session.output(result.out . (result.err ==# '' ? '' : printf('!!!%s!!!', err)))
    autocmd! plugin-quickrun-neoclojure
    call session.finish(1)
    return 1
  else
    return 0
  endif
endfunction

function! s:runner.sweep()
  if has_key(self, '_autocmd')
    autocmd! plugin-quickrun-neoclojure
  endif
  if has_key(self, '_updatetime')
    let &updatetime = self._updatetime
  endif
endfunction

function! quickrun#runner#neoclojure#new()
  return deepcopy(s:runner)
endfunction

" TODO use vital's
function! s:_is_cmdwin()
  return bufname('%') ==# '[Command Line]'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
