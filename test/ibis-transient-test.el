;;; ibis-transient-test.el --- Tests for ibis-transient.el -*- lexical-binding: t; -*-

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

;; ERT tests for the transient menu.

;;; Code:

(require 'ert)
(require 'ibis-transient)

(defun ibis-transient-test--suffix (key)
  "Return the plist of the menu suffix bound to KEY."
  (cdr (transient-get-suffix 'ibis-transient-menu key)))

(defun ibis-transient-test--command (key)
  "Return the command the menu runs for KEY."
  (plist-get (ibis-transient-test--suffix key) :command))

(ert-deftest ibis-transient-test-loading-binds-the-menu ()
  (should (eq (keymap-lookup ibis-mode-map "C-c m") #'ibis-transient-menu)))

(ert-deftest ibis-transient-test-insert-keys ()
  (should (eq (ibis-transient-test--command "i") #'ibis-insert-issue))
  (should (eq (ibis-transient-test--command "I") #'ibis-insert-root-issue))
  (should (eq (ibis-transient-test--command ">") #'ibis-insert-position))
  (should (eq (ibis-transient-test--command "+") #'ibis-insert-pro))
  (should (eq (ibis-transient-test--command "-") #'ibis-insert-con))
  (should (eq (ibis-transient-test--command "s") #'ibis-insert-sibling))
  (should (eq (ibis-transient-test--command "c") #'ibis-insert-child)))

(ert-deftest ibis-transient-test-structure-keys-repeat ()
  (dolist (pair '(("M-<left>" . ibis-promote)
                  ("M-<right>" . ibis-demote)
                  ("M-<up>" . ibis-move-up)
                  ("M-<down>" . ibis-move-down)))
    (let ((suffix (ibis-transient-test--suffix (car pair))))
      (should (eq (plist-get suffix :command) (cdr pair)))
      (should (eq (plist-get suffix :transient) t)))))

(ert-deftest ibis-transient-test-navigate-keys-repeat ()
  (dolist (pair '(("p" . outline-previous-visible-heading)
                  ("n" . outline-next-visible-heading)
                  ("u" . outline-up-heading)
                  ("b" . outline-backward-same-level)
                  ("f" . outline-forward-same-level)))
    (let ((suffix (ibis-transient-test--suffix (car pair))))
      (should (eq (plist-get suffix :command) (cdr pair)))
      (should (eq (plist-get suffix :transient) t)))))

(ert-deftest ibis-transient-test-outline-commands-walk-the-map ()
  (with-temp-buffer
    (insert "? a\n  → b\n    + c\n? d\n")
    (ibis-mode)
    (goto-char (point-min))
    (forward-line 2)
    (outline-up-heading 1)
    (should (looking-at-p "  → b"))
    (outline-up-heading 1)
    (should (looking-at-p "? a"))
    (outline-forward-same-level 1)
    (should (looking-at-p "? d"))
    (outline-previous-visible-heading 1)
    (should (looking-at-p "    \\+ c"))))

(ert-deftest ibis-transient-test-other-keys ()
  (should (eq (ibis-transient-test--command "t") #'ibis-toggle-tag))
  (should (eq (ibis-transient-test--command "!") #'ibis-check))
  (should (eq (ibis-transient-test--command "q") #'transient-quit-one)))

(provide 'ibis-transient-test)
;;; ibis-transient-test.el ends here
