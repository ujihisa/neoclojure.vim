(defproject neoclojure "0.1-SNAPSHOT"
  :description "FIXME: write description"
  :url "https://github.com/ujihisa/neoclojure.vim"
  :license {:name "GNU GPL v3+"
            :url "http://www.gnu.org/licenses/gpl-3.0.en.html"}
  :dependencies [[org.clojure/clojure "1.9.0"]
                 [org.clojure/tools.reader "1.2.2"]
                 [com.cemerick/pomegranate "1.0.0"]
                 [org.clojure/core.incubator "0.1.4"]
                 ; Dirty hack -- without this the following error will occur for
                 ; projects that (indirectly) use old clj-http:
                 ;   instance method search failed: CompilerException java.lang.NoClassDefFoundError: IllegalName: compile__stub.clj_http.headers.clj-http.headers/HeaderMap, compiling:(clj_http/headers.clj:105:1)
                 [clj-http/clj-http "3.9.0"]
                 [expectations "2.1.9"]]
  :plugins [[lein-expectations "0.0.7"]]
  :target-path "target/%s"
  :min-lein-version "2.5.0"
  :jvm-opts ["-Djava.security.policy=example.policy" ; for clojail
             "-XX:+TieredCompilation" ; http://tnoda-clojure.tumblr.com/post/51495039433/
             "-XX:TieredStopAtLevel=1"
             "-Xverify:none"])
