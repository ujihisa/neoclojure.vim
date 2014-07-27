(defn vimlist [seq]
  (str "[" (clojure.string/join ", " (map pr-str seq)) "]"))

(defn search [partial-classname]
  (vimlist (for [[k v] (ns-imports *ns*)
                 :let [name (.getName k)]
                 :when (.startsWith name partial-classname)]
             name)))
