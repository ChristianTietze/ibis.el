;;; ibis-transient.el --- Transient menu for ibis-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Christian Tietze

;; Author: Christian Tietze <me@christiantietze.de>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (ibis-mode "0.1.0"))
;; Keywords: outlines, wp
;; URL: https://github.com/ChristianTietze/ibis.el

;; This file is not part of GNU Emacs.

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

;; Optional menu for `ibis-mode' built on `transient'.  Loading this
;; file binds the menu to `C-c m' in `ibis-mode-map'; nothing else
;; in the package depends on it.

;;; Code:

(require 'ibis-mode)
(require 'transient)

;;;###autoload (autoload 'ibis-transient-menu "ibis-transient" nil t)
(transient-define-prefix ibis-transient-menu ()
  "Menu of the `ibis-mode' editing commands."
  ["Insert"
   ("i" "issue" ibis-insert-issue)
   ("I" "issue (root)" ibis-insert-root-issue)
   (">" "position" ibis-insert-position)
   ("+" "pro" ibis-insert-pro)
   ("-" "con" ibis-insert-con)
   ("s" "sibling" ibis-insert-sibling)
   ("c" "child" ibis-insert-child)])

(keymap-set ibis-mode-map "C-c m" #'ibis-transient-menu)

(provide 'ibis-transient)
;;; ibis-transient.el ends here
