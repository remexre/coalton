;;;; package.lisp

(fiasco:define-test-package #:coalton-tests
  (:documentation "Tests for the COALTON system.")
  (:use #:cl #:coalton-impl/typechecker)
  (:shadowing-import-from #:coalton
                          #:fn
                          #:->
                          #:=>)
  (:import-from #:coalton-impl/codegen
                #:direct-application)
  (:import-from #:coalton-impl/ast
                #:pattern-var
                #:pattern-wildcard
                #:pattern-literal
                #:pattern-constructor)
  (:shadowing-import-from #:coalton
                          #:String
                          #:Integer
                          #:Char
                          #:Unit)
  (:export
   #:run-coalton-tests))

(defpackage #:coalton-native-tests
  (:documentation "Tests for the COALTON system, written in Coalton.")
  (:use #:coalton #:coalton-prelude)
  (:local-nicknames
   (#:string #:coalton-library/string)
   (#:vector #:coalton-library/vector)
   (#:slice #:coalton-library/slice)
   (#:hashtable #:coalton-library/hashtable)
   (#:iter #:coalton-library/iterator)))

(defpackage #:coalton-test-user
  (:documentation "A copy-cat package to COALTON-USER for testing.")
  (:use #:coalton #:coalton-prelude)
  (:local-nicknames
   (#:string #:coalton-library/string)
   (#:vector #:coalton-library/vector)
   (#:slice #:coalton-library/slice)
   (#:hashtable #:coalton-library/hashtable)
   (#:iter #:coalton-library/iterator)))
