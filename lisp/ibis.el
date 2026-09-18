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

(defconst ibis--legality
  '(((issue . issue)
     . (generalizes specializes suggests suggested-by questions questioned-by))
    ((issue . position) . (response suggested-by questions))
    ((issue . argument) . (suggests suggested-by questions questioned-by))
    ((position . issue) . (responds-to suggests questioned-by))
    ((position . position) . (generalizes specializes))
    ((position . argument) . (supported-by opposed-by responds-to))
    ((argument . issue) . (suggests suggested-by questions questioned-by))
    ((argument . position) . (supports opposes questions suggested-by response))
    ((argument . argument)
     . (generalizes specializes suggests suggested-by questions questioned-by)))
  "Alist mapping a (SUBJECT . OBJECT) class pair to the properties joining them.")

(defun ibis-legal-properties (subject object)
  "Return the properties that may relate a SUBJECT class to an OBJECT class."
  (cdr (assoc (cons subject object) ibis--legality)))

(defun ibis-relation-legal-p (subject predicate object)
  "Return non-nil when PREDICATE may relate class SUBJECT to class OBJECT."
  (and (memq predicate (ibis-legal-properties subject object)) t))

(cl-defstruct (ibis-node (:copier nil))
  "A node of an IBIS network.

ID is the optional identifier written in the file, CLASS one of
`issue', `position' or `argument', TEXT the node's prose, TAGS its
hashtags without the leading `#', and BEG the buffer position the
node was parsed from."
  id class text tags beg)

(cl-defstruct (ibis-edge (:copier nil))
  "A directed relation between two `ibis-node' structs.

SUBJECT and OBJECT are nodes compared by identity, PREDICATE is an
IBIS property name."
  subject predicate object)

(cl-defstruct (ibis-network (:copier nil))
  "An IBIS network holding NODES and EDGES in document order."
  nodes edges)

(defun ibis-network-add-node (network node)
  "Append NODE to NETWORK and return NODE."
  (setf (ibis-network-nodes network)
        (append (ibis-network-nodes network) (list node)))
  node)

(defun ibis-network-add-edge (network subject predicate object)
  "Append an edge SUBJECT PREDICATE OBJECT to NETWORK and return it."
  (let ((edge (make-ibis-edge :subject subject :predicate predicate
                              :object object)))
    (setf (ibis-network-edges network)
          (append (ibis-network-edges network) (list edge)))
    edge))

(defun ibis-network-node-by-id (network id)
  "Return the node of NETWORK whose identifier is ID, or nil."
  (seq-find (lambda (node) (equal (ibis-node-id node) id))
            (ibis-network-nodes network)))

(defun ibis--node-edge (network node)
  "Return the edge attaching NODE to its parent in NETWORK, or nil."
  (seq-find (lambda (edge) (eq (ibis-edge-subject edge) node))
            (ibis-network-edges network)))

(defun ibis-node-parent (network node)
  "Return the node NODE attaches to in NETWORK, or nil when it is a root."
  (let ((edge (ibis--node-edge network node)))
    (and edge (ibis-edge-object edge))))

(defun ibis-node-children (network node)
  "Return the nodes attached to NODE in NETWORK, in edge order."
  (mapcar #'ibis-edge-subject
          (seq-filter (lambda (edge) (eq (ibis-edge-object edge) node))
                      (ibis-network-edges network))))

(rx-define ibis-marker-rx (or "?" "→" "->" "+" "-"))

(defconst ibis--markers
  '(("?" . issue)
    ("→" . position)
    ("->" . position)
    ("+" . pro)
    ("-" . con))
  "Alist mapping a line marker to its marker symbol.")

