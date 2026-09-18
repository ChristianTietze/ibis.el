;;; ibis-mode-test.el --- Tests for ibis-mode.el -*- lexical-binding: t; -*-

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

(ert-deftest ibis-mode-test-insert-on-plain-line-is-an-error ()
  (ibis-mode-test--with-buffer "plain\n"
    (should-error (ibis-insert-issue) :type 'user-error)))

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
  (should (eq (keymap-lookup ibis-mode-map "C-c #") #'ibis-toggle-tag)))

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
