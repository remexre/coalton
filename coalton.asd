;;;; coalton.asd

(asdf:defsystem #:coalton
  :description "An efficient, statically typed functional programming language that supercharges Common Lisp. "
  :author "Coalton contributors (https://github.com/coalton-lang/coalton)"
  :license "MIT"
  :version (:read-file-form "VERSION.txt")
  :depends-on (#:alexandria
               #:global-vars
               #:trivia
               #:fset
               #:float-features
               #:split-sequence
               #:uiop
               #:coalton/hashtable-shim)
  :in-order-to ((asdf:test-op (asdf:test-op #:coalton/tests)))
  :around-compile (lambda (compile)
                    (let (#+sbcl (sb-ext:*derive-function-types* t))
                      (funcall compile)))
  :pathname "src/"
  :serial t
  :components ((:file "package")
               (:file "settings")
               (:file "utilities")
               (:file "global-lexical")
               (:module "algorithm"
                :serial t
                :components ((:file "tarjan-scc")
                             (:file "immutable-map")
                             (:file "immutable-listmap")))
               (:module "ast"
                :serial t
                :components ((:file "pattern")
                             (:file "node")
                             (:file "parse-error")
                             (:file "parse-form")
                             (:file "free-variables")))
               (:module "typechecker"
                :serial t
                :components ((:file "kinds")
                             (:file "types")
                             (:file "pretty-printing")
                             (:file "substitutions")
                             (:file "predicate")
                             (:file "scheme")
                             (:file "typed-node")
                             (:file "type-errors")
                             (:file "unify")
                             (:file "equality")
                             (:file "environment")
                             (:file "context-reduction")
                             (:file "type-parse-error")
                             (:file "parse-type")
                             (:file "parse-type-definition")
                             (:file "parse-class-definition")
                             (:file "parse-instance-definition")
                             (:file "derive-type")
                             (:file "check-types")
                             (:file "debug")))
               (:module "codegen"
                :serial t
                :components ((:file "utilities")
                             (:file "lisp-types")
                             (:file "function-entry")
                             (:file "optimizer")
                             (:file "direct-application")
                             (:file "match-constructor-lift")
                             (:file "pointfree-transform")
                             (:file "compile-pattern")
                             (:file "compile-typeclass-dicts")
                             (:file "compile-expression")
                             (:file "compile-type-definition")
                             (:file "program")))
               (:file "toplevel-define-type")
               (:file "toplevel-declare")
               (:file "toplevel-define")
               (:file "toplevel-define-instance")
               (:file "coalton")
               (:file "debug")
               (:file "faux-macros")
               (:file "language-macros")
               (:module "library"
                :serial t
                :components ((:file "utils")
                             (:file "classes")
                             (:file "builtin")
                             (:file "boolean")
                             (:file "bits")
                             (:file "arith")
                             (:file "char")
                             (:file "string")
                             (:file "tuple")
                             (:file "optional")
                             (:file "list")
                             (:file "result")
                             (:file "functions")
                             (:file "cell")
                             (:file "vector")
                             (:file "slice")
                             (:file "hashtable")
                             (:file "monad/state")
                             (:file "iterator")
                             (:file "prelude")))
               (:file "toplevel-environment")))

;;; we need to inspect the sbcl version in order to decide which version of the hashtable shim to load,
;;; because 2.1.12 includes (or will include) a bugfix that allows a cleaner, more maintainable
;;; implementation.

(cl:if (uiop:featurep :sbcl)
       (cl:pushnew
        (cl:if (uiop:version< (cl:lisp-implementation-version)
                              "2.2.2")
               :sbcl-pre-2-2-2
               :sbcl-post-2-2-2)
        cl:*features*))

(asdf:defsystem #:coalton/hashtable-shim
  :description "Shim over Common Lisp hash tables with custom hash functions, for use by the Coalton standard library."
  :author "Coalton contributors (https://github.com/coalton-lang/coalton)"
  :license "MIT"
  :version (:read-file-form "VERSION.txt")
  :pathname "src/hashtable-shim"
  :serial t
  :components ((:file "defs")
               (:file "impl-sbcl-pre-2-2-2" :if-feature :sbcl-pre-2-2-2)
               (:file "impl-sbcl-post-2-2-2" :if-feature :sbcl-post-2-2-2)
               (:file "impl-fail" :if-feature (:not :sbcl))))

(asdf:defsystem #:coalton/doc
  :description "Documentation generator for Coalton"
  :author "Coalton contributors (https://github.com/coalton-lang/coalton)"
  :license "MIT"
  :version (:read-file-form "VERSION.txt")
  :depends-on (#:coalton
               #:html-entities
               #:yason
               #:uiop)
  :around-compile (lambda (compile)
                    (let (#+sbcl (sb-ext:*derive-function-types* t))
                      (funcall compile)))
  :pathname "src/doc"
  :serial t
  :components ((:file "package")
               (:file "generate-documentation")
               (:file "markdown")
               (:file "hugo")))

(asdf:defsystem #:coalton/tests
  :description "Tests for COALTON."
  :author "Coalton contributors (https://github.com/coalton-lang/coalton)"
  :license "MIT"
  :depends-on (#:coalton
               #:fiasco
               #:coalton-json/tests
               #:quil-coalton/tests
               #:thih-coalton/tests)
  :perform (asdf:test-op (o s)
                         (unless (symbol-call :coalton-tests :run-coalton-tests)
                           (error "Tests failed")))
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "utilities")
               (:file "coalton-native-test-utils")
               (:file "toplevel-walker-tests")
               (:file "tarjan-scc-tests")
               (:file "type-inference-tests")
               (:file "runtime-tests")
               (:file "environment-persist-tests")
               (:file "slice-tests")
               (:file "quantize-tests")
               (:file "hashtable-tests")
               (:file "iterator-tests")))
