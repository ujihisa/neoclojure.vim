(defproject neoclojure "0.1-SNAPSHOT"
  :description "FIXME: write description"
  :url "https://github.com/ujihisa/neoclojure.vim"
  :license {:name "GNU GPL v3+"
            :url "http://www.gnu.org/licenses/gpl-3.0.en.html"}
  :dependencies [[org.clojure/clojure "1.8.0-RC4"]
                 [org.clojure/tools.reader "0.10.0"]
                 [com.cemerick/pomegranate "0.3.0"]
                 [org.clojure/core.incubator "0.1.3"]
                 ; Dirty hack -- without this leininge takes 0.1.2
                 ; which doesn't work with clj-http
                 [org.apache.httpcomponents/httpclient "4.4"]]
  :target-path "target/%s"
  :min-lein-version "2.5.0"
  :jvm-opts ["-Djava.security.policy=example.policy"]) ; for clojail
