if get(g:, 'neoclojure_autowarmup', 0)
  let p = neoclojure#of(expand('%'))
  call p.tick()
endif
