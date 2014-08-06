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
         :word (if (< 2 (count expr))
                 (pr-str (concat (take 3 expr) '(...)))
                 (pr-str expr))
         :lnum (-> expr meta :line)
         :level 1 #_(if (= 'ns typ) 1 2)
         :is_volatile 0})
    neoclojure.search/->vimson
    println))
