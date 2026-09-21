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
(require 'flymake)
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

(defconst ibis-mode--hashtag-rx
  (rx (or bol " ") (group "#" (one-or-more (not (in " \n#")))))
  "Regexp matching a hashtag, capturing it with its leading `#'.")

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
    (,ibis-mode--hashtag-rx (1 'ibis-hashtag-face prepend)))
  "Font lock keywords highlighting marker, identifier, prose and hashtags.")

(defconst ibis-mode--blank-rx
  (rx bol (zero-or-more (in " \t")) eol)
  "Regexp matching a line holding nothing but whitespace.")

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
        (unless (looking-at-p ibis-mode--blank-rx)
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

(defconst ibis-mode--typed-arrow-rx
  (rx bos (zero-or-more " ") "->" eos)
  "Regexp matching a line whose whole content so far is a `->' marker.")

(defun ibis-mode--replace-typed-arrow ()
  "Replace the `->' marker just typed at the start of a line with `→'.

A function for `post-self-insert-hook'."
  (when (and (eq last-command-event ?>)
             (string-match-p ibis-mode--typed-arrow-rx
                             (buffer-substring-no-properties
                              (line-beginning-position) (point))))
    (delete-char -2)
    (insert "→")))

(defconst ibis-mode--insert-markers
  '((issue . "?")
    (position . "→")
    (pro . "+")
    (con . "-"))
  "Alist mapping a marker symbol to the marker string written for it.")

(defun ibis-mode--node-at-point ()
  "Return the node line at point as a plist, or nil when there is none.

The plist is that of `ibis--parse-line' extended by :beg, the
position the line starts at."
  (let* ((beg (line-beginning-position))
         (parsed (ibis--parse-line
                  (buffer-substring-no-properties
                   beg (line-end-position)))))
    (and parsed (append parsed (list :beg beg)))))

(defun ibis-mode--node-positions ()
  "Return the (BEG . COLUMN) of every node line, in document order.

The parser decides which lines are nodes: a line it cannot read is
transparent, so a deeper node below it still nests under the node
above it."
  (mapcar (lambda (node)
            (cons (ibis-node-beg node) (ibis-node-column node)))
          (ibis-network-nodes (car (ibis-parse-buffer)))))

(defun ibis-mode--positions-after (node)
  "Return the node positions following NODE, in document order."
  (let ((beg (plist-get node :beg))
        (positions (ibis-mode--node-positions)))
    (while (and positions (/= (caar positions) beg))
      (setq positions (cdr positions)))
    (cdr positions)))

(defun ibis-mode--subtree-end (node)
  "Return the position just after the subtree of NODE.

Blank and prose lines belong to the subtree when a deeper node
follows them, so that a block kept apart for readability moves as
one.  Lines trailing the subtree do not, so that the separator
between two blocks stays between them."
  (let ((last (plist-get node :beg))
        (column (plist-get node :column))
        (positions (ibis-mode--positions-after node)))
    (while (and positions (> (cdar positions) column))
      (setq last (caar positions))
      (setq positions (cdr positions)))
    (save-excursion
      (goto-char last)
      (line-beginning-position 2))))

(defun ibis-mode--insert-line (node indent marker blank)
  "Insert a line with MARKER at INDENT after the subtree of NODE.

BLANK non-nil surrounds the line with empty ones, the way the
serializer separates top-level blocks, without doubling a
separator that is already there.  Leave point after the marker."
  (goto-char (ibis-mode--subtree-end node))
  (unless (bolp)
    (insert "\n"))
  (when blank
    (insert "\n"))
  (insert (make-string indent ?\s)
          (cdr (assq marker ibis-mode--insert-markers))
          " \n")
  (when (and blank (not (eobp))
             (not (looking-at-p ibis-mode--blank-rx)))
    (save-excursion (insert "\n")))
  (forward-char -1))

(defun ibis-mode--insert-child (marker)
  "Insert a child line with MARKER under the node at point.

Signal a `user-error' when point is not on a node line, or when
the grammar forbids MARKER under it."
  (let* ((node (or (ibis-mode--node-at-point)
                   (user-error "No IBIS node at point")))
         (rule (ibis--tree-rule
                marker
                (ibis--marker-class (plist-get node :marker))
                ibis-strict-grammar)))
    (when (stringp rule)
      (user-error "%s" rule))
    (ibis-mode--insert-line node (+ (plist-get node :column) 2) marker nil)))

(defun ibis-insert-sibling ()
  "Insert a sibling of the node at point after that node's subtree.

Signal a `user-error' when point is not on a node line."
  (interactive)
  (let* ((node (or (ibis-mode--node-at-point)
                   (user-error "No IBIS node at point")))
         (column (plist-get node :column)))
    (ibis-mode--insert-line node column (plist-get node :marker)
                            (zerop column))))

(defconst ibis-mode--child-markers
  '((issue . position)
    (position . pro)
    (argument . issue))
  "Alist mapping a parent class to the marker `ibis-insert-child' gives it.")

(defun ibis-insert-child ()
  "Insert the customary child of the node at point under it.

An issue gets a position, a position a supporting argument, and
an argument an issue."
  (interactive)
  (let ((node (or (ibis-mode--node-at-point)
                  (user-error "No IBIS node at point"))))
    (ibis-mode--insert-child
     (cdr (assq (ibis--marker-class (plist-get node :marker))
                ibis-mode--child-markers)))))

(defun ibis-insert-issue ()
  "Insert a new issue under the node at point."
  (interactive)
  (ibis-mode--insert-child 'issue))

(defun ibis-insert-position ()
  "Insert a new position under the node at point."
  (interactive)
  (ibis-mode--insert-child 'position))

(defun ibis-insert-pro ()
  "Insert a new supporting argument under the node at point."
  (interactive)
  (ibis-mode--insert-child 'pro))

(defun ibis-insert-con ()
  "Insert a new opposing argument under the node at point."
  (interactive)
  (ibis-mode--insert-child 'con))

(defun ibis-mode--shift-subtree (delta)
  "Shift the node at point and its subtree by DELTA columns.

Signal a `user-error' when point is not on a node line, or when
the shift would move the node past the left margin."
  (let* ((node (or (ibis-mode--node-at-point)
                   (user-error "No IBIS node at point")))
         (offset (max 0 (- (point) (ibis-mode--text-beginning))))
         (end nil))
    (when (< (+ (plist-get node :column) delta) 0)
      (user-error "Node is already at the left margin"))
    (setq end (copy-marker (ibis-mode--subtree-end node)))
    (save-excursion
      (goto-char (plist-get node :beg))
      (while (< (point) end)
        (unless (looking-at-p ibis-mode--blank-rx)
          (indent-line-to (max 0 (+ (ibis-mode--indentation) delta))))
        (forward-line 1)))
    (set-marker end nil)
    (goto-char (plist-get node :beg))
    (goto-char (+ (ibis-mode--text-beginning) offset))))

(defun ibis-promote ()
  "Shift the node at point and its subtree two columns to the left."
  (interactive)
  (ibis-mode--shift-subtree -2))

(defun ibis-demote ()
  "Shift the node at point and its subtree two columns to the right."
  (interactive)
  (ibis-mode--shift-subtree 2))

(defun ibis-mode--previous-sibling-beginning (node)
  "Return the start of the sibling preceding NODE, or nil when it has none."
  (let ((beg (plist-get node :beg))
        (column (plist-get node :column))
        (previous nil))
    (dolist (position (ibis-mode--node-positions))
      (when (and (< (car position) beg)
                 (<= (cdr position) column))
        (setq previous (and (= (cdr position) column) (car position)))))
    previous))

(defun ibis-mode--next-sibling-beginning (node)
  "Return the start of the sibling following NODE, or nil when it has none."
  (let ((column (plist-get node :column))
        (positions (ibis-mode--positions-after node)))
    (while (and positions (> (cdar positions) column))
      (setq positions (cdr positions)))
    (and positions
         (= (cdar positions) column)
         (caar positions))))

(defun ibis-mode--swap-with-next-sibling ()
  "Swap the node at point and its subtree with the sibling below them.

Whatever separates the two, such as the blank line between
top-level blocks, stays between them.  Signal a `user-error' when
point is not on a node line or the node has no next sibling."
  (let* ((node (or (ibis-mode--node-at-point)
                   (user-error "No IBIS node at point")))
         (offset (max 0 (- (point) (ibis-mode--text-beginning))))
         (next-beg (or (ibis-mode--next-sibling-beginning node)
                       (user-error "No next sibling")))
         (beg (plist-get node :beg))
         (end (ibis-mode--subtree-end node))
         (next-end (save-excursion
                     (goto-char next-beg)
                     (ibis-mode--subtree-end (ibis-mode--node-at-point)))))
    (save-excursion
      (goto-char next-end)
      (unless (bolp)
        (insert "\n")
        (setq next-end (point))))
    (let ((subtree (buffer-substring-no-properties beg end))
          (separator (buffer-substring-no-properties end next-beg))
          (next (buffer-substring-no-properties next-beg next-end)))
      (delete-region beg next-end)
      (insert next separator subtree)
      (goto-char (+ beg (length next) (length separator)))
      (goto-char (+ (ibis-mode--text-beginning) offset)))))

(defun ibis-move-down ()
  "Swap the node at point and its subtree with the sibling below them."
  (interactive)
  (ibis-mode--swap-with-next-sibling))

(defun ibis-move-up ()
  "Swap the node at point and its subtree with the sibling above them."
  (interactive)
  (let* ((node (or (ibis-mode--node-at-point)
                   (user-error "No IBIS node at point")))
         (offset (max 0 (- (point) (ibis-mode--text-beginning))))
         (previous (or (ibis-mode--previous-sibling-beginning node)
                       (user-error "No previous sibling"))))
    (goto-char previous)
    (ibis-mode--swap-with-next-sibling)
    (goto-char previous)
    (goto-char (+ (ibis-mode--text-beginning) offset))))

(defun ibis-mode--tags-in-buffer ()
  "Return the hashtag names used in the buffer, in order of first use."
  (let ((tags nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward ibis-mode--hashtag-rx nil t)
        (push (substring (match-string-no-properties 1) 1) tags)))
    (delete-dups (nreverse tags))))

(defun ibis-toggle-tag (tag)
  "Add TAG to the line at point, or remove it when it is already there.

TAG is a hashtag name without its leading `#'."
  (interactive (list (completing-read "Tag: " (ibis-mode--tags-in-buffer))))
  (save-excursion
    (let ((pattern (rx-to-string `(seq " #" (literal ,tag) (or " " eol)) t))
          (eol (line-end-position)))
      (goto-char (line-beginning-position))
      (if (re-search-forward pattern eol t)
          (delete-region (match-beginning 0)
                         (+ (match-beginning 0) 2 (length tag)))
        (goto-char eol)
        (insert " #" tag)))))

(defun ibis-flymake (report-fn &rest _)
  "Report the parser diagnostics of the current buffer to REPORT-FN.

A backend for `flymake-diagnostic-functions'."
  (let ((buffer (current-buffer)))
    (funcall
     report-fn
     (mapcar (lambda (diagnostic)
               (let ((beg (car diagnostic)))
                 (flymake-make-diagnostic
                  buffer beg
                  (save-excursion (goto-char beg) (line-end-position))
                  :error (cdr diagnostic))))
             (cdr (ibis-parse-buffer))))))

(defun ibis-check ()
  "Parse the buffer and show what the grammar rejects."
  (interactive)
  (flymake-mode 1)
  (flymake-start)
  (if noninteractive
      (dolist (diagnostic (flymake-diagnostics))
        (message "%s" (flymake-diagnostic-text diagnostic)))
    (flymake-show-buffer-diagnostics)))

(defvar-keymap ibis-mode-map
  :doc "Keymap for `ibis-mode'."
  "RET" #'ibis-newline-and-indent
  "M-RET" #'ibis-insert-sibling
  "S-<return>" #'ibis-insert-child
  "M-<left>" #'ibis-promote
  "M-<right>" #'ibis-demote
  "M-<up>" #'ibis-move-up
  "M-<down>" #'ibis-move-down
  "C-c ?" #'ibis-insert-issue
  "C-c >" #'ibis-insert-position
  "C-c +" #'ibis-insert-pro
  "C-c -" #'ibis-insert-con
  "C-c t" #'ibis-toggle-tag
  "C-c C-c" #'ibis-check)

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
  (setq-local indent-tabs-mode nil)
  (setq-local outline-regexp ibis-mode--outline-rx)
  (setq-local outline-level #'ibis-mode--outline-level)
  (setq-local imenu-create-index-function #'ibis-mode--imenu-index)
  (add-hook 'flymake-diagnostic-functions #'ibis-flymake nil t)
  (setq-local require-final-newline t)
  (setq-local comment-start nil)
  (add-hook 'post-self-insert-hook #'ibis-mode--replace-typed-arrow nil t))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ibis\\'" . ibis-mode))

(provide 'ibis-mode)

;;; ibis-mode.el ends here
