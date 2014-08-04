(ns experimental.core
  (:use [clojure.pprint :only [pprint]]
        [cemerick.pomegranate :only (add-dependencies)])
  (:require #_[clojail.core]
            [clojure.repl]
            [clojure.tools.reader :as r]
            [clojure.tools.reader.reader-types :as rt]))

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
    (prn (add-dependencies
           :coordinates dependencies
           :repositories (merge cemerick.pomegranate.aether/maven-central
                                {"clojars" "http://clojars.org/repo"}
                                repositories)))
    (prn "------------------------------------------")
    (prn (eval (parse-clojure "org.bukkit.Bukkit")))))

; overwrite
(defn -main []
  (let [known-classes (for [[_ cls] (ns-imports *ns*)]
                        (.getName cls))
        classes
        (for [path (for [url (-> (ClassLoader/getSystemClassLoader) .getURLs)
                         :let [path (.getPath url)]
                         :when (.endsWith path ".jar")]
                     path)
              :let [ jar (java.util.jar.JarFile. path)]
              entry (enumeration-seq (.entries jar))
              :when (.endsWith (.getName entry) ".class")]
          (-> (.getName entry)
            (.replaceAll "/" ".")
            (.replaceAll "\\.class$" "")
            (.replaceAll "\\$.*" "")
            (.replaceAll "__init$" "")))]
    (mapv prn (clojure.set/difference (set classes) (set known-classes)))))
(-main)
