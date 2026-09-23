;;; ibis-test.el --- Tests for ibis.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Christian Tietze
;; Author: Christian Tietze <me@christiantietze.de>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; ERT tests for the vocabulary, graph, parser and serializer.

;;; Code:

(require 'ert)
(require 'ibis)

(ert-deftest ibis-test-namespace ()
  (should (equal ibis-namespace "https://vocab.methodandstructure.com/ibis#")))

(ert-deftest ibis-test-class-p ()
  (should (ibis-class-p 'issue))
  (should (ibis-class-p 'network))
  (should-not (ibis-class-p 'skos:Concept)))

(ert-deftest ibis-test-class-parent ()
  (should (eq (ibis-class-parent 'network) 'skos:ConceptScheme))
  (should (eq (ibis-class-parent 'argument) 'issue))
  (should (eq (ibis-class-parent 'entity) 'skos:Concept))
  (should-not (ibis-class-parent 'skos:Concept)))

(ert-deftest ibis-test-subclass-p ()
  (should (ibis-subclass-p 'argument 'state))
  (should (ibis-subclass-p 'issue 'issue))
  (should (ibis-subclass-p 'position 'skos:Concept))
  (should-not (ibis-subclass-p 'position 'issue)))

(ert-deftest ibis-test-disjoint-p ()
  (should (ibis-disjoint-p 'argument 'position))
  (should (ibis-disjoint-p 'position 'issue))
  (should-not (ibis-disjoint-p 'argument 'issue))
  (should-not (ibis-disjoint-p 'issue 'issue)))

(ert-deftest ibis-test-property-lookup ()
  (should (eq (ibis-property-range (ibis-property 'suggests)) 'issue))
  (should (eq (ibis-property-domain (ibis-property 'suggests)) 'entity))
  (should (eq (ibis-property-name (ibis-property 'response)) 'response))
  (should (eq (ibis-property-parent (ibis-property 'specializes)) 'skos:broader))
  (should-not (ibis-property 'nonesuch)))

(ert-deftest ibis-test-inverse ()
  (should (eq (ibis-inverse 'questions) 'questioned-by))
  (should (eq (ibis-inverse 'responds-to) 'response))
  (should-not (ibis-inverse 'nonesuch)))

(ert-deftest ibis-test-label ()
  (should (equal (ibis-label 'response) "Has Response"))
  (should (equal (ibis-label 'responds-to) "Responds to"))
  (should (equal (ibis-label 'issue) "Issue"))
  (should (equal (ibis-label 'position) "Position"))
  (should (equal (ibis-label 'argument) "Argument"))
  (should-not (ibis-label 'nonesuch)))

(ert-deftest ibis-test-preferred ()
  (should (eq (ibis-preferred 'supported-by) 'supports))
  (should (eq (ibis-preferred 'specializes) 'generalizes))
  (should (eq (ibis-preferred 'response) 'responds-to))
  (should (eq (ibis-preferred 'questions) 'questions)))

(ert-deftest ibis-test-inverse-of-inverse-is-self ()
  (dolist (name (ibis--property-names))
    (let* ((prop (ibis-property name))
           (back (ibis-property (ibis-property-inverse prop))))
      (should (eq (ibis-property-inverse back) name))
      (should (eq (ibis-property-domain back) (ibis-property-range prop)))
      (should (eq (ibis-property-range back) (ibis-property-domain prop))))))

(ert-deftest ibis-test-legal-properties ()
  (should (equal (ibis-legal-properties 'position 'argument)
                 '(supported-by opposed-by responds-to)))
  (should (equal (ibis-legal-properties 'position 'position)
                 '(generalizes specializes)))
  (should-not (ibis-legal-properties 'network 'issue)))

(ert-deftest ibis-test-relation-legal-p ()
  (should (ibis-relation-legal-p 'argument 'supports 'position))
  (should (ibis-relation-legal-p 'position 'responds-to 'issue))
  (should-not (ibis-relation-legal-p 'issue 'supports 'position))
  (should-not (ibis-relation-legal-p 'position 'supports 'argument)))

(ert-deftest ibis-test-legality-respects-domain-and-range ()
  (pcase-dolist (`((,subject . ,object) . ,names) ibis--legality)
    (dolist (name names)
      (let ((prop (ibis-property name)))
        (should prop)
        (should (ibis-subclass-p subject (ibis-property-domain prop)))
        (should (ibis-subclass-p object (ibis-property-range prop)))))))

(defun ibis-test--sample-network ()
  "Return a network of one issue with two positions attached."
  (let* ((network (make-ibis-network))
         (issue (ibis-network-add-node
                 network (make-ibis-node :id "I-1" :class 'issue :text "Wie?")))
         (first (ibis-network-add-node
                 network (make-ibis-node :class 'position :text "So")))
         (second (ibis-network-add-node
                  network (make-ibis-node :class 'position :text "Anders"))))
    (ibis-network-add-edge network first 'responds-to issue)
    (ibis-network-add-edge network second 'responds-to issue)
    network))

(ert-deftest ibis-test-network-node-by-id ()
  (let* ((network (ibis-test--sample-network))
         (issue (ibis-network-node-by-id network "I-1")))
    (should (eq issue (car (ibis-network-nodes network))))
    (should (equal (ibis-node-text issue) "Wie?"))
    (should-not (ibis-network-node-by-id network "I-9"))))

(ert-deftest ibis-test-node-parent-and-children ()
  (let* ((network (ibis-test--sample-network))
         (nodes (ibis-network-nodes network))
         (issue (nth 0 nodes))
         (first (nth 1 nodes))
         (second (nth 2 nodes)))
    (should (eq (ibis-node-parent network first) issue))
    (should (eq (ibis-node-parent network second) issue))
    (should-not (ibis-node-parent network issue))
    (should (equal (ibis-node-children network issue) (list first second)))
    (should-not (ibis-node-children network first))))

(ert-deftest ibis-test-network-add-edge ()
  (let* ((network (ibis-test--sample-network))
         (edge (car (ibis-network-edges network))))
    (should (= (length (ibis-network-edges network)) 2))
    (should (eq (ibis-edge-predicate edge) 'responds-to))
    (should (eq (ibis-edge-subject edge) (nth 1 (ibis-network-nodes network))))
    (should (eq (ibis-edge-object edge) (nth 0 (ibis-network-nodes network))))))

(ert-deftest ibis-test-parse-line-position ()
  (should (equal (ibis--parse-line "  \u2192 Ja")
                 '(:column 2 :marker position :id nil :text "Ja" :tags nil)))
  (should (equal (ibis--parse-line "-> x")
                 '(:column 0 :marker position :id nil :text "x" :tags nil))))

(ert-deftest ibis-test-parse-line-id-and-tags ()
  (should (equal (ibis--parse-line "? I-1: Wie denn? #pr\u00fcfen #Empfehlung")
                 '(:column 0 :marker issue :id "I-1" :text "Wie denn?"
                           :tags ("pr\u00fcfen" "Empfehlung")))))

(ert-deftest ibis-test-parse-line-argument-markers ()
  (should (eq (plist-get (ibis--parse-line "    + Gut.") :marker) 'pro))
  (should (eq (plist-get (ibis--parse-line "    - Schlecht.") :marker) 'con))
  (should (= (plist-get (ibis--parse-line "    - Schlecht.") :column) 4)))

(ert-deftest ibis-test-parse-line-hash-inside-text-is-text ()
  (should (equal (plist-get (ibis--parse-line "? Was ist #1 wert?") :text)
                 "Was ist #1 wert?"))
  (should-not (plist-get (ibis--parse-line "? Was ist #1 wert?") :tags)))

(ert-deftest ibis-test-parse-line-rejects-non-ibis-lines ()
  (should-not (ibis--parse-line "foo"))
  (should-not (ibis--parse-line ""))
  (should-not (ibis--parse-line "?nospace"))
  (should-not (ibis--parse-line "\t? tab indent")))

(defconst ibis-test--fixture
  (expand-file-name "fixtures/beispiel.ibis"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Path of the German example map used by the tests.")

(defun ibis-test--fixture-string ()
  "Return the contents of `ibis-test--fixture' as a string."
  (let ((coding-system-for-read 'utf-8))
    (with-temp-buffer
      (insert-file-contents ibis-test--fixture)
      (buffer-string))))

(defun ibis-test--fixture-network ()
  "Return the network parsed from `ibis-test--fixture'."
  (car (ibis-parse-string (ibis-test--fixture-string))))

(defun ibis-test--roots (network)
  "Return the nodes of NETWORK that have no parent."
  (seq-remove (lambda (node) (ibis-node-parent network node))
              (ibis-network-nodes network)))

(ert-deftest ibis-test-tree-rule-lenient ()
  (should (eq (ibis--tree-rule 'issue 'issue nil) 'specializes))
  (should (eq (ibis--tree-rule 'issue 'position nil) 'questions))
  (should (eq (ibis--tree-rule 'issue 'argument nil) 'questions))
  (should (eq (ibis--tree-rule 'position 'issue nil) 'responds-to))
  (should (eq (ibis--tree-rule 'position 'position nil) 'specializes))
  (should (eq (ibis--tree-rule 'position 'argument nil) 'responds-to))
  (should (eq (ibis--tree-rule 'pro 'position nil) 'supports))
  (should (eq (ibis--tree-rule 'con 'position nil) 'opposes)))

(ert-deftest ibis-test-tree-rule-errors ()
  (should (equal (ibis--tree-rule 'pro 'issue nil)
                 "Argument must support a position"))
  (should (equal (ibis--tree-rule 'con 'argument nil)
                 "Argument must support a position"))
  (should (equal (ibis--tree-rule 'position 'position t)
                 "Position must respond to an issue"))
  (should (equal (ibis--tree-rule 'position 'argument t)
                 "Position must respond to an issue")))

(ert-deftest ibis-test-parse-fixture-roots ()
  (let* ((result (ibis-parse-string (ibis-test--fixture-string)))
         (network (car result))
         (roots (ibis-test--roots network)))
    (should-not (cdr result))
    (should (= (length roots) 6))
    (should (equal (mapcar #'ibis-node-id roots)
                   '("I-1" "I-2" "I-3" "I-4" "I-5" "I-6")))
    (should (seq-every-p (lambda (node) (eq (ibis-node-class node) 'issue))
                         roots))))

(ert-deftest ibis-test-parse-fixture-i4-edges ()
  (let* ((network (ibis-test--fixture-network))
         (from (ibis-node-beg (ibis-network-node-by-id network "I-4")))
         (to (ibis-node-beg (ibis-network-node-by-id network "I-5")))
         (edges (seq-filter
                 (lambda (edge)
                   (let ((beg (ibis-node-beg (ibis-edge-subject edge))))
                     (and (> beg from) (< beg to))))
                 (ibis-network-edges network))))
    (should (equal (mapcar #'ibis-edge-predicate edges)
                   '(responds-to opposes responds-to supports specializes
                                 questions questions)))))

(ert-deftest ibis-test-parse-fixture-tags ()
  (let* ((network (ibis-test--fixture-network))
         (tagged (seq-filter #'ibis-node-tags (ibis-network-nodes network))))
    (should (equal (mapcar #'ibis-node-tags tagged)
                   '(("prüfen") ("prüfen") ("Empfehlung") ("festgehalten")
                     ("prüfen"))))))

(ert-deftest ibis-test-parse-fixture-node-beg-is-line-start ()
  (let* ((text (ibis-test--fixture-string))
         (network (car (ibis-parse-string text))))
    (with-temp-buffer
      (insert text)
      (dolist (node (ibis-network-nodes network))
        (goto-char (ibis-node-beg node))
        (should (bolp))
        (should (string-search
                 (ibis-node-text node)
                 (buffer-substring-no-properties (line-beginning-position)
                                                 (line-end-position))))))))

(ert-deftest ibis-test-fixture-edges-are-legal ()
  (let ((network (ibis-test--fixture-network)))
    (should (ibis-network-edges network))
    (dolist (edge (ibis-network-edges network))
      (should (ibis-relation-legal-p
               (ibis-node-class (ibis-edge-subject edge))
               (ibis-edge-predicate edge)
               (ibis-node-class (ibis-edge-object edge)))))))

(ert-deftest ibis-test-diagnostic-argument-under-issue ()
  (let ((diagnostics (cdr (ibis-parse-string "? a\n  + b"))))
    (should (equal diagnostics '((5 . "Argument must support a position"))))))

(ert-deftest ibis-test-diagnostic-top-level-must-be-issue ()
  (should (equal (cdr (ibis-parse-string "→ a"))
                 '((1 . "Top-level node must be an issue")))))

(ert-deftest ibis-test-diagnostic-indented-without-parent ()
  (should (equal (cdr (ibis-parse-string "  ? a"))
                 '((1 . "Indented line has no parent")))))

(ert-deftest ibis-test-diagnostic-not-an-ibis-line ()
  (should (equal (cdr (ibis-parse-string "? a\nplain"))
                 '((5 . "Not an IBIS line")))))

(ert-deftest ibis-test-erroneous-node-is-still-a-parent ()
  (let* ((result (ibis-parse-string "→ a\n  + b"))
         (network (car result)))
    (should (= (length (cdr result)) 1))
    (should (= (length (ibis-network-nodes network)) 2))
    (should (equal (mapcar #'ibis-edge-predicate (ibis-network-edges network))
                   '(supports)))))

(ert-deftest ibis-test-erroneous-node-gets-no-edge ()
  (let ((network (car (ibis-parse-string "? a\n  + b"))))
    (should (= (length (ibis-network-nodes network)) 2))
    (should-not (ibis-network-edges network))))

(ert-deftest ibis-test-strict-grammar-flags-nested-positions ()
  (let* ((ibis-strict-grammar t)
         (result (ibis-parse-string (ibis-test--fixture-string)))
         (diagnostics (cdr result)))
    (should (= (length diagnostics) 3))
    (should (seq-every-p (lambda (entry)
                           (equal (cdr entry) "Position must respond to an issue"))
                         diagnostics))
    (should (equal (mapcar #'car diagnostics)
                   (sort (mapcar #'car diagnostics) #'<)))))

(defun ibis-test--round-trip (string)
  "Return STRING parsed into a network and serialized back."
  (ibis-serialize (car (ibis-parse-string string))))

(ert-deftest ibis-test-serialize-normalizes-markers ()
  (should (equal (ibis-test--round-trip "? a\n  -> b") "? a\n  → b\n")))

(ert-deftest ibis-test-serialize-omits-absent-ids ()
  (should (equal (ibis-test--round-trip "? I-1: a\n  → b\n    + c\n    - d")
                 "? I-1: a\n  → b\n    + c\n    - d\n")))

(ert-deftest ibis-test-serialize-appends-tags ()
  (should (equal (ibis-test--round-trip "? a #x #y") "? a #x #y\n")))

(ert-deftest ibis-test-serialize-separates-roots-with-blank-line ()
  (should (equal (ibis-test--round-trip "? a\n\n? b") "? a\n\n? b\n")))

(ert-deftest ibis-test-serialize-round-trips-the-fixture ()
  (let ((text (ibis-test--fixture-string)))
    (should (equal (ibis-test--round-trip text) text))))

(ert-deftest ibis-test-parse-line-ignores-trailing-whitespace-after-tags ()
  (should (equal (ibis--parse-line "? a #x  ")
                 '(:column 0 :marker issue :id nil :text "a" :tags ("x")))))

(provide 'ibis-test)

;;; ibis-test.el ends here
