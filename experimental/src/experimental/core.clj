(ns experimental.core
  (:use [clojure.pprint :only [pprint]])
  (:require #_[clojail.core]
            [clojure.repl]
            [clojure.tools.reader :as r]
            [clojure.tools.reader.reader-types :as rt]
            [cemerick.pomegranate :as p]
            [cemerick.pomegranate.aether :as aether]))

#_ (defn -main []
  (try (let [sandbox (clojail.core/sandbox #{}) ]
         (sandbox '(do
                     (use 'clojure.repl)
                     (use 'clojure.pprint)
                     (prn (ns-publics 'clojure.repl))
                     (defn f []
                       123)
                     (pprint (source f))
                     (prn (f)))))
    (catch Exception e (clojure.repl/pst e))))

; #=(+ 2 3)

(defn parse-clojure [code]
  (try
    (binding [r/*read-eval* false]
      (->> code
        rt/indexing-push-back-reader
        r/read))
    (catch clojure.lang.ExceptionInfo e e)))

(defn parse-clojure-all [code]
  (parse-clojure (str "[" code "]")))

(defn -main []
  #_ (pprint (parse-clojure (slurp "src/experimental/core.clj")))
  #_ (prn "--ready")

  #_ (try
    (let [file "(ns aaa
                (:require [clojure.repl]))
                (prn 'ok)
                (def hello \"world\")
                (defn f [x]
                  123)
                (defn ^String f2 [x]
                  123)
                98
                (let [memo 123]
                  (defn g [y]
                    memo))"
          only-declare
          (fn [x]
            (case (first x)
              ns x
              def (with-meta (list 'declare (-> x rest first))
                             (meta x))
              defn x
              nil))]
      (->> file
        parse-clojure-all
        (filter list?)
        (mapv only-declare)
        (filter identity)
        (map (juxt identity meta))
        clojure.pprint/pprint))
    (catch Exception e (clojure.repl/pst e)))

  (let [[_ _ _ & x] (parse-clojure (slurp "/home/ujihisa/git/cloft2/client/project.clj"))
        hashmap (apply hash-map x)
        dependencies (get hashmap :dependencies [])
        repositories (get hashmap :repositories {})]
    (prn "------------------------------------------")
    (prn dependencies repositories)
    (prn "------------------------------------------")
    (prn (p/add-dependencies
           :coordinates dependencies
           :repositories (merge aether/maven-central
                                {"clojars" "http://clojars.org/repo"}
                                repositories)))
    (prn "------------------------------------------")
    (prn (eval (parse-clojure "org.bukkit.Bukkit")))))

; overwrite
#_ (defn -main []
  (let [known-classes (for [[_ cls] (ns-imports *ns*)]
                        (.getName cls))
        classes
        (for [url (.getURLs (ClassLoader/getSystemClassLoader))
              :let [path (.getPath url)]
              :when (.endsWith path ".jar")
              :let [jar (java.util.jar.JarFile. path)]
              entry (enumeration-seq (.entries jar))
              :when (.endsWith (.getName entry) ".class")]
          (-> (.getName entry)
            (.replaceAll "/" ".")
            (.replaceAll "\\.class$" "")
            (.replaceAll "\\$.*" "")
            (.replaceAll "__init$" "")))]
    (prn (count (clojure.set/difference (set classes) (set known-classes))))))
#_ (let [t (System/currentTimeMillis)]
  (-main)
  (prn (- (System/currentTimeMillis) t)))

#_ (load-file "/home/ujihisa/.vimbundles/neoclojure.vim/autoload/neoclojure.clj")

(defn-
  ^{:doc "Give me the path of project.clj file"}
  project-file->pomegranate-hashmap [^String project-filepath]
  (let [[_ _ _ & attrs-vec] (parse-clojure (slurp project-filepath))
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

#_ (prn (project-file->pomegranate-hashmap "/home/ujihisa/git/cloft2/client/project.clj"))

#_ (add-dependencies-from-project-file "/home/ujihisa/.vimbundles/neoclojure.vim/test/project.clj")
#_ (use '[clojure.tools.namespace.repl :only (refresh)])
#_ (prn 'refresh (refresh))
#_ (prn (p/add-classpath "/home/ujihisa/.vimbundles/neoclojure.vim/test/src"))
#_ (ns x
  (:require [clj-http.client] :reload-all))
#_ (prn (vec (.getURLs (ClassLoader/getSystemClassLoader))))
#_ (vec (.getFields org.apache.http.client.params.ClientPNames))

#_ clj-http.client/post

(defn initialize [^String sfiledir]
  (p/add-classpath "/home/ujihisa/.vimbundles/neoclojure.vim/autoload")
  (add-dependencies-from-project-file (str sfiledir "/project.clj"))
  (p/add-classpath (str sfiledir "/src")))

#_ (initialize "/home/ujihisa/Dropbox/vimbundles/neoclojure.vim/test")
