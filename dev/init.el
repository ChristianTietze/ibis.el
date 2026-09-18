;;; init.el --- Minimal init for ibis.el development -*- lexical-binding: t -*-

;;; Commentary:

;; Loaded via --init-directory=dev by the Makefile.  Puts the package
;; sources on `load-path'.

;;; Code:

(setq inhibit-startup-message t)

(add-to-list 'load-path
             (expand-file-name "../lisp" user-emacs-directory))

(require 'package)
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory))
(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;;; init.el ends here
