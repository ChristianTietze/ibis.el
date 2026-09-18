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

(provide 'ibis-mode-test)

;;; ibis-mode-test.el ends here
