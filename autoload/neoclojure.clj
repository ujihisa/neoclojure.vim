(do
  (ns neoclojure)
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
    (let [the-ns *ns*
          java-instance-methods
          (do
            (ns neoclojure)
            (->> (for [[k v] (ns-imports the-ns)
                       method (.getMethods v)
                       :let [mname (str "." (.getName method))]
                       :when (.startsWith mname phrase)]
                   [mname (.getName v)])
              set))
          java-static-methods
          (->> (for [[k v] (ns-imports the-ns)
                     method (.getMethods v)
                     :let [mname (str k "/" (.getName method))]
                     :when (and
                             (-> method .getModifiers
                               java.lang.reflect.Modifier/isStatic)
                             (.startsWith mname phrase))]
                 [mname ""])
            set)
          java-enum-constants
          (->> (for [[k v] (ns-imports the-ns)
                     enum (.getEnumConstants v)
                     :let [ename (str k "/" (.name enum))]
                     :when (and
                             true
                             #_(-> method .getModifiers
                               java.lang.reflect.Modifier/isStatic)
                             (.startsWith ename phrase))]
                 [ename (.getName v)])
            set)
          java-namespaces
          (->> (for [[_ v] (ns-imports the-ns)
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
