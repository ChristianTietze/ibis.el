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

(cl-defstruct (ibis-property (:constructor ibis--make-property)
                             (:copier nil))
  "A property of the IBIS vocabulary.

NAME is the local name as a symbol, LABEL its human-readable name,
DOMAIN and RANGE the class symbols it relates (nil when unstated),
INVERSE the name of its inverse property, and PARENT the property
it specializes."
  name label domain range inverse parent)

(defconst ibis--property-table
  '((concerns "Concerns" skos:Concept nil concern-of nil)
    (concern-of "Concern of" nil skos:Concept concerns nil)
    (involves "Involves" skos:Concept foaf:Agent involvement concerns)
    (involvement "Involvement" foaf:Agent skos:Concept involves concern-of)
    (endorses "Endorses" foaf:Agent entity endorsed-by involvement)
    (endorsed-by "Endorsed By" entity foaf:Agent endorses involves)
    (principal "Principal" skos:Concept foaf:Agent principal-of involves)
    (principal-of "Principal of" foaf:Agent skos:Concept principal involvement)
    (generalizes "Generalizes" entity entity specializes skos:narrower)
    (specializes "Specializes" entity entity generalizes skos:broader)
    (replaces "Replaces" entity entity replaced-by dct:replaces)
    (replaced-by "Replaced By" entity entity replaces dct:isReplacedBy)
    (implies "Implies" entity state implied-by skos:semanticRelation)
    (implied-by "Implied By" state entity implies skos:semanticRelation)
    (suggests "Suggests" entity issue suggested-by implies)
    (suggested-by "Suggested By" issue entity suggests implied-by)
    (questions "Questions" issue entity questioned-by suggested-by)
    (questioned-by "Questioned By" entity issue questions suggests)
    (response "Has Response" issue position responds-to skos:semanticRelation)
    (responds-to "Responds to" position issue response skos:semanticRelation)
    (supports "Supports" argument position supported-by suggested-by)
    (supported-by "Supported By" position argument supports suggests)
    (opposes "Opposes" argument position opposed-by suggested-by)
    (opposed-by "Opposed By" position argument opposes suggests))
  "The IBIS properties as (NAME LABEL DOMAIN RANGE INVERSE PARENT) rows.")

(defconst ibis--properties
  (let ((table (make-hash-table :test #'eq)))
    (pcase-dolist (`(,name ,label ,domain ,range ,inverse ,parent)
                   ibis--property-table)
      (puthash name (ibis--make-property :name name :label label
                                         :domain domain :range range
                                         :inverse inverse :parent parent)
               table))
    table)
  "Hash table mapping a property name to its `ibis-property' struct.")

(defconst ibis--class-labels
  '((entity . "Entity")
    (state . "State")
    (issue . "Issue")
    (position . "Position")
    (argument . "Argument")
    (invariant . "Invariant")
    (network . "Network"))
  "Alist mapping an IBIS class symbol to its human-readable label.")

(defconst ibis--preferred
  '((specializes . generalizes)
    (replaced-by . replaces)
    (questioned-by . questions)
    (suggested-by . suggests)
    (response . responds-to)
    (supported-by . supports)
    (opposed-by . opposes))
  "Alist mapping a property to the direction preferred for display.")

(defun ibis-property (name)
  "Return the `ibis-property' struct called NAME, or nil."
  (gethash name ibis--properties))

(defun ibis--property-names ()
  "Return the names of all IBIS properties in vocabulary order."
  (mapcar #'car ibis--property-table))

(defun ibis-inverse (name)
  "Return the name of the property inverse to NAME, or nil."
  (let ((prop (ibis-property name)))
    (and prop (ibis-property-inverse prop))))

(defun ibis-label (symbol)
  "Return the label of the property or class SYMBOL, or nil."
  (let ((prop (ibis-property symbol)))
    (if prop
        (ibis-property-label prop)
      (cdr (assq symbol ibis--class-labels)))))

(defun ibis-preferred (name)
  "Return the preferred direction of property NAME, NAME itself by default."
  (or (cdr (assq name ibis--preferred)) name))

(provide 'ibis)

;;; ibis.el ends here
