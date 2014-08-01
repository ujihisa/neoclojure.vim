# neoclojure.vim

This is under development!

* Java method-name completion works (type `(.` in your clojure buffer)
    * no automatic `import` insertion yet
    * `(ns ...)` has to be located as the first expression of the file

## Requirement

* [leiningen](http://leiningen.org/)
* [vimproc.vim](https://github.com/Shougo/vimproc.vim)
  * Recommended [additional patch](https://gist.github.com/ujihisa/4666b417034040295828) for speed.

Optional dependency plugins

* [neocomplete.vim](https://github.com/Shougo/neocomplete.vim)
    * If you don't have neocomplete.vim, use omni-complete
      `<C-x><C-o>` to trigger manual completion.
* NOT YET -- [unite.vim](https://github.com/Shougo/unite.vim)

## Installation

~/.vimrc

```vim
augroup vimrc-neoclojure
  autocmd!
  autocmd FileType clojure setlocal omnifunc=neoclojure#complete
augroup END
```

If you have quickrun.vim, include this as well.

```vim
let g:quickrun_config.clojure = {
      \ 'runner': 'neoclojure', 'command': 'dummy',
      \ 'tempfile'  : '%{tempname()}.clj'}
```

## Development progress / todo

* SECURITY WARNING! This plugin *executes* your clojure/java code silently. This problem will be fixed before version 0.1 release. (Current version is 0.1-dev)
* Java completions in clojure files are available
    * Class names e.g. `java.lang.String`
    * Instance Methods e.g. `(.getLocation player)`
    * Static Methods e.g. `(String/format)`
    * Static Enum Constants `Thread$STATE/BLOCKED`
    * ... They are based on `(ns (:import ...))`

* First time completion takes very long time (like 4sec)
    * it'll be done asynchronously in the future.
* No clojure function completions yet.

## Links

<http://twitter.com/neoclojure>

## License

GPL version 3 or any later version
Copyright (c) Tatsuhiro Ujihisa
