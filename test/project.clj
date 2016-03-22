(defproject cloft2-client "0.1-SNAPSHOT"
  :description "FIXME: write description"
  :url "https://github.com/ujihisa/cloft2"
  :license {:name "GNU GPL v3+"
            :url "http://www.gnu.org/licenses/gpl-3.0.en.html"}
  :repositories {"org.bukkit"
                 "http://repo.bukkit.org/content/groups/public/"}
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [clj-http "0.9.2"]
                 [org.clojure/core.incubator "0.1.3"]
                 [org.clojure/tools.nrepl "0.2.3"]
                 [org.bukkit/bukkit "1.7.9-R0.2"]]
  :target-path "target/%s"
  :min-lein-version "2.2.0")
