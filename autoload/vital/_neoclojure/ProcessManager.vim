let s:save_cpo = &cpo
set cpo&vim

let s:_processes = {}

function! s:_vital_loaded(V)
  let s:V = a:V
  let s:Prelude = s:V.import('Prelude')
  let s:S = s:V.import('Data.String')
  let s:P = s:V.import('Process')
endfunction

function! s:_vital_depends()
  return ['Data.String', 'Process']
endfunction

function! s:is_available()
  return s:P.has_vimproc()
endfunction

function! s:touch(name, cmd)
  if has_key(s:_processes, a:name)
    return 'existing'
  else
    let p = vimproc#popen3(a:cmd)
    let s:_processes[a:name] = p
    return 'new'
  endif
endfunction

function! s:_stop(i, ...)
  let p = s:_processes[a:i]
  call p.kill(get(a:000, 0, 0) ? g:vimproc#SIGKILL : g:vimproc#SIGTERM)
  " call p.waitpid()
  call p.checkpid()
  unlet s:_processes[a:i]
  unlet s:state[a:i]
endfunction

function! s:term(i)
  return s:_stop(a:i, 0)
endfunction

function! s:kill(i)
  return s:_stop(a:i, 1)
endfunction

function! s:read(i, endpatterns)
  return s:read_wait(a:i, 0.05, a:endpatterns)
endfunction

let s:state = {}

function! s:read_wait(i, wait, endpatterns)
  if !has_key(s:_processes, a:i)
    throw printf("ProcessManager doesn't know about %s", a:i)
  endif

  let p = s:_processes[a:i]

  if s:status(a:i) ==# 'inactive'
    let s:state[a:i] = 'inactive'
    return [p.stdout.read(), p.stderr.read(), 'inactive']
  endif

  let out_memo = ''
  let err_memo = ''
  let lastchanged = reltime()
  while 1
    let [x, y] = [p.stdout.read(), p.stderr.read()]
    if x ==# '' && y ==# ''
      if str2float(reltimestr(reltime(lastchanged))) > a:wait
        let s:state[a:i] = 'reading'
        return [out_memo, err_memo, 'timedout']
      endif
    else
      let lastchanged = reltime()
      let out_memo .= x
      let err_memo .= y
      for pattern in a:endpatterns
        if out_memo =~ ("\\(^\\|\n\\)" . pattern)
          let s:state[a:i] = 'idle'
          return [s:S.substitute_last(out_memo, pattern, ''), err_memo, 'matched']
        endif
      endfor
    endif
  endwhile
endfunction

function! s:state(i)
  return get(s:state, a:i, 'undefined')
endfunction

function! s:write(i, str)
  if !has_key(s:_processes, a:i)
    throw printf("ProcessManager doesn't know about %s", a:i)
  endif
  if s:status(a:i) ==# 'inactive'
    return 'inactive'
  endif

  let p = s:_processes[a:i]
  call p.stdin.write(a:str)

  return 'active'
endfunction

function! s:writeln(i, str)
  return s:write(a:i, a:str . "\n")
endfunction

function! s:status(i)
  if !has_key(s:_processes, a:i)
    throw printf("ProcessManager doesn't know about %s", a:i)
  endif
  let p = s:_processes[a:i]
  " vimproc.kill isn't to stop but to ask for the current state.
  " return p.kill(0) ? 'inactive' : 'active'
  " ... checkpid() checks if the process is running AND does waitpid() in C,
  " so it solves zombie processes.
  return get(p.checkpid(), 0, '') ==# 'run'
        \ ? 'active'
        \ : 'inactive'
endfunction

function! s:debug_processes()
  return s:_processes
endfunction

" ------------ Experimental version 2 ------------
let s:_processes2 = {}

function! s:of(label, command)
  let p = get(s:_processes2, a:label)
  if s:Prelude.is_dict(p)
    return p
  endif

  unlet! p
  call s:touch(a:label, a:command)
  let p = {
        \ 'label': a:label,
        \ '*mailbox*': ['*new*'],
        \ '*buffer*': ['', ''],
        \ 'is_new': function('s:is_new'),
        \ 'is_idle': function('s:is_idle'),
        \ 'shutdown': function('s:shutdown'),
        \ 'reserve_wait': function('s:reserve_wait'),
        \ 'reserve_writeln': function('s:reserve_writeln'),
        \ 'reserve_read': function('s:reserve_read'),
        \ 'go_bulk': function('s:go_bulk'),
        \ 'go_part': function('s:go_part')}
  let s:_processes2[a:label] = p
  return p
endfunction

function! s:is_new() dict
  return self['*mailbox*'] ==# ['*new*']
endfunction

function! s:is_idle() dict
  return empty(self['*mailbox*'])
endfunction

function! s:shutdown() dict
  call s:kill(self.label)
  unlet! s:_processes2[self.label]
endfunction

function! s:reserve_wait(endpatterns) dict
  call s:_reserve(self, 'wait', a:endpatterns)
  return self
endfunction

function! s:reserve_writeln(line) dict
  call s:_reserve(self, 'writeln', a:line)
  return self
endfunction

function! s:reserve_read(endpatterns) dict
  call s:_reserve(self, 'read', a:endpatterns)
  return self
endfunction

function! s:_reserve(self, key, value)
  if a:self['*mailbox*'] ==# ['*new*']
    let a:self['*mailbox*'] = [[a:key, a:value]]
  else
    call add(a:self['*mailbox*'], [a:key, a:value])
  endif
endfunction

function! s:_trigger(self)
  let [msgkey, msgvalue] = a:self['*mailbox*'][0]
  if msgkey ==# 'writeln'
    call s:writeln(a:self.label, msgvalue)
    call remove(a:self['*mailbox*'], 0)
    return s:_trigger(a:self)
  elseif msgkey ==# 'wait'
    let [_, _, t] = s:read(a:self.label, msgvalue)
    if t ==# 'matched'
      call remove(a:self['*mailbox*'], 0)
    endif
    return {'done': 0, 'fail': 0}
  elseif msgkey ==# 'read'
    let [out, err, t] = s:read(a:self.label, msgvalue)
    if t ==# 'matched'
      call remove(a:self['*mailbox*'], 0)
      let out = a:self['*buffer*'][0] . out
      let err = a:self['*buffer*'][1] . err
      return {'done': 1, 'fail': 0, 'out': out, 'err': err}
    else
      let out .= a:self['*buffer*'][0]
      let err .= a:self['*buffer*'][1]
      return {'done': 0, 'fail': 0}
    endif
  endif
endfunction

function! s:go_bulk() dict
  return s:_go('bulk', self)
endfunction

function! s:go_part() dict
  return s:_go('part', self)
endfunction

function! s:_go(bulk_or_part, self)
  let self = a:self
  if self.is_idle()
    throw 'Vital.ProcessManager: go has nothing to do'
  endif
  let [msgkey, msgvalue] = self['*mailbox*'][0]

  let state = s:state(self.label)
  " echomsg string(['state', state, 'msg', msgkey, msgvalue, 'mailbox', self['*mailbox*']])
  if state ==# 'inactive'
    let result = {'done': 0, 'fail': 1}
    return result

  elseif state ==# 'reading' && msgkey ==# 'writeln'
    throw 'Must not happen!!!!!!!!!!!!!1'

  elseif state ==# 'reading' && msgkey ==# 'wait'
    call s:read(self.label, msgvalue)
    let result = {'done': 0, 'fail': 0}
    return result

  elseif state ==# 'reading' && msgkey ==# 'read'
    let [out, err, _] = s:read(self.label, msgvalue)
    if a:bulk_or_part == 'bulk'
      let self['*buffer*'][0] .= out
      let self['*buffer*'][1] .= err
      let result = {'done': 0, 'fail': 0}
    else " 'part'
      let result = {'done': 0, 'fail': 0, 'part': {'out': out, 'err': err}}
    endif
    return result

  elseif state ==# 'undefined'
    return s:_trigger(self)

  elseif state ==# 'idle'
    " idle == current message processing is done. finish it.
    if msgkey ==# 'writeln'
      return s:_trigger(self)
    elseif msgkey ==# 'wait'
      let result = {'done': 0, 'fail': 0}
      call remove(self['*mailbox*'], 0)
      return self.go_bulk()
    elseif msgkey ==# 'read'
      let out = self['*buffer*'][0]
      let err = self['*buffer*'][1]
      let self['*buffer*'] = ['', '']
      call remove(self['*mailbox*'], 0)
      let result = {'done': 1, 'fail': 0, 'out': out, 'err': err}
      return result
    endif
  else
    throw printf('Vital.ProcessManager: Must not happen: %s', state)
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0:
