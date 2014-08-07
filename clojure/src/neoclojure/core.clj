(ns neoclojure.core
  (:use [clojure.pprint :only [pprint]])
  (:require [clojure.tools.reader :as r]
            [clojure.tools.reader.reader-types :as rt]
            [cemerick.pomegranate :as p]
            [cemerick.pomegranate.aether :as aether]))

(defn parse-clojure-one [^String code]
  (try
    (binding [r/*read-eval* false]
      (->> code
        rt/indexing-push-back-reader
        r/read))
    (catch clojure.lang.ExceptionInfo e e)))

(defn parse-clojure-all [^String code]
  (parse-clojure-one (str "[" code "]")))

(defn-
  ^{:doc "Give me the path of project.clj file"}
  project-file->pomegranate-hashmap [^String project-filepath]
  (let [[_ _ _ & attrs-vec] (parse-clojure-one (slurp project-filepath))
        attrs (apply hash-map attrs-vec)]
    {:coordinates (:dependencies attrs)
     :repositories (merge aether/maven-central
                          {"clojars" "http://clojars.org/repo"}
                          (:repositories attrs))}))

(defn add-dependencies-from-project-file [^String project-filepath]
  (let [{c :coordinates r :repositories}
        (project-file->pomegranate-hashmap project-filepath)]
    #_ (aether/resolve-dependencies :coordinates c :repositories r)
    (p/add-dependencies :coordinates c :repositories r)))

(defn initialize [^String sfiledir]
  (add-dependencies-from-project-file (str sfiledir "/project.clj"))
  (p/add-classpath (str sfiledir "/src")))

#_ (initialize "/home/ujihisa/Dropbox/vimbundles/neoclojure.vim/test")
