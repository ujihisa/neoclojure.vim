(do
  (ns neoclojure
    (:require [clojure.string :as s]))

  (defn split-at-last-dot [st]
    (let [[left right] (s/split st #"\.(?=[^\.]*$)")]
      (if right
        [left right]
        [nil left])))

  (defn ^String ->vimlist [x]
    (cond
      (vector? x)
      (str "["
           (clojure.string/join ", " (map ->vimlist x))
           "]")
      (map? x)
      (str "{"
           (clojure.string/join ", " (map #(str (->vimlist (first %)) ":" (->vimlist (second %))) x))
           "}")
      :else (pr-str x)))

  (defn to-hashmap [darr]
    (reduce (fn [acc [k v]]
            (assoc acc k (conj (get acc k []) v)))
          {} darr))

  (defn search [ns-declare phrase]
    (eval (read-string ns-declare))
    (let [given-ns *ns*
          [given-package given-class+] (split-at-last-dot phrase)
          java-instance-methods
          (do
            (ns neoclojure)
            (->> (for [[k v] (ns-imports given-ns)
                       method (.getMethods v)
                       :let [mname (str "." (.getName method))]
                       :when (.startsWith mname phrase)]
                   [mname (.getName v)])
              set))
          java-static-methods
          (->> (for [[k v] (ns-imports given-ns)
                     method (.getMethods v)
                     :let [mname (str k "/" (.getName method))]
                     :when (and
                             (-> method .getModifiers
                               java.lang.reflect.Modifier/isStatic)
                             (.startsWith mname phrase))]
                 [mname ""])
            set)
          java-enum-constants
          (-> (if given-package
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
            set)
          java-namespaces
          (->> (for [[_ v] (ns-imports given-ns)
                     :let [fqdn-name (.getName v)]
                     :when (.startsWith fqdn-name phrase)]
                 [fqdn-name ""])
            set)]
      (-> (concat java-instance-methods
                  java-namespaces
                  java-static-methods
                  java-enum-constants)
        to-hashmap
        ->vimlist)))
  #_(println (search "(ns aaa (:import [java.net URI]))" ".getN")))
