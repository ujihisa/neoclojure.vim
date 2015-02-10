" quickrun: runner/neoclojure
" Author:  ujihisa <ujihisa at gmail com>
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('neoclojure')
let s:CP = s:V.import('ConcurrentProcess')

let g:neoclojure_quickrun_default_project_dir =
      \ get(g:, 'neoclojure_quickrun_default_project_dir', '/tmp/.neoclojure-quickrun')

let s:runner = {}

augroup plugin-quickrun-neoclojure
augroup END

function! s:runner.validate()
  if !neoclojure#is_available()
    throw 'Needs lein and vimproc.'
  endif
endfunction

function! s:runner.run(commands, input, session)
  if !isdirectory(g:neoclojure_quickrun_default_project_dir)
    call mkdir(g:neoclojure_quickrun_default_project_dir)
  endif

  let fname = expand('%')
  let label = neoclojure#of(
        \ len(fname) ? fname : printf('%s/dummy.clj', g:neoclojure_quickrun_default_project_dir))

  let message = a:session.build_command('(do (require ''clojure.repl) (try (load-file "%S") (catch Exception e (clojure.repl/pst e))))')
  call s:CP.queue(label, [
        \ ['*writeln*', message],
        \ ['*read*', 'quickrun', 'user=>']])

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
  let label = neoclojure#of(a:fname)

  call s:CP.tick(label)
  let [out, err] = s:CP.takeout(label, 'quickrun')
  call session.output(out . (err ==# '' ? '' : printf('!!!%s!!!', err)))

  if s:CP.is_done(label, 'quickrun')
    autocmd! plugin-quickrun-neoclojure
    call session.finish(0)
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

" main -- executed only when this file is executed as like :source %
if expand("%:p") == expand("<sfile>:p")
  let runner = deepcopy(s:runner)
  let runner.name = 'neoclojure'
  let runner.kind = 'runner'
  call quickrun#module#register(runner, 1)
endif

let &cpo = s:save_cpo
unlet s:save_cpo
