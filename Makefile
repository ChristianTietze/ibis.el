EMACS    ?= emacs
INIT_DIR := --init-directory=$(CURDIR)/dev
# --batch skips the init file, so packages in dev/elpa need activating by hand.
BATCH    := $(EMACS) $(INIT_DIR) --batch \
              --eval '(package-activate-all)' \
              --eval '(add-to-list '"'"'load-path "$(CURDIR)/lisp")'

PKG      := ibis

SRCS     := lisp/$(PKG).el lisp/$(PKG)-mode.el
TESTS    := test/$(PKG)-test.el test/$(PKG)-mode-test.el

.DEFAULT_GOAL := help

.PHONY: all compile lint lint-package lint-checkdoc test clean help

all: compile lint test

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all       Compile, lint and test (CI)"
	@echo "  compile   Byte-compile source files (warnings are errors)"
	@echo "  lint      Run package-lint and checkdoc"
	@echo "  test      Run ERT unit tests"
	@echo "  clean     Remove byte-compiled files"

compile:
	$(BATCH) --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile $(SRCS)

lint: lint-package lint-checkdoc

lint-package:
	$(BATCH) -l dev/run-lint.el $(SRCS)

lint-checkdoc:
	$(BATCH) --eval "(progn \
	  (require 'checkdoc) \
	  (setq sentence-end-double-space nil) \
	  (let ((warning-count 0)) \
	    (cl-letf (((symbol-function 'lwarn) \
	              (lambda (_type _level msg &rest args) \
	                (message \"%s\" (apply #'format-message msg args)) \
	                (setq warning-count (1+ warning-count))))) \
	      (dolist (f '($(foreach s,$(SRCS),\"$(s)\" ))) \
	        (checkdoc-file f)) \
	      (when (> warning-count 0) (kill-emacs 1)))))"

test:
	$(BATCH) -l ert \
	  $(foreach s,$(SRCS),-l $(s)) \
	  $(foreach t,$(TESTS),-l $(t)) \
	  --eval '(ert-run-tests-batch-and-exit "$(PKG)")'

clean:
	rm -f lisp/*.elc
