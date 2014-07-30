# neoclojure.vim

This is under development!

* Java method-name completion works (type `(.` in your clojure buffer)
    * no automatic `import` insertion yet
    * `(ns ...)` has to be located as the first expression of the file

## Requirement

* [leiningen](http://leiningen.org/)
* [vimproc.vim](https://github.com/Shougo/vimproc.vim)
  * Recommended [ichizok's fork improve-readwrite branch](https://github.com/ichizok/vimproc.vim/tree/improve-readwrite) + [additional patch](https://gist.github.com/ujihisa/4666b417034040295828) for speed.

Optional dependency plugins

* [neocomplete.vim](https://github.com/Shougo/neocomplete.vim)
* NOT YET -- [unite.vim](https://github.com/Shougo/unite.vim)

## Installation

~/.vimrc

```vim
augroup vimrc-neoclojure
  autocmd!
  autocmd FileType clojure setlocal omnifunc=neoclojure#complete
augroup END
```

## License

GPL version 3 or any later version
Copyright (c) Tatsuhiro Ujihisa
