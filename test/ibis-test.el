;;; ibis-test.el --- Tests for ibis.el -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for the vocabulary, graph, parser and serializer.

;;; Code:

(require 'ert)
(require 'ibis)

(ert-deftest ibis-test-namespace ()
  (should (equal ibis-namespace "https://vocab.methodandstructure.com/ibis#")))

(provide 'ibis-test)

;;; ibis-test.el ends here