(defconst ibis--line-rx
  (rx bol
      (group (zero-or-more " "))
      (group ibis-marker-rx)
      (one-or-more " ")
      (opt (group (one-or-more (in alnum ?- ?_ ?.))) ":" (zero-or-more " "))
      (group (minimal-match (zero-or-more nonl)))
      (group (zero-or-more " #" (one-or-more (not (in " \t")))))
      eol)
  "Regexp matching one line of an `.ibis' file.

The groups are indent, marker, identifier, text and trailing hashtags.")

(defun ibis--marker-class (marker)
  "Return the IBIS class a MARKER symbol denotes."
  (if (memq marker '(pro con)) 'argument marker))

(defun ibis--parse-tags (string)
  "Return the hashtags in STRING as a list of names without the `#'."
  (mapcar (lambda (tag) (substring tag 1))
          (split-string (or string "") " " t)))

(defun ibis--parse-line (line)
  "Return a plist describing LINE, or nil when LINE is not an IBIS line.

The plist has the keys :column, :marker, :id, :text and :tags."
  (when (string-match ibis--line-rx line)
    (list :column (length (match-string 1 line))
          :marker (cdr (assoc (match-string 2 line) ibis--markers))
          :id (match-string 3 line)
          :text (string-trim (match-string 4 line))
          :tags (ibis--parse-tags (match-string 5 line)))))

(defcustom ibis-strict-grammar nil
  "Non-nil enforces Conklin's stricter nesting rules while parsing.

Under it a position may only respond to an issue; the lenient
default also reads a position nested under a position or argument."
  :type 'boolean
  :group 'ibis)

(defconst ibis--argument-error "Argument must support a position"
  "Diagnostic for an argument nested anywhere but under a position.")

(defconst ibis--position-error "Position must respond to an issue"
  "Diagnostic for a position nested under a non-issue in strict mode.")

(defun ibis--tree-rule (marker parent-class strict)
  "Return the predicate relating a MARKER child to its PARENT-CLASS parent.

Return a diagnostic message string instead when the nesting is not
allowed.  STRICT non-nil applies `ibis-strict-grammar' semantics."
  (pcase (cons marker parent-class)
    ('(issue . issue) 'specializes)
    ('(issue . position) 'questions)
    ('(issue . argument) 'questions)
    ('(position . issue) 'responds-to)
    ('(position . position) (if strict ibis--position-error 'specializes))
    ('(position . argument) (if strict ibis--position-error 'responds-to))
    ('(pro . position) 'supports)
    ('(con . position) 'opposes)
    (_ ibis--argument-error)))

(defun ibis-parse-buffer ()
  "Parse the current buffer and return a cons of network and diagnostics.

Diagnostics are an alist of (POSITION . MESSAGE) in document order."
  (let ((network (make-ibis-network))
        (stack nil)
        (diagnostics nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((beg (line-beginning-position))
               (line (buffer-substring-no-properties beg (line-end-position))))
          (unless (string-blank-p line)
            (let ((parsed (ibis--parse-line line)))
              (if (null parsed)
                  (push (cons beg "Not an IBIS line") diagnostics)
                (let* ((column (plist-get parsed :column))
                       (marker (plist-get parsed :marker))
                       (node (ibis-network-add-node
                              network
                              (make-ibis-node
                               :id (plist-get parsed :id)
                               :class (ibis--marker-class marker)
                               :text (plist-get parsed :text)
                               :tags (plist-get parsed :tags)
                               :beg beg))))
                  (while (and stack (>= (caar stack) column))
                    (pop stack))
                  (cond
                   ((zerop column)
                    (unless (eq marker 'issue)
                      (push (cons beg "Top-level node must be an issue")
                            diagnostics)))
                   ((null stack)
                    (push (cons beg "Indented line has no parent") diagnostics))
                   (t
                    (let* ((parent (cdar stack))
                           (rule (ibis--tree-rule marker
                                                  (ibis-node-class parent)
                                                  ibis-strict-grammar)))
                      (if (stringp rule)
                          (push (cons beg rule) diagnostics)
                        (ibis-network-add-edge network node rule parent)))))
                  (push (cons column node) stack))))))
        (forward-line 1)))
    (cons network (nreverse diagnostics))))

(defun ibis-parse-string (string)
  "Parse STRING as an IBIS document and return a cons of network and diagnostics."
  (with-temp-buffer
    (insert string)
    (ibis-parse-buffer)))

(defun ibis--node-marker (network node)
  "Return the marker string written for NODE in NETWORK."
  (pcase (ibis-node-class node)
    ('issue "?")
    ('position "→")
    (_ (let ((edge (ibis--node-edge network node)))
         (if (eq (and edge (ibis-edge-predicate edge)) 'opposes) "-" "+")))))

(defun ibis--serialize-node (network node depth)
  "Return the lines for NODE and its children in NETWORK, indented by DEPTH."
  (apply #'concat
         (concat (make-string (* 2 depth) ?\s)
                 (ibis--node-marker network node) " "
                 (if (ibis-node-id node) (concat (ibis-node-id node) ": ") "")
                 (ibis-node-text node)
                 (mapconcat (lambda (tag) (concat " #" tag))
                            (ibis-node-tags node) "")
                 "\n")
         (mapcar (lambda (child) (ibis--serialize-node network child (1+ depth)))
                 (ibis-node-children network node))))

(defun ibis-serialize (network)
  "Return the `.ibis' text of NETWORK, one blank line between its roots."
  (mapconcat (lambda (root) (ibis--serialize-node network root 0))
             (seq-remove (lambda (node) (ibis-node-parent network node))
                         (ibis-network-nodes network))
             "\n"))

(provide 'ibis)

;;; ibis.el ends here
