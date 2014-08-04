(ns neoclojure
  (:require [clojure.string :as s]
            [clojure.repl]
            [clojure.set]))

(defn
  ^{:test (fn []
            (assert (= ["hello" "world"] (split-at-last-dot "hello.world")))
            (assert (= ["hello.this" "world"] (split-at-last-dot "hello.this.world")))
            (assert (= [nil "world"] (split-at-last-dot "world"))))}
  split-at-last-dot [st]
  (let [[left right] (s/split st #"\.(?=[^\.]*$)")]
    (if right
      [left right]
      [nil (str left)])))
#_ (prn 'split-at-last-dot (test #'split-at-last-dot))

(defn ^String ->vimson [x]
  (cond
    (vector? x)
    (str "[" (s/join ", " (map ->vimson x)) "]")

    (keyword? x)
    (pr-str (name x))

    (map? x)
    (str "{"
         (s/join ", " (map #(str (->vimson (first %)) ":" (->vimson (second %))) x))
         "}")

    :else (pr-str x)))

(defn to-hashmap [darr]
  (reduce (fn [acc [k v]]
            (assoc acc k (conj (get acc k []) v)))
          {} darr))

(defn- some-read-string [^String s]
  (try
    (read-string s)
    (catch RuntimeException e nil)))

(defn
 ^{:test (fn []
           (assert (= '(ns dummy) (find-ns-declare "")))
           (assert (= '(ns aaa) (find-ns-declare "(ns aaa)")))
           (assert (= '(ns dummy) (find-ns-declare "(ns aaa")))
           (assert (= '(ns aaa (:require [clojure.string]))
                      (find-ns-declare "(ns aaa (:require [clojure.string]))")))
           (assert (= '(ns aaa (:require [clojure.strin]))
                      (find-ns-declare "(ns aaa (:require [clojure.strin]))"))))}
  find-ns-declare [content]
  (let [first-expr (some-read-string content)]
    (if (and (list? first-expr) (= 'ns (first first-expr)))
      first-expr
      '(ns dummy))))
#_ (prn 'find-ns-declare (test #'find-ns-declare))

(defn-
 ^{:tag clojure.lang.Namespace
   :test (fn []
           (assert (nil? (eval-in&give-me-ns "")))
           (assert (= 'aaa (.getName (eval-in&give-me-ns "(ns aaa)"))))
           (assert (nil? (eval-in&give-me-ns "(ns aaa")))
           #_ (prn 'final (eval-in&give-me-ns "(ns aaa (:require [abc]))"))
           (assert (= "Could not locate abc__init.class or abc.clj on classpath: "
                      (eval-in&give-me-ns "(ns aaa (:require [abc]))"))))}
  eval-in&give-me-ns [^String ns-declare]
  (let [orig-ns *ns*
        parsed (some-read-string ns-declare)]
    (when (and (list? parsed) (= 'ns (first parsed)))
      (try
        (eval parsed)
        *ns*
        (catch java.io.FileNotFoundException e (.getMessage e))
        (catch Exception e (clojure.repl/pst e))
        (finally (in-ns (.getName orig-ns)))))))
(prn 'eval-in&give-me-ns (test #'eval-in&give-me-ns))

(defn- prn* [& xs]
  (apply prn xs)
  (last xs))

(defn-
  ^{:test (fn []
            (assert (= [[".toPlainString" "java.math.BigDecimal"]]
                       (java-instance-methods* *ns* ".toPlainString"))))}
  java-instance-methods* [given-ns phrase]
  (for [[sym cls] (ns-imports given-ns)
        method (.getMethods cls)
        :let [mname (str "." (.getName method))]
        :when (and
                (not (-> method .getModifiers
                       java.lang.reflect.Modifier/isStatic))
                (.startsWith mname phrase))]
    [mname (.getName cls)]))
#_ (prn 'java-instance-methods* (test #'java-instance-methods*))

(defn-
  ^{:test (fn []
            (assert (= [["s/reverse" "[s]"]] (clojure-ns-vars* *ns* "s/rev")))
            (assert (= [["clojure.set/map-invert" "[m]"]]
                       (clojure-ns-vars* *ns* "clojure.set/map-inve")))
            (prn (clojure-ns-vars* *ns* "clojure.set/map-inve")))}
  clojure-ns-vars* [given-ns phrase]
  (let [alias-table (clojure.set/map-invert (ns-aliases given-ns))]
    (for [nz (all-ns)
          [sym f] (ns-publics nz)
          nz-str (filter identity [(.getName nz) (alias-table nz)])
          :let [vname  (format "%s/%s" nz-str sym)]
          :when (.startsWith vname phrase)]
      [vname (s/join ", " (-> f meta :arglists))])))
#_ (prn 'clojure-ns-vars* (test #'clojure-ns-vars*))

(defn
  ^{:tag String
    :test (fn []
            (assert (= "[[\"M\", {\".toPlainString\":[\"java.math.BigDecimal\"]}], [\"S\", {}], [\"P\", {}], [\"E\", {}]]"
                       (complete-candidates "(ns aaa)" ".toPlai"))))}
  complete-candidates [ns-declare phrase]
  (let [given-ns (eval-in&give-me-ns ns-declare)]
    (cond
      ; TODO
      (string? given-ns)
      "[]"

      :else
      (let [[given-package given-class+] (split-at-last-dot phrase)

            java-instance-methods
            (java-instance-methods* given-ns phrase)

            clojure-ns-vars
            (clojure-ns-vars* given-ns phrase)

            java-static-methods
            (if given-package
              (for [[sym cls] (ns-imports given-ns)
                    :let [v-package (-> cls .getPackage .getName)]
                    method (.getMethods cls)
                    :let [mname (str (.getName cls) "/" (.getName method))]
                    :when (and
                            (-> method .getModifiers
                              java.lang.reflect.Modifier/isStatic)
                            (.startsWith mname phrase))]
                [mname ""])
              (for [[sym cls] (ns-imports given-ns)
                    method (.getMethods cls)
                    :let [mname (str sym "/" (.getName method))]
                    :when (and
                            (-> method .getModifiers
                              java.lang.reflect.Modifier/isStatic)
                            (.startsWith mname phrase))]
                [mname ""]))
            java-enum-constants
            (if given-package
              (for [[k v] (ns-imports given-ns)
                    :let [v-package (-> v .getPackage .getName)]
                    enum (.getEnumConstants v)
                    :let [class+enum (str k "/" enum)]
                    :when (and
                            (= v-package given-package)
                            (.startsWith class+enum given-class+))]
                [(str given-package "." class+enum) ""])
              (for [[k v] (ns-imports given-ns)
                    :let [v-package (-> v .getPackage .getName)]
                    enum (.getEnumConstants v)
                    :let [class+enum (str k "/" enum)]
                    :when (.startsWith class+enum given-class+)]
                [class+enum v-package]))
            java-namespaces
            (for [[_ v] (ns-imports given-ns)
                  :let [fqdn-name (.getName v)]
                  :when (.startsWith fqdn-name phrase)]
              [fqdn-name ""])]
        (->
          []
          (conj [:M (to-hashmap (set java-instance-methods))]
                [:S (to-hashmap (concat
                                  (set java-static-methods)
                                  (set clojure-ns-vars)))]
                [:P (to-hashmap (set java-namespaces))]
                [:E (to-hashmap (set java-enum-constants))])
          ->vimson)))))
(prn 'complete-candidates (test #'complete-candidates))

; main -- not indented to be executed when you load this file as library
(doseq  [x (rest *command-line-args*)]
  (println (complete-candidates "(ns aaa (:import [java.net URI]))" x)))
