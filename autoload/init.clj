(do
  (ns searcher)
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
  (defn search [ns-declare partial-methodname]
    (eval (read-string ns-declare))
    (let [the-ns *ns*
          instance-methods
          (do
            (ns searcher)
            (->> (for [[k v] (ns-imports the-ns)
                       method (.getMethods v)
                       :let [mname (str "." (.getName method))]
                       :when (.startsWith mname partial-methodname)]
                   [mname (.getName v)])
              set vec to-hashmap))
          static-methods
          (->> (for [[k v] (ns-imports the-ns)
                     method (.getMethods v)
                     :let [mname (str k "/" (.getName method))]
                     :when (and
                             (-> method .getModifiers
                               java.lang.reflect.Modifier/isStatic)
                             (.startsWith mname partial-methodname))]
                 [mname ""])
            set vec to-hashmap) ]
      (-> (merge instance-methods static-methods)
        ->vimlist)))
  #_(println (search "(ns aaa (:import [java.net URI]))" ".getN")))
