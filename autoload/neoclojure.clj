(ns neoclojure
  (:require [clojure.string :as s]))

(defn split-at-last-dot [st]
  (let [[left right] (s/split st #"\.(?=[^\.]*$)")]
    (if right
      [left right]
      [nil (str left)])))

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

(defn- eval-in&give-me-ns [^String ns-declare]
  (let [parsed (read-string ns-declare)]
    (when (= 'ns (first parsed))
      (try
        (eval parsed)
        (catch Exception e e))
      (let [probably-ns *ns*]
        (ns neoclojure)
        probably-ns))))

(defn search [ns-declare phrase]
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
  (println (search "(ns aaa (:import [java.net URI]))" x)))
