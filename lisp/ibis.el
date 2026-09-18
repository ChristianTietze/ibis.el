;;; ibis.el --- IBIS vocabulary, graph and .ibis text format -*- lexical-binding: t; -*-

;; Author: Christian Tietze
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: outlines, wp
;; URL: https://codeberg.org/ctietze/ibis.el

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Issue-Based Information Systems (Kunz & Rittel, 1970) as data:
;; Dorian Taylor's IBIS vocabulary, a small in-memory graph, and a
;; parser and serializer for the `.ibis' plain-text format that
;; `ibis-mode' edits.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst ibis-namespace "https://vocab.methodandstructure.com/ibis#"
  "Namespace URI of the IBIS vocabulary.")

(defconst ibis-version "0.7"
  "Version of the IBIS vocabulary encoded here.")

(defgroup ibis nil
  "Issue-Based Information Systems in plain text."
  :group 'text
  :prefix "ibis-")

(defconst ibis--classes
  '((entity . skos:Concept)
    (state . entity)
    (issue . state)
    (position . entity)
    (argument . issue)
    (invariant . entity)
    (network . skos:ConceptScheme))
  "Alist mapping each IBIS class symbol to its parent class.

Parents outside the IBIS vocabulary are opaque symbols such as
`skos:Concept' and are not themselves IBIS classes.")

(defconst ibis--disjoint
  '((issue . position)
    (position . argument))
  "Unordered pairs of IBIS classes that cannot share an instance.")

(defun ibis-class-p (class)
  "Return non-nil when CLASS is a class of the IBIS vocabulary."
  (and (assq class ibis--classes) t))

(defun ibis-class-parent (class)
  "Return the parent of CLASS, or nil when CLASS is not an IBIS class."
  (cdr (assq class ibis--classes)))

(defun ibis-subclass-p (sub super)
  "Return non-nil when SUB is SUPER or descends from it."
  (or (eq sub super)
      (let ((parent (ibis-class-parent sub)))
        (and parent (ibis-subclass-p parent super)))))

(defun ibis-disjoint-p (class other)
  "Return non-nil when CLASS and OTHER are declared disjoint."
  (and (or (member (cons class other) ibis--disjoint)
           (member (cons other class) ibis--disjoint))
       t))

(provide 'ibis)

;;; ibis.el ends here
