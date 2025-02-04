;;;; toplevel-define.lisp

(in-package #:coalton-impl)

;;; Handling of top-level COALTON:DEFINE.

(defun parse-define-form (form package env &key (skip-inherited-symbol-checks nil))
  "Parse a COALTON:DEFINE form."
  (declare (type list form)
           (type package package)
           (type environment env)
           (values symbol node (or null string) &optional))
  (assert (and (eql (first form) 'coalton:define)
               (or (= 3 (length form))   ; Without docstring
                   (= 4 (length form)))) ; With docstring
          () "Malformed DEFINE form ~A" form)
  ;; Defines either define a value or a function. Values and functions
  ;; in Coalton occupy the namespace, but the intent of the user can
  ;; be distinguished. A definition either looks like:
  ;;
  ;;     (DEFINE <var> <val>)
  ;;
  ;; or
  ;;
  ;;     (DEFINE (<fvar> <arg>*) <val>)
  ;;
  ;; The former defines a variable, the latter defines a function.
  (let* ((parse-docstring? (= 4 (length form)))
         (var-thing (second form))
         (val (if parse-docstring?
                  (fourth form)
                  (third form)))
         (docstring (when parse-docstring?
                      (third form))))
    (cond
      ((null var-thing)
       (error-parsing form "Found a null value where a symbol or function ~
                            was expected."))
      ((symbolp var-thing)
       (parse-define-form-variable var-thing val docstring package env :skip-inherited-symbol-checks skip-inherited-symbol-checks))
      ((and (listp var-thing)
            (every #'symbolp var-thing))
       ;; Disallow zero arity functions
       (unless (>= (length var-thing) 2)
         (error-parsing form "Unable to define function with arity ~A" (1- (length var-thing))))
       (parse-define-form-function (first var-thing) (rest var-thing) val docstring package env :skip-inherited-symbol-checks skip-inherited-symbol-checks))
      (t
       (error-parsing form "Invalid second argument.")))))

(defun parse-define-form-variable (var val docstring package env &key (skip-inherited-symbol-checks nil))
  (declare (type symbol var)
           (type t val)
           (type package package)
           (type environment env)
           (ignore env)
           (values symbol node (or null string)))
  ;; The (DEFINE <var> <val>) case.
  ;; XXX: Should this be LETREC too? Probably for something like F = x => ... F.
  (unless (or skip-inherited-symbol-checks (equalp package (symbol-package var)))
    (error-inherited-symbol
     var
     package))
  (values var
          (parse-form val (make-immutable-map) package)
          docstring))

(defun parse-define-form-function (fvar args val docstring package env &key (skip-inherited-symbol-checks nil))
  (declare (type symbol fvar)
           (type list args)
           (type t val)
           (type package package)
           (type environment env)
           (ignore env)
           (values symbol node (or null string)))
  ;; The (DEFINE (<fvar> . <args>) <val>) case.
  (unless (or skip-inherited-symbol-checks (equalp package (symbol-package fvar)))
    (error-inherited-symbol
     fvar
     package))
  (values fvar
          (parse-form `(coalton:fn ,args ,val) (make-immutable-map) package)
          docstring))

(defun process-toplevel-value-definitions (def-forms declared-types package env)
  "Parse all coalton DEFINE forms in DEF-FORMS, optionally with declared types

Returns new environment, binding list of declared nodes, and a DAG of dependencies"
  (declare (type package package)
           (values environment typed-binding-list list list))

  (let* ((docstrings nil)
         (parsed (loop :for form :in def-forms
                       :collect (multiple-value-bind (name node docstring)
                                    (parse-define-form form package env)
                                  (push (list name docstring) docstrings)
                                  (cons name node))))
         (expl-names (alexandria:hash-table-keys declared-types))
         (impl-bindings nil)
         (expl-bindings nil))

    ;; Sort our bindings into implicit and explicit
    (loop :for binding :in parsed
          :do
             (if (member (car binding) expl-names :test #'eql)
                 (push binding expl-bindings)
                 (push binding impl-bindings)))

    ;; Assert that there are no orphan declares
    (loop :for name :in expl-names :do
      (assert (member name expl-bindings :key #'car)
              () "Orphan type declaration for variable ~A" name))

    (coalton-impl/typechecker::with-type-context ("COALTON-TOPLEVEL")
      (multiple-value-bind (typed-bindings preds new-env subs)
          (coalton-impl/typechecker::derive-bindings-type
           impl-bindings expl-bindings declared-types env nil nil
           :disable-monomorphism-restriction t
           :allow-deferred-predicates nil)
        (when preds
          (coalton-bug "Preds not expected. ~A" preds))

        ;; Apply output substitutions
        (setf typed-bindings
              (mapcar (lambda (binding)
                        (cons
                         (car binding)
                         (coalton-impl/typechecker::apply-substitution subs (cdr binding))))
                      typed-bindings))

        ;; Update the current environment with any updated types
        (setf env (coalton-impl/typechecker::apply-substitution subs new-env))

        ;; Checks for monomorphism restriction for top level bindings
        (dolist (b typed-bindings)
          (with-type-context ("definition of ~A" (car b))
            (let* ((type (coalton-impl/typechecker::fresh-inst (lookup-value-type env (car b))))

                   (preds (reduce-context env (coalton-impl/typechecker::qualified-ty-predicates type) subs
                                          :allow-deferred-predicates nil)))
              (when (and (not (gethash (car b) declared-types))
                         (not (coalton-impl/typechecker::typed-node-abstraction-p (cdr b)))
                         (not (null preds)))
                (error 'toplevel-monomorphism-restriction
                       :type type
                       :name (car b))))))

        (loop :for (name . node) :in typed-bindings :do
          (progn
            (when *coalton-dump-ast*
              (format t "~A :: ~A~%~A~%~%" name (lookup-value-type env name) node))
            (setf env (set-name env name
                                (make-name-entry
                                 :name name
                                 :type :value
                                 :docstring (second (find name docstrings :key #'car))
                                 :location (or *compile-file-pathname* *load-truename*))))))

        (values
         env
         typed-bindings
         (reverse
          (tarjan-scc (bindings-to-dag (append impl-bindings expl-bindings)))))))))
