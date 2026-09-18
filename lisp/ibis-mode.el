;;; ibis-mode.el --- Major mode for .ibis issue maps -*- lexical-binding: t; -*-

;; Author: Christian Tietze
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (ibis "0.1.0"))
;; Keywords: outlines, wp
;; URL: https://codeberg.org/ctietze/ibis.el

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Editing support for `.ibis' files: an indented outline of issues
;; (`?'), positions (`→') and arguments (`+' / `-'), backed by the
;; vocabulary and parser in `ibis.el'.

;;; Code:

(require 'ibis)

(provide 'ibis-mode)

;;; ibis-mode.el ends here
