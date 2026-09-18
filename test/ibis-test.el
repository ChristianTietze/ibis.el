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

(provide 'ibis-test)

;;; ibis-test.el ends here
