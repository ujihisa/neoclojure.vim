neoclojure
* Code complete (fast and sync)
* quickrun (slow and async)
    * libraries
    * under proj: uses the project
    * outside proj: uses dummy "unnamed" project
* ref (fast and sync)
* leiningen? (e.g. lein run)

* executes project.clj
* executes dependencies (including current project)
* parses current buffer

* spawns dummy unnamed project by stardup asynchronously

* debugging itself
    * logger
    * test
    * fault tolerance


# neoclojure.vim

This is under development!

* Java method-name completion works (type `(.` in your clojure buffer)
    * no automatic `import` insertion yet
    * `(ns ...)` has to be located as the first expression of the file

## Requirement

* [leiningen](http://leiningen.org/)
* [vimproc.vim](https://github.com/Shougo/vimproc.vim)

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
  " If you use neocomplete
  autocmd FileType clojure setlocal omnifunc=neoclojure#complete#omni_auto
  " Otherwise
  autocmd FileType clojure setlocal omnifunc=neoclojure#complete#omni
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
    * This plugin evaluates the first expression of the current file. If the first expression is `ns` with `:require` or `:use`, they will be evaluated, which means neoclojure will evaluate other files. Rest of expressions won't be evaluated though.
* Java completions in clojure files are available
    * Class names e.g. `java.lang.String`
    * Instance Methods e.g. `(.getLocation player)`
    * Static Methods e.g. `(String/format)`
    * Static Enum Constants `Thread$STATE/BLOCKED`
    * ... They are based on `(ns (:import ...))`
* Clojure completions (WIP)
    * <http://gyazo.com/04c943ca6b5c337fab39dd10fd201617>
    * <http://gyazo.com/08d52356cba83f58aac4deb2a1447bed>
    * <http://gyazo.com/9c2221ecfc315b26d63eb5a6c73db3bb>
    * <http://gyazo.com/b5d33baff6410c573e27016242ee5f97>

* First time completion may take very long time (like 4sec)
    * it'll be done asynchronously in the future.

## Philosophy

What neoclojure doesn't do:

* neoclojure doesn't implement everything here.
    * It depends on embedded libraries.
    * It uses other plugins *only if* you already have.
    * It doesn't parse Clojure in Vim script. Let Clojure does that work; it knows more about itself.
* neoclojure doesn't spawn Clojure daemon.
    * It just spawns Clojure process and communicate with stdout/stderr instead of socket.
    * When Vim dies, Clojure process also dies. That's what it should be.

### FAQ

* Q. neoclojure hangs for some reason!
    * A. is leiningen working? It doesn't work when clojars.org is down.

## Links

<http://twitter.com/neoclojure>

## Licence

GPL version 3 or any later version
Copyright (c) Tatsuhiro Ujihisa
