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

(defface ibis-issue-face '((t :inherit font-lock-function-name-face))
  "Face for the prose of an issue line."
  :group 'ibis)

(defface ibis-position-face '((t :inherit font-lock-variable-name-face))
  "Face for the prose of a position line."
  :group 'ibis)

(defface ibis-pro-face '((t :inherit success))
  "Face for the prose of a supporting argument."
  :group 'ibis)

(defface ibis-con-face '((t :inherit error))
  "Face for the prose of an opposing argument."
  :group 'ibis)

(defface ibis-issue-marker-face '((t :inherit ibis-issue-face :weight bold))
  "Face for the `?' marker of an issue line."
  :group 'ibis)

(defface ibis-position-marker-face
  '((t :inherit ibis-position-face :weight bold))
  "Face for the `→' marker of a position line."
  :group 'ibis)

(defface ibis-pro-marker-face '((t :inherit ibis-pro-face :weight bold))
  "Face for the `+' marker of a supporting argument."
  :group 'ibis)

(defface ibis-con-marker-face '((t :inherit ibis-con-face :weight bold))
  "Face for the `-' marker of an opposing argument."
  :group 'ibis)

(defface ibis-id-face '((t :inherit font-lock-constant-face))
  "Face for the identifier of a node."
  :group 'ibis)

(defface ibis-hashtag-face '((t :inherit font-lock-keyword-face))
  "Face for a status hashtag."
  :group 'ibis)

(defconst ibis-mode--font-lock-keywords
  `((,(rx bol (zero-or-more " ")
          (group "?")
          (one-or-more " ")
          (opt (group (one-or-more (in alnum ?- ?_ ?.)) ":")
               (zero-or-more " "))
          (group (zero-or-more nonl))
          eol)
     (1 'ibis-issue-marker-face)
     (2 'ibis-id-face nil t)
     (3 'ibis-issue-face))
    (,(rx bol (zero-or-more " ")
          (group (or "→" "->"))
          (one-or-more " ")
          (opt (group (one-or-more (in alnum ?- ?_ ?.)) ":")
               (zero-or-more " "))
          (group (zero-or-more nonl))
          eol)
     (1 'ibis-position-marker-face)
     (2 'ibis-id-face nil t)
     (3 'ibis-position-face))
    (,(rx bol (zero-or-more " ")
          (group "+")
          (one-or-more " ")
          (opt (group (one-or-more (in alnum ?- ?_ ?.)) ":")
               (zero-or-more " "))
          (group (zero-or-more nonl))
          eol)
     (1 'ibis-pro-marker-face)
     (2 'ibis-id-face nil t)
     (3 'ibis-pro-face))
    (,(rx bol (zero-or-more " ")
          (group "-")
          (one-or-more " ")
          (opt (group (one-or-more (in alnum ?- ?_ ?.)) ":")
               (zero-or-more " "))
          (group (zero-or-more nonl))
          eol)
     (1 'ibis-con-marker-face)
     (2 'ibis-id-face nil t)
     (3 'ibis-con-face))
    (,(rx (or bol " ") (group "#" (one-or-more (not (in " #")))))
     (1 'ibis-hashtag-face prepend)))
  "Font lock keywords highlighting marker, identifier, prose and hashtags.")

;;;###autoload
(define-derived-mode ibis-mode text-mode "IBIS"
  "Major mode for editing `.ibis' issue maps.

Each line carries a marker: `?' for an issue, `→' (or `->') for a
position, `+' and `-' for arguments.  Indentation by two spaces
nests a node under the one above it."
  (setq-local font-lock-defaults '(ibis-mode--font-lock-keywords t))
  (setq-local require-final-newline t)
  (setq-local comment-start nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ibis\\'" . ibis-mode))

(provide 'ibis-mode)

;;; ibis-mode.el ends here
