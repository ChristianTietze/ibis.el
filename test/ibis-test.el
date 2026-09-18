;;; ibis-test.el --- Tests for ibis.el -*- lexical-binding: t; -*-

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

(provide 'ibis-test)

;;; ibis-test.el ends here
