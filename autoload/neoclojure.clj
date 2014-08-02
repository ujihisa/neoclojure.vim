(ns neoclojure
  (:require [clojure.string :as s]
            [clojure.repl]))

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
  (let [first-expr
        (try
          (read-string content)
          (catch Exception e nil))]
    (if (and first-expr (= 'ns (first first-expr)))
      first-expr
      '(ns dummy))))
#_ (prn 'find-ns-declare (test #'find-ns-declare))

(defn- eval-in&give-me-ns [^String ns-declare]
  (let [parsed (read-string ns-declare)]
    (when (= 'ns (first parsed))
      (try
        (eval parsed)
        (let [probably-ns *ns*]
          (ns neoclojure)
          probably-ns)
        (catch Exception e
          (if (.startsWith (.getMessage e) "EOF while reading")
            nil
            (clojure.repl/pst)))))))

(defn complete-candidates [ns-declare phrase]
  (when-let [given-ns (eval-in&give-me-ns ns-declare)]
    (let [[given-package given-class+] (split-at-last-dot phrase)
          java-instance-methods
          (for [[sym cls] (ns-imports given-ns)
                method (.getMethods cls)
                :let [mname (str "." (.getName method))]
                :when (and
                        (not (-> method .getModifiers
                               java.lang.reflect.Modifier/isStatic))
                        (.startsWith mname phrase))]
            [mname (.getName cls)])
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
              [:S (to-hashmap (set java-static-methods))]
              [:P (to-hashmap (set java-namespaces))]
              [:E (to-hashmap (set java-enum-constants))])
        ->vimson))))

; main -- not indented to be executed when you load this file as library
(doseq  [x (rest *command-line-args*)]
  (println (complete-candidates "(ns aaa (:import [java.net URI]))" x)))
