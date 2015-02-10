let s:save_cpo = &cpo
set cpo&vim

" * queries: [(QueueLabel, QueueBody)]
" * logs: [(String, String, String)] stdin, stdout, stderr
" * vp: vimproc dict
" * buffer_out, buffer_err: String
"     * current buffered vp output/error
" * vars: dict
let s:_process_info = {}

function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:L = s:V.import('Data.List')
  let s:S = s:V.import('Data.String')
  let s:P = s:V.import('Process')
endfunction

function! s:_vital_depends() abort
  return ['Data.List', 'Data.String', 'Process']
endfunction

function! s:is_available() abort
  return s:P.has_vimproc()
endfunction

" supervisor strategy
" * Failed to spawn the process: exception
" * The process has been dead: start from scratch silently
function! s:of(command, dir, initial_queries) abort
  let label = sha256(printf('%s--%s--%s', a:command, a:dir, join(a:initial_queries, ';')))

  " Reset if the process is dead
  if has_key(s:_process_info, label)
    if get(s:_process_info[label].vp.checkpid(), 0, '') !=# 'run'
      call remove(s:_process_info, label)
    endif
  endif

  if !has_key(s:_process_info, label)
    let cwd = getcwd()
    execute 'chdir' a:dir
    try
      let vp = vimproc#popen3(a:command)
    finally
      execute 'chdir' cwd
    endtry

    let s:_process_info[label] = {
          \ 'logs': [], 'queries': a:initial_queries, 'vp': vp,
          \ 'buffer_out': '', 'buffer_err': '', 'vars': {}}
  endif

  return label
endfunction

function! s:_split_at_last_newline(str) abort
  if len(a:str) == 0
    return ['', '']
  endif

  let xs = split(a:str, ".*\n\\zs", 1)
  if len(xs) >= 2
    return [xs[0], xs[1]]
  else
    return ['', a:str]
  endif
endfunction

function! s:tick(label) abort
  let pi = s:_process_info[a:label]
  if len(pi.queries)
    let qlabel = pi.queries[0][0]

    if qlabel ==# '*read*'
      let rname = pi.queries[0][1]
      let rtil = pi.queries[0][2]

      let [out, err] = [pi.vp.stdout.read(), pi.vp.stderr.read()]
      call add(pi.logs, ['', out, err])

      " stdout: store into vars and buffer_out
      if !has_key(pi.vars, rname)
        let pi.vars[rname] = ['', '']
      endif
      let [left, right] = s:_split_at_last_newline(pi.buffer_out . out)
      let pi.vars[rname][0] .= left
      let pi.buffer_out = right

      " stderr: directly store into buffer_err
      let pi.buffer_err .= err

      let pattern = "\\(^\\|\n\\)" . rtil . '$'
      " wait ended.
      if pi.buffer_out =~ pattern
        if rname !=# '_'
          let pi.vars[rname][0] .= s:S.substitute_last(pi.buffer_out, pattern, '')
          let pi.vars[rname][1] = pi.buffer_err
        endif

        call remove(pi.queries, 0)
        let pi.buffer_out = ''
        let pi.buffer_err = ''

        call s:tick(a:label)
      endif
    elseif qlabel ==# '*writeln*'
      let wbody = pi.queries[0][1]
      call pi.vp.stdin.write(wbody . "\n")
      call remove(pi.queries, 0)

      call add(pi.logs, [wbody . "\n", '', ''])

      call s:tick(a:label)
    else
      " must not happen
      throw printf("ConcurrentProcess: must not happen")
    endif
  endif
endfunction

function! s:takeout(label, varname) abort
  let pi = s:_process_info[a:label]

  if has_key(pi.vars, a:varname)
    let memo = pi.vars[a:varname]
    call remove(pi.vars, a:varname)
    return memo
  else
    return ['', '']
  endif
endfunction

function! s:is_done(label, rname) abort
  return s:L.all(
        \ printf('v:val[0] ==# "*read*" && v:val[1] !=# %s', string(a:rname)),
        \ s:_process_info[a:label].queries)
endfunction

function! s:queue(label, queries) abort
  let s:_process_info[a:label].queries += a:queries
endfunction

" Just to wipe out the log
function! s:log_clear(label) abort
  let s:_process_info[a:label].logs = []
endfunction

" Print out log, and wipe out the log
function! s:log_dump(label) abort
  echomsg '-----------------------------'
  for [stdin, stdout, stderr] in s:_process_info[a:label].logs
    echon stdin
    echon stdout
    if stderr
      echon printf('!!!%s!!!', stderr)
    endif
  endfor
  let s:_process_info[a:label].logs = []
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0:
