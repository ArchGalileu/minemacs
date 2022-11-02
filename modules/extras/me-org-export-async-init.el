;; -*- lexical-binding: t; -*-

(message "Using MinEmacs' \"me-org-export-async-init.el\" as init file.")

;; Load only some essential modules
(defvar minemacs-core-modules
  '(defaults bootstrap keybindings))

(defvar minemacs-modules
  '(org prog lisp data biblio))

;; To force loading Org and other stuff
(provide 'minemacs-loaded)

(load (concat user-emacs-directory "init.el"))
