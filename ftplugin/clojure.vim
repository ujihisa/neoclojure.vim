if get(g:, 'neoclojure_autowarmup', 0) | call neoclojure#warmup(expand('%')) | endif
