(ns neoclojure.unite-outline
  (:use [clojure.pprint :only [pprint]]
        [clojure.core.strint :only (<<)])
  (:require [neoclojure.core]
            [neoclojure.search]
            [clojure.string :as s]
            [clojure.tools.reader :as r]
            [clojure.tools.reader.reader-types :as rt]))

(defn run [^String fname]
  (-> (for [expr (neoclojure.core/parse-clojure-all (slurp fname))
            :let [typ (get #{'ns 'defn 'def 'defn-} (first expr) nil)]
            :when typ]
        {:type (str typ)
         :word (case typ
                 'ns (<< "(~{typ} ~(second expr) ...)")
                 (<< "(~{typ} ~(second expr) ~(nth expr 2) ...)"))
         :lnum (-> expr meta :line)
         :level 1 #_(if (= 'ns typ) 1 2)})
    neoclojure.search/->vimson
    println))
