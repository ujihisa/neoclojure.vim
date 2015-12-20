(ns neoclojure.search-test
  (:require [expectations :refer :all]
            [neoclojure.search :refer :all]))

(expect ["hello" "world"] (split-at-last-dot "hello.world"))
(expect ["hello.this" "world"] (split-at-last-dot "hello.this.world"))
(expect [nil "world"] (split-at-last-dot "world"))
