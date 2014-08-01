(defproject experimental "0.1-SNAPSHOT"
  :description "FIXME: write description"
  :url "https://github.com/ujihisa/neoclojure.vim"
  :license {:name "GNU GPL v3+"
            :url "http://www.gnu.org/licenses/gpl-3.0.en.html"}
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [org.clojure/tools.reader "0.8.5"]
                 [com.cemerick/pomegranate "0.3.0"]]
  :main ^:skip-aot experimental.core
  :target-path "target/%s"
  :min-lein-version "2.2.0"
  :jvm-opts ["-Djava.security.policy=example.policy"]) ; for clojail
