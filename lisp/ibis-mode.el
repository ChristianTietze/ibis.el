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
(require 'imenu)
(require 'outline)

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

(defconst ibis-mode--outline-rx
  (rx (zero-or-more " ") ibis-marker-rx " ")
  "Regexp matching the marker that opens a node line.")

(defun ibis-mode--indentation ()
  "Return the number of leading spaces of the line at point.

Indentation is counted in characters rather than columns, so that
lines outline has hidden, whose display width is zero, still
report their nesting."
  (save-excursion
    (let ((beg (line-beginning-position)))
      (goto-char beg)
      (skip-chars-forward " ")
      (- (point) beg))))

(defun ibis-mode--outline-level ()
  "Return the outline level of the line at point, counting from 1."
  (1+ (/ (ibis-mode--indentation) 2)))

(defun ibis-mode--indent-candidates (prev-indent)
  "Return the indentations a line under PREV-INDENT may take.

The first is the sibling indentation, the second that of a child,
the rest those of its ancestors down to the left margin."
  (let ((candidates (list prev-indent (+ prev-indent 2)))
        (ancestor (- prev-indent 2)))
    (while (>= ancestor 0)
      (setq candidates (append candidates (list ancestor)))
      (setq ancestor (- ancestor 2)))
    (delete-dups candidates)))

(defun ibis-mode--previous-indentation ()
  "Return the indentation of the last non-blank line before point, or 0."
  (save-excursion
    (forward-line 0)
    (catch 'found
      (while (not (bobp))
        (forward-line -1)
        (unless (looking-at-p (rx bol (zero-or-more " ") eol))
          (throw 'found (ibis-mode--indentation))))
      0)))

(defun ibis-mode--text-beginning ()
  "Return the position where the text of the line at point starts."
  (+ (line-beginning-position) (ibis-mode--indentation)))

(defun ibis-mode--next-indentation (candidates current)
  "Return the indentation following CURRENT in CANDIDATES, wrapping around."
  (or (cadr (member current candidates)) (car candidates)))

(defun ibis-indent-line ()
  "Indent the current line under the node above it.

The first invocation indents like the previous line; repeating the
command cycles through child and ancestor indentations."
  (interactive)
  (let* ((candidates (ibis-mode--indent-candidates
                      (ibis-mode--previous-indentation)))
         (target (if (eq last-command this-command)
                     (ibis-mode--next-indentation candidates
                                                  (ibis-mode--indentation))
                   (car candidates)))
         (offset (max 0 (- (point) (ibis-mode--text-beginning)))))
    (indent-line-to target)
    (goto-char (+ (ibis-mode--text-beginning) offset))))

(defun ibis-newline-and-indent ()
  "Open a new line indented like the current one."
  (interactive)
  (let ((indent (ibis-mode--indentation)))
    (newline)
    (indent-line-to indent)))

(defvar-keymap ibis-mode-map
  :doc "Keymap for `ibis-mode'."
  "RET" #'ibis-newline-and-indent)

(defun ibis-mode--imenu-index ()
  "Return an imenu index of the top-level issues of the buffer."
  (let ((index nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((beg (line-beginning-position))
               (parsed (ibis--parse-line
                        (buffer-substring-no-properties
                         beg (line-end-position)))))
          (when (and parsed
                     (zerop (plist-get parsed :column))
                     (eq (plist-get parsed :marker) 'issue))
            (let ((id (plist-get parsed :id))
                  (text (plist-get parsed :text)))
              (push (cons (if id (concat id ": " text) text) beg) index))))
        (forward-line 1)))
    (nreverse index)))

;;;###autoload
(define-derived-mode ibis-mode text-mode "IBIS"
  "Major mode for editing `.ibis' issue maps.

Each line carries a marker: `?' for an issue, `→' (or `->') for a
position, `+' and `-' for arguments.  Indentation by two spaces
nests a node under the one above it."
  (setq-local font-lock-defaults '(ibis-mode--font-lock-keywords t))
  (setq-local indent-line-function #'ibis-indent-line)
  (setq-local outline-regexp ibis-mode--outline-rx)
  (setq-local outline-level #'ibis-mode--outline-level)
  (setq-local imenu-create-index-function #'ibis-mode--imenu-index)
  (setq-local require-final-newline t)
  (setq-local comment-start nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ibis\\'" . ibis-mode))

(provide 'ibis-mode)

;;; ibis-mode.el ends here
