;;; run-lint.el --- Package-lint runner -*- lexical-binding: t -*-

;;; Commentary:

;; Installs `package-lint' on demand, then lints the files named on
;; the command line.  Complaints about the package's own files
;; depending on each other are dropped: they are not installable from
;; an archive, and that is the point of a multi-file package.

;;; Code:

(require 'package)

(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

(unless (package-installed-p 'package-lint)
  (package-refresh-contents)
  (package-install 'package-lint))

(require 'package-lint)

(defconst ibis-lint-own-packages
  '("ibis" "ibis-mode")
  "Files of this package, which no archive can offer.")

(defun ibis-lint-ignored-p (message)
  "Return non-nil when MESSAGE reports a dependency on our own files."
  (seq-some (lambda (pkg)
              (equal message (format "Package %s is not installable." pkg)))
            ibis-lint-own-packages))

(let ((failed nil))
  (dolist (file command-line-args-left)
    (with-temp-buffer
      (insert-file-contents file t)
      (emacs-lisp-mode)
      (dolist (problem (package-lint-buffer))
        (pcase-let ((`(,line ,col ,type ,message) problem))
          (unless (ibis-lint-ignored-p message)
            (setq failed t)
            (message "%s:%d:%d: %s: %s" file line col type message))))))
  (kill-emacs (if failed 1 0)))

;;; run-lint.el ends here
