(ns neoclojure.search-test
  (:require [expectations :refer :all]
            [neoclojure.search :refer :all]))

; split-at-last-dot
(expect ["hello" "world"] (split-at-last-dot "hello.world"))
(expect ["hello.this" "world"] (split-at-last-dot "hello.this.world"))
(expect [nil "world"] (split-at-last-dot "world"))

; ->vimson
(expect "[1]" (->vimson [1]))
(expect "\"hello\"" (->vimson :hello))
(expect "{1:2}" (->vimson {1 2}))
(expect "[1, \"hello\", {}, [], {1:2}, {\"a\":\"b\"}]"
        (->vimson [1 "hello" {} [] {1 2} {"a" "b"}]))

; to-hashmap

; find-ns-declare

; eval-in&give-me-ns

; java-instance-methods*

; clojure-ns-vars*

; complete-candidates
