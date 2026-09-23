;;; ibis-mode-test.el --- Tests for ibis-mode.el -*- lexical-binding: t; -*-

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

;; ERT tests for the major mode.

;;; Code:

(require 'ert)
(require 'ibis-mode)

(defconst ibis-mode-test--fixture
  (expand-file-name "fixtures/beispiel.ibis"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Path of the German example map used by the tests.")

(defun ibis-mode-test--fixture-string ()
  "Return the contents of `ibis-mode-test--fixture' as a string."
  (let ((coding-system-for-read 'utf-8))
    (with-temp-buffer
      (insert-file-contents ibis-mode-test--fixture)
      (buffer-string))))

(defmacro ibis-mode-test--with-buffer (text &rest body)
  "Run BODY with point at the start of an `ibis-mode' buffer holding TEXT."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (insert ,text)
     (ibis-mode)
     (goto-char (point-min))
     ,@body))

(defun ibis-mode-test--faces-at (position)
  "Return the faces in effect at POSITION as a list."
  (ensure-list (get-text-property position 'face)))

(defun ibis-mode-test--faces-before (string)
  "Return the faces in effect where STRING starts after point."
  (search-forward string)
  (ibis-mode-test--faces-at (match-beginning 0)))

(ert-deftest ibis-mode-test-auto-mode-alist ()
  (should (eq (cdr (assoc "\\.ibis\\'" auto-mode-alist)) 'ibis-mode)))

(ert-deftest ibis-mode-test-derived-from-text-mode ()
  (ibis-mode-test--with-buffer "? a\n"
    (should (derived-mode-p 'text-mode))
    (should (equal mode-name "IBIS"))
    (should require-final-newline)
    (should-not comment-start)))

(ert-deftest ibis-mode-test-font-lock-issue-marker ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (font-lock-ensure)
    (should (memq 'ibis-issue-marker-face
                  (ibis-mode-test--faces-at (point-min))))))

(ert-deftest ibis-mode-test-font-lock-id ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (font-lock-ensure)
    (should (memq 'ibis-id-face (ibis-mode-test--faces-before "I-1")))))

(ert-deftest ibis-mode-test-font-lock-hashtag ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (font-lock-ensure)
    (should (memq 'ibis-hashtag-face
                  (ibis-mode-test--faces-before "#prüfen")))))

(ert-deftest ibis-mode-test-font-lock-pro-text ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (font-lock-ensure)
    (should (memq 'ibis-pro-face
                  (ibis-mode-test--faces-before "Termin kann verfallen")))))

(ert-deftest ibis-mode-test-font-lock-con-marker ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (font-lock-ensure)
    (should (memq 'ibis-con-marker-face
                  (ibis-mode-test--faces-before "- Klärt")))))

(ert-deftest ibis-mode-test-font-lock-position-marker ()
  (ibis-mode-test--with-buffer "? a\n  -> b\n"
    (font-lock-ensure)
    (should (memq 'ibis-position-marker-face
                  (ibis-mode-test--faces-before "->")))
    (should (memq 'ibis-position-face (ibis-mode-test--faces-before "b")))))

(ert-deftest ibis-mode-test-outline-level ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (search-forward "+ Termin kann verfallen")
    (goto-char (match-beginning 0))
    (should (= (funcall outline-level) 3))))

(ert-deftest ibis-mode-test-outline-hide-sublevels ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (outline-hide-sublevels 1)
    (goto-char (point-min))
    (while (not (eobp))
      (let ((beg (line-beginning-position)))
        (unless (string-blank-p (buffer-substring-no-properties
                                 beg (line-end-position)))
          (if (eq (char-after beg) ??)
              (should-not (invisible-p beg))
            (should (invisible-p beg)))))
      (forward-line 1))))

(ert-deftest ibis-mode-test-imenu-index ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (let ((index (funcall imenu-create-index-function)))
      (should (= (length index) 6))
      (should (equal (caar index)
                     "I-1: Wie werden Bedingung und Termin verständlich?"))
      (should (= (cdar index) (point-min))))))

(ert-deftest ibis-mode-test-imenu-index-without-id ()
  (ibis-mode-test--with-buffer "? a\n  → b\n? c\n"
    (let ((index (funcall imenu-create-index-function)))
      (should (equal (mapcar #'car index) '("a" "c"))))))

(defun ibis-mode-test--press-tab (times)
  "Call `ibis-indent-line' TIMES in a row, as repeated TAB presses would."
  (let ((last-command nil)
        (this-command 'indent-for-tab-command))
    (dotimes (_ times)
      (ibis-indent-line)
      (setq last-command 'indent-for-tab-command))))

(ert-deftest ibis-mode-test-indent-candidates ()
  (should (equal (ibis-mode--indent-candidates 4) '(4 6 2 0)))
  (should (equal (ibis-mode--indent-candidates 0) '(0 2)))
  (should (equal (ibis-mode--indent-candidates 2) '(2 4 0))))

(ert-deftest ibis-mode-test-indent-first-tab-takes-previous-indentation ()
  (ibis-mode-test--with-buffer "? a\n  → b\n+ c\n"
    (goto-char (point-max))
    (forward-line -1)
    (ibis-mode-test--press-tab 1)
    (should (= (current-indentation) 2))))

(ert-deftest ibis-mode-test-indent-cycles-on-repeated-tab ()
  (ibis-mode-test--with-buffer "? a\n→ b\n"
    (forward-line 1)
    (ibis-mode-test--press-tab 1)
    (should (= (current-indentation) 0))
    (ibis-mode-test--press-tab 2)
    (should (= (current-indentation) 2))
    (ibis-mode-test--press-tab 3)
    (should (= (current-indentation) 0))))

(ert-deftest ibis-mode-test-indent-keeps-point-on-text ()
  (ibis-mode-test--with-buffer "? a\n  → b\n→ cde\n"
    (goto-char (point-max))
    (forward-line -1)
    (forward-char 3)
    (ibis-mode-test--press-tab 1)
    (should (equal (buffer-substring-no-properties (point) (line-end-position))
                   "de"))))

(ert-deftest ibis-mode-test-newline-and-indent ()
  (ibis-mode-test--with-buffer "  → b\n"
    (end-of-line)
    (ibis-newline-and-indent)
    (should (= (current-indentation) 2))
    (should (= (point) (line-end-position)))))

(ert-deftest ibis-mode-test-return-is-bound ()
  (should (eq (keymap-lookup ibis-mode-map "RET") #'ibis-newline-and-indent)))

(ert-deftest ibis-mode-test-node-at-point ()
  (ibis-mode-test--with-buffer "? a\n  → I-2: b #x\n"
    (forward-line 1)
    (let ((node (ibis-mode--node-at-point)))
      (should (= (plist-get node :column) 2))
      (should (eq (plist-get node :marker) 'position))
      (should (equal (plist-get node :id) "I-2"))
      (should (= (plist-get node :beg) (line-beginning-position))))))

(ert-deftest ibis-mode-test-node-at-point-on-plain-line ()
  (ibis-mode-test--with-buffer "plain\n"
    (should-not (ibis-mode--node-at-point))))

(ert-deftest ibis-mode-test-insert-pro-after-subtree ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (forward-line 1)
    (ibis-insert-pro)
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position))
                   "    + "))
    (should (= (point) (line-end-position)))
    (forward-line -1)
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position))
                   "    - Klärt Voraussetzungen und Ausfall nicht."))))

(ert-deftest ibis-mode-test-insert-pro-under-issue-is-an-error ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (should-error (ibis-insert-pro) :type 'user-error)))

(ert-deftest ibis-mode-test-insert-position-and-issue ()
  (ibis-mode-test--with-buffer "? a\n"
    (ibis-insert-position)
    (should (equal (buffer-string) "? a\n  → \n"))
    (ibis-insert-issue)
    (should (equal (buffer-string) "? a\n  → \n    ? \n"))))

(ert-deftest ibis-mode-test-insert-con-under-position ()
  (ibis-mode-test--with-buffer "? a\n  → b\n? c\n"
    (forward-line 1)
    (ibis-insert-con)
    (should (equal (buffer-string) "? a\n  → b\n    - \n? c\n"))))

(ert-deftest ibis-mode-test-insert-issue-off-a-node-starts-a-root-issue ()
  (ibis-mode-test--with-buffer "? a\n\nplain\n"
    (goto-char (point-max))
    (ibis-insert-issue)
    (should (equal (buffer-string) "? a\n\n? \n\nplain\n"))))

(ert-deftest ibis-mode-test-insert-issue-with-prefix-starts-a-root-issue ()
  (ibis-mode-test--with-buffer "? a\n  → b\n? c\n"
    (forward-line 1)
    (ibis-insert-issue '(4))
    (should (equal (buffer-string) "? a\n  → b\n\n? \n\n? c\n"))))

(ert-deftest ibis-mode-test-insert-root-issue-after-the-block-at-point ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n\n? d\n"
    (forward-line 2)
    (ibis-insert-root-issue)
    (should (equal (buffer-string) "? a\n  → b\n    + c\n\n? \n\n? d\n"))
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (point))
                   "? "))))

(ert-deftest ibis-mode-test-insert-root-issue-on-blank-line-follows-the-block-above ()
  (ibis-mode-test--with-buffer "? a\n\n? c\n"
    (forward-line 1)
    (ibis-insert-root-issue)
    (should (equal (buffer-string) "? a\n\n? \n\n? c\n"))))

(ert-deftest ibis-mode-test-insert-root-issue-in-empty-buffer ()
  (ibis-mode-test--with-buffer ""
    (ibis-insert-root-issue)
    (should (equal (buffer-string) "? \n"))
    (should (= (point) 3))))

(ert-deftest ibis-mode-test-insert-root-issue-before-the-first-block ()
  (ibis-mode-test--with-buffer "plain\n\n? a\n"
    (ibis-insert-root-issue)
    (should (equal (buffer-string) "? \n\nplain\n\n? a\n"))))

(ert-deftest ibis-mode-test-insert-issue-is-bound ()
  (should (eq (keymap-lookup ibis-mode-map "C-c ?") #'ibis-insert-issue))
  (should (eq (keymap-lookup ibis-mode-map "C-c i") #'ibis-insert-issue))
  (should (eq (keymap-lookup ibis-mode-map "C-c I") #'ibis-insert-root-issue)))

(ert-deftest ibis-mode-test-insert-sibling-keeps-marker-and-indent ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n"
    (forward-line 1)
    (ibis-insert-sibling)
    (should (equal (buffer-string) "? a\n  → b\n    + c\n  → \n"))
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (point))
                   "  → "))))

(ert-deftest ibis-mode-test-insert-sibling-separates-top-level-blocks ()
  (ibis-mode-test--with-buffer "? a\n"
    (ibis-insert-sibling)
    (should (equal (buffer-string) "? a\n\n? \n"))))

(ert-deftest ibis-mode-test-insert-sibling-separates-the-following-block ()
  (ibis-mode-test--with-buffer "? a\n? b\n"
    (ibis-insert-sibling)
    (should (equal (buffer-string) "? a\n\n? \n\n? b\n"))
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (point))
                   "? "))))

(ert-deftest ibis-mode-test-insert-sibling-keeps-one-blank-line-on-each-side ()
  (ibis-mode-test--with-buffer "? a\n\n? c\n"
    (ibis-insert-sibling)
    (should (equal (buffer-string) "? a\n\n? \n\n? c\n"))))

(ert-deftest ibis-mode-test-insert-sibling-on-blank-line-is-an-error ()
  (ibis-mode-test--with-buffer "\n"
    (should-error (ibis-insert-sibling) :type 'user-error)))

(ert-deftest ibis-mode-test-insert-sibling-is-bound ()
  (should (eq (keymap-lookup ibis-mode-map "M-RET") #'ibis-insert-sibling)))

(ert-deftest ibis-mode-test-insert-child-under-issue-is-a-position ()
  (ibis-mode-test--with-buffer "? a\n"
    (ibis-insert-child)
    (should (equal (buffer-string) "? a\n  → \n"))))

(ert-deftest ibis-mode-test-insert-child-under-position-is-a-pro ()
  (ibis-mode-test--with-buffer "? a\n  → b\n"
    (forward-line 1)
    (ibis-insert-child)
    (should (equal (buffer-string) "? a\n  → b\n    + \n"))))

(ert-deftest ibis-mode-test-insert-child-under-argument-is-an-issue ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n"
    (forward-line 2)
    (ibis-insert-child)
    (should (equal (buffer-string)
                   "? a\n  → b\n    + c\n      ? \n"))))

(ert-deftest ibis-mode-test-insert-child-is-bound ()
  (should (eq (keymap-lookup ibis-mode-map "S-<return>") #'ibis-insert-child)))

(defun ibis-mode-test--type (string)
  "Insert STRING into the current buffer as if it were typed."
  (dolist (char (string-to-list string))
    (let ((last-command-event char))
      (self-insert-command 1))))

(ert-deftest ibis-mode-test-arrow-replaces-marker-at-line-start ()
  (ibis-mode-test--with-buffer ""
    (ibis-mode-test--type "  -> b")
    (should (equal (buffer-string) "  → b"))))

(ert-deftest ibis-mode-test-arrow-keeps-an-arrow-in-the-text ()
  (ibis-mode-test--with-buffer ""
    (ibis-mode-test--type "? A -> B")
    (should (equal (buffer-string) "? A -> B"))))

(ert-deftest ibis-mode-test-demote-shifts-the-subtree ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n"
    (forward-line 1)
    (ibis-demote)
    (should (equal (buffer-string) "? a\n    → b\n      + c\n"))))

(ert-deftest ibis-mode-test-demote-keeps-point-in-the-text ()
  (ibis-mode-test--with-buffer "? a\n  → b\n"
    (forward-line 1)
    (forward-char 4)
    (ibis-demote)
    (should (equal (buffer-substring-no-properties (point) (point-max))
                   "b\n"))))

(ert-deftest ibis-mode-test-demote-into-column-eight-writes-no-tab ()
  (let ((indent-tabs-mode t))
    (ibis-mode-test--with-buffer "? a\n  \u2192 b\n    + c\n      ? d\n"
      (forward-line 3)
      (ibis-demote)
      (should-not (string-match-p "\t" (buffer-string)))
      (should-not (cdr (ibis-parse-buffer))))))

(ert-deftest ibis-mode-test-promote-at-the-left-margin-is-an-error ()
  (ibis-mode-test--with-buffer "? a\n"
    (should-error (ibis-promote) :type 'user-error)))

(ert-deftest ibis-mode-test-promote-at-the-left-margin-changes-nothing ()
  (ibis-mode-test--with-buffer "? a\n  \u2192 b\n? c\n"
    (forward-line 2)
    (forward-char 2)
    (let ((origin (point)))
      (should-error (ibis-promote) :type 'user-error)
      (should (equal (buffer-string) "? a\n  \u2192 b\n? c\n"))
      (should (= (point) origin)))))

(ert-deftest ibis-mode-test-demote-keeps-point-on-a-later-line ()
  (ibis-mode-test--with-buffer "? a\n  \u2192 b\n    + cde\n"
    (forward-line 2)
    (forward-char 7)
    (ibis-demote)
    (should (equal (buffer-substring-no-properties (point) (line-end-position))
                   "de"))
    (should (= (current-indentation) 6))))

(ert-deftest ibis-mode-test-demote-in-a-read-only-buffer-releases-the-marker ()
  (ibis-mode-test--with-buffer "? a\n  \u2192 b\n    + c\n"
    (let* ((markers nil)
           (copy (symbol-function 'copy-marker)))
      (cl-letf (((symbol-function 'copy-marker)
                 (lambda (&rest arguments)
                   (car (push (apply copy arguments) markers)))))
        (forward-line 1)
        (setq buffer-read-only t)
        (should-error (ibis-demote) :type 'buffer-read-only))
      (should markers)
      (should-not (seq-find #'marker-buffer markers)))))

(ert-deftest ibis-mode-test-promote-reverses-a-demote ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n"
    (forward-line 1)
    (ibis-demote)
    (ibis-promote)
    (should (equal (buffer-string) "? a\n  → b\n    + c\n"))))

(ert-deftest ibis-mode-test-promote-and-demote-are-bound ()
  (should (eq (keymap-lookup ibis-mode-map "M-<left>") #'ibis-promote))
  (should (eq (keymap-lookup ibis-mode-map "M-<right>") #'ibis-demote)))

(ert-deftest ibis-mode-test-move-down-swaps-siblings-with-subtrees ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n  → d\n    + e\n"
    (forward-line 1)
    (ibis-move-down)
    (should (equal (buffer-string)
                   "? a\n  → d\n    + e\n  → b\n    + c\n"))
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position))
                   "  → b"))))

(ert-deftest ibis-mode-test-move-up-without-a-sibling-is-an-error ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n  → d\n"
    (forward-line 1)
    (should-error (ibis-move-up) :type 'user-error)))

(ert-deftest ibis-mode-test-move-up-reverses-a-move-down ()
  (ibis-mode-test--with-buffer "? a\n  → b\n    + c\n  → d\n    + e\n"
    (forward-line 1)
    (ibis-move-down)
    (ibis-move-up)
    (should (equal (buffer-string)
                   "? a\n  → b\n    + c\n  → d\n    + e\n"))
    (should (equal (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position))
                   "  → b"))))

(ert-deftest ibis-mode-test-move-down-keeps-the-blank-line-between-blocks ()
  (ibis-mode-test--with-buffer "? a\n\n? b\n"
    (ibis-move-down)
    (should (equal (buffer-string) "? b\n\n? a\n"))))

(ert-deftest ibis-mode-test-move-commands-are-bound ()
  (should (eq (keymap-lookup ibis-mode-map "M-<up>") #'ibis-move-up))
  (should (eq (keymap-lookup ibis-mode-map "M-<down>") #'ibis-move-down)))

(defconst ibis-mode-test--split-subtree
  "? a\n  \u2192 b\n    + c\n\n    + d\n  \u2192 e\n"
  "A map whose second argument sits behind a blank line inside its subtree.")

(defun ibis-mode-test--edges ()
  "Return the edges of the buffer as sorted (SUBJECT PREDICATE OBJECT) triples.

Subject and object are the prose of the nodes they name."
  (sort (mapcar (lambda (edge)
                  (list (ibis-node-text (ibis-edge-subject edge))
                        (ibis-edge-predicate edge)
                        (ibis-node-text (ibis-edge-object edge))))
                (ibis-network-edges (car (ibis-parse-buffer))))
        (lambda (a b) (string< (format "%S" a) (format "%S" b)))))

(ert-deftest ibis-mode-test-blank-line-inside-a-subtree-keeps-the-parent ()
  (ibis-mode-test--with-buffer ibis-mode-test--split-subtree
    (should-not (cdr (ibis-parse-buffer)))
    (should (equal (ibis-mode-test--edges)
                   '(("b" responds-to "a")
                     ("c" supports "b")
                     ("d" supports "b")
                     ("e" responds-to "a"))))))

(ert-deftest ibis-mode-test-demote-takes-the-whole-split-subtree ()
  (ibis-mode-test--with-buffer ibis-mode-test--split-subtree
    (let ((edges (ibis-mode-test--edges)))
      (forward-line 1)
      (ibis-demote)
      (should (equal (buffer-string)
                     "? a\n    \u2192 b\n      + c\n\n      + d\n  \u2192 e\n"))
      (should-not (cdr (ibis-parse-buffer)))
      (should (equal (ibis-mode-test--edges) edges)))))

(ert-deftest ibis-mode-test-demote-leaves-a-blank-line-of-tabs-alone ()
  (ibis-mode-test--with-buffer "? a\n  \u2192 b\n    + c\n\t\n    + d\n"
    (forward-line 1)
    (ibis-demote)
    (should (equal (buffer-string)
                   "? a\n    \u2192 b\n      + c\n\t\n      + d\n"))))

(ert-deftest ibis-mode-test-move-down-takes-the-whole-split-subtree ()
  (ibis-mode-test--with-buffer ibis-mode-test--split-subtree
    (let ((edges (ibis-mode-test--edges)))
      (forward-line 1)
      (ibis-move-down)
      (should (equal (buffer-string)
                     "? a\n  \u2192 e\n  \u2192 b\n    + c\n\n    + d\n"))
      (should-not (cdr (ibis-parse-buffer)))
      (should (equal (ibis-mode-test--edges) edges)))))

(ert-deftest ibis-mode-test-move-up-reverses-a-move-down-over-a-blank-line ()
  (ibis-mode-test--with-buffer ibis-mode-test--split-subtree
    (let ((edges (ibis-mode-test--edges)))
      (forward-line 1)
      (ibis-move-down)
      (ibis-move-up)
      (should (equal (buffer-string) ibis-mode-test--split-subtree))
      (should-not (cdr (ibis-parse-buffer)))
      (should (equal (ibis-mode-test--edges) edges)))))

(ert-deftest ibis-mode-test-insert-sibling-lands-after-a-split-subtree ()
  (ibis-mode-test--with-buffer ibis-mode-test--split-subtree
    (let ((edges (ibis-mode-test--edges)))
      (forward-line 1)
      (ibis-insert-sibling)
      (should (equal (buffer-string)
                     "? a\n  \u2192 b\n    + c\n\n    + d\n  \u2192 \n  \u2192 e\n"))
      (should-not (cdr (ibis-parse-buffer)))
      (should (equal (ibis-mode-test--edges)
                     (sort (cons '("" responds-to "a") edges)
                           (lambda (a b)
                             (string< (format "%S" a) (format "%S" b)))))))))

(defconst ibis-mode-test--prose-in-subtree
  "? a\n  \u2192 b\n    + c\nPROSE\n    + d\n"
  "A map whose second argument sits behind a line the parser cannot read.")

(ert-deftest ibis-mode-test-prose-line-inside-a-subtree-keeps-the-parent ()
  (ibis-mode-test--with-buffer ibis-mode-test--prose-in-subtree
    (should (equal (mapcar #'cdr (cdr (ibis-parse-buffer)))
                   '("Not an IBIS line")))
    (should (equal (ibis-mode-test--edges)
                   '(("b" responds-to "a")
                     ("c" supports "b")
                     ("d" supports "b"))))))

(ert-deftest ibis-mode-test-demote-takes-a-subtree-split-by-prose ()
  (ibis-mode-test--with-buffer ibis-mode-test--prose-in-subtree
    (let ((edges (ibis-mode-test--edges)))
      (forward-line 1)
      (ibis-demote)
      (should (equal (buffer-string)
                     "? a\n    \u2192 b\n      + c\n  PROSE\n      + d\n"))
      (should (equal (ibis-mode-test--edges) edges)))))

(ert-deftest ibis-mode-test-promote-reverses-a-demote-over-prose ()
  (ibis-mode-test--with-buffer ibis-mode-test--prose-in-subtree
    (forward-line 1)
    (ibis-demote)
    (ibis-promote)
    (should (equal (buffer-string) ibis-mode-test--prose-in-subtree))))

(ert-deftest ibis-mode-test-move-down-finds-a-sibling-past-prose ()
  (ibis-mode-test--with-buffer "? a\n  \u2192 b\n  note\n    + c\n  \u2192 e\n"
    (let ((edges (ibis-mode-test--edges)))
      (forward-line 1)
      (ibis-move-down)
      (should (equal (buffer-string)
                     "? a\n  \u2192 e\n  \u2192 b\n  note\n    + c\n"))
      (should (equal (ibis-mode-test--edges) edges)))))

(ert-deftest ibis-mode-test-move-up-reverses-a-move-down-over-prose ()
  (ibis-mode-test--with-buffer "? a\n  \u2192 b\n  note\n    + c\n  \u2192 e\n"
    (forward-line 1)
    (ibis-move-down)
    (ibis-move-up)
    (should (equal (buffer-string)
                   "? a\n  \u2192 b\n  note\n    + c\n  \u2192 e\n"))))

(ert-deftest ibis-mode-test-toggle-tag-adds-then-removes ()
  (ibis-mode-test--with-buffer "? a\n"
    (ibis-toggle-tag "x")
    (should (equal (buffer-string) "? a #x\n"))
    (ibis-toggle-tag "x")
    (should (equal (buffer-string) "? a\n"))))

(ert-deftest ibis-mode-test-toggle-tag-keeps-neighbours ()
  (ibis-mode-test--with-buffer "? a #x #y\n"
    (ibis-toggle-tag "x")
    (should (equal (buffer-string) "? a #y\n"))))

(ert-deftest ibis-mode-test-tags-in-buffer ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (should (equal (ibis-mode--tags-in-buffer)
                   '("prüfen" "Empfehlung" "festgehalten")))))

(ert-deftest ibis-mode-test-insert-commands-are-bound ()
  (should (eq (keymap-lookup ibis-mode-map "C-c ?") #'ibis-insert-issue))
  (should (eq (keymap-lookup ibis-mode-map "C-c >") #'ibis-insert-position))
  (should (eq (keymap-lookup ibis-mode-map "C-c +") #'ibis-insert-pro))
  (should (eq (keymap-lookup ibis-mode-map "C-c -") #'ibis-insert-con))
  (should (eq (keymap-lookup ibis-mode-map "C-c t") #'ibis-toggle-tag)))

(ert-deftest ibis-mode-test-toggle-tag-key ()
  (ibis-mode-test--with-buffer "? a\n"
    (should (eq (key-binding (kbd "C-c t")) #'ibis-toggle-tag))))

(defun ibis-mode-test--flymake-diagnostics ()
  "Return the diagnostics `ibis-flymake' reports for the current buffer."
  (let ((reported nil))
    (ibis-flymake (lambda (diagnostics) (setq reported diagnostics)))
    reported))

(ert-deftest ibis-mode-test-flymake-reports-a-diagnostic ()
  (ibis-mode-test--with-buffer "? a\n  + b\n"
    (let ((diagnostics (ibis-mode-test--flymake-diagnostics)))
      (should (= (length diagnostics) 1))
      (should (= (flymake-diagnostic-beg (car diagnostics)) 5))
      (should (= (flymake-diagnostic-end (car diagnostics)) 10))
      (should (eq (flymake-diagnostic-type (car diagnostics)) :error))
      (should (equal (flymake-diagnostic-text (car diagnostics))
                     "Argument must support a position")))))

(ert-deftest ibis-mode-test-flymake-accepts-the-fixture ()
  (ibis-mode-test--with-buffer (ibis-mode-test--fixture-string)
    (should-not (ibis-mode-test--flymake-diagnostics))))

(ert-deftest ibis-mode-test-flymake-is-a-buffer-local-backend ()
  (ibis-mode-test--with-buffer "? a\n"
    (should (memq #'ibis-flymake flymake-diagnostic-functions))
    (should (local-variable-p 'flymake-diagnostic-functions))))

(ert-deftest ibis-mode-test-check-is-bound ()
  (should (eq (keymap-lookup ibis-mode-map "C-c C-c") #'ibis-check)))

(provide 'ibis-mode-test)

;;; ibis-mode-test.el ends here
