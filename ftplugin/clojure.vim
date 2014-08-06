if get(g:, 'neoclojure_autowarmup', 0) | call neoclojure#of(expand('%')).tick() | endif
