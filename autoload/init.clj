(do
  (ns searcher)
  (defn ->vimlist [x]
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
    (let [the-ns *ns*]
      (ns searcher)
      (->> (for [[k v] (ns-imports the-ns)
                 method (.getMethods v)
                 :let [mname (str "." (.getName method))]
                 :when (.startsWith mname partial-methodname)]
             [mname (.getName v)])
        set vec to-hashmap ->vimlist)))
  #_(println (search "(ns aaa (:import [java.net URI]))" "getN")))
