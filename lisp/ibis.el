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

(provide 'ibis)

;;; ibis.el ends here
