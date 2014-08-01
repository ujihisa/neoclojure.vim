if get(g:, 'neoclojure_autowarmup', 0)
  let p = neoclojure#_give_me_p(expand('%'))
  call p.tick()
endif
