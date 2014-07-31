(do
  (ns neoclojure
    (:require [clojure.string :as s]))

  (defn split-at-last-dot [st]
    (let [[left right] (s/split st #"\.(?=[^\.]*$)")]
      (if right
        [left right]
        [nil left])))

  (defn ^String ->vimson [x]
    (cond
      (vector? x)
      (str "["
           (clojure.string/join ", " (map ->vimson x))
           "]")
      (map? x)
      (str "{"
           (clojure.string/join ", " (map #(str (->vimson (first %)) ":" (->vimson (second %))) x))
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
                   [mname (.getName v) "M"])
              set))
          java-static-methods
          (->> (for [[k v] (ns-imports given-ns)
                     method (.getMethods v)
                     :let [mname (str k "/" (.getName method))]
                     :when (and
                             (-> method .getModifiers
                               java.lang.reflect.Modifier/isStatic)
                             (.startsWith mname phrase))]
                 [mname "" "S"])
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
                  [(str given-package "." class+enum) "" "E"])
                (for [[k v] (ns-imports given-ns)
                      :let [v-package (-> v .getPackage .getName)]
                      enum (.getEnumConstants v)
                      :let [class+enum (str k "/" enum)]
                      :when (.startsWith class+enum given-class+)]
                  [class+enum v-package "E"]))
            set)
          java-namespaces
          (->> (for [[_ v] (ns-imports given-ns)
                     :let [fqdn-name (.getName v)]
                     :when (.startsWith fqdn-name phrase)]
                 [fqdn-name "" "P"])
            set)]
      (->
        {}
          (assoc "M" (to-hashmap (concat java-instance-methods java-static-methods)))
          (assoc "P" (to-hashmap java-namespaces))
          (assoc "E" (to-hashmap java-enum-constants))
        ->vimson)))
  #_(println (search "(ns aaa (:import [java.net URI]))" ".getN")))
