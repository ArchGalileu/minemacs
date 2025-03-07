;;; lisp.el --- Lisp, Scheme, Elisp -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2023  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa (concat "abougouffa" "@" "fedora" "project" "." "org")

;;; Commentary:

;;; Code:

(unless (+emacs-features-p 'modules)
  (add-to-list 'minemacs-disabled-packages 'parinfer-rust-mode))

(use-package parinfer-rust-mode
  :straight t
  :when (eq sys/arch 'x86_64)
  :custom
  (parinfer-rust-library-directory (concat minemacs-local-dir "parinfer-rust/"))
  (parinfer-rust-auto-download (eq sys/arch 'x86_64))
  :hook (emacs-lisp-mode clojure-mode scheme-mode lisp-mode racket-mode hy-mode)
  :config
  (defvar-local +parinter-rust--was-enabled-p nil)

  ;; HACK: Disable `parinfer-rust-mode' on some commands.
  (defun +parinter-rust--restore-a (&rest _)
    (when +parinter-rust--was-enabled-p
      (setq +parinter-rust--was-enabled-p nil)
      (parinfer-rust-mode 1)))

  (defun +parinter-rust--disable-a (&rest _)
    (if (and (bound-and-true-p parinfer-rust-mode)
             (bound-and-true-p parinfer-rust-enabled))
        (progn
          (setq +parinter-rust--was-enabled-p t)
          (parinfer-rust-mode -1))
      (setq +parinter-rust--was-enabled-p nil)))

  (dolist (cmd '(evil-shift-right))
    (advice-add cmd :before #'+parinter-rust--disable-a)
    (advice-add cmd :after #'+parinter-rust--restore-a)))

;; Common Lisp
(use-package sly
  :straight t
  :custom
  (sly-mrepl-history-file-name (+directory-ensure minemacs-local-dir "sly/mrepl-history.el"))
  (sly-net-coding-system 'utf-8-unix)
  :config
  (dolist (impl '("lisp"   ; Default Lisp implementation on the system
                  "clisp"  ; GNU CLISP
                  "abcl"   ; Armed Bear Common Lisp
                  "ecl"    ; Embeddable Common-Lisp
                  "gcl"    ; GNU Common Lisp
                  "ccl"    ; Clozure Common Lisp
                  "cmucl"  ; CMU Common Lisp
                  "clasp"  ; Common Lisp on LLVM
                  "sbcl")) ; Steel Bank Common Lisp
    (when (executable-find impl)
      (add-to-list
       'sly-lisp-implementations
       `(,(intern impl) (,impl) :coding-system utf-8-unix))))
  (setq inferior-lisp-program (caar (cdar sly-lisp-implementations))
        sly-default-lisp (caar sly-lisp-implementations))

  (+map-local! :keymaps '(lisp-mode-map)
    "s"  #'sly
    "c"  '(nil :wk "compile")
    "cc" #'sly-compile-file
    "cC" #'sly-compile-and-load-file
    "cd" #'sly-compile-defun
    "cr" #'sly-compile-region
    "g"  '(nil :wk "goto/find")
    "gn" #'sly-goto-first-note
    "gL" #'sly-load-file
    "gn" #'sly-next-note
    "gN" #'sly-previous-note
    "gs" #'sly-stickers-next-sticker
    "gS" #'sly-stickers-prev-sticker
    "gN" #'sly-previous-note
    "gd" #'sly-edit-definition
    "gD" #'sly-edit-definition-other-window
    "gb" #'sly-pop-find-definition-stack
    "h"  '(nil :wk "help/info")
    "hs" #'sly-describe-symbol
    "hf" #'sly-describe-function
    "hc" #'sly-who-calls
    "hC" #'sly-calls-who
    "hs" #'sly-who-calls
    "hC" #'sly-calls-who
    "hd" #'sly-disassemble-symbol
    "hD" #'sly-disassemble-definition
    "r"  '(nil :wk "repl")
    "rr" #'sly-restart-inferior-lisp
    "rc" #'sly-mrepl-clear-repl
    "rs" #'sly-mrepl-sync
    "rn" #'sly-mrepl-new
    "rq" #'sly-quit-lisp))

(use-package sly-quicklisp
  :straight t
  :after sly
  :demand t)

(use-package sly-asdf
  :straight t
  :after sly
  :demand t)

(use-package sly-repl-ansi-color
  :straight t
  :after sly
  :demand t)

;; Scheme
(use-package racket-mode
  :straight t)

(use-package geiser
  :straight t
  :custom
  (geiser-default-implementation 'guile))

(use-package geiser-chez
  :straight t)

(use-package geiser-guile
  :straight t)

(use-package geiser-mit
  :straight t)

(use-package geiser-racket
  :straight t)

;; Clojure
(use-package clojure-mode
  :straight t)

(use-package cider
  :straight t)

(use-package macrostep
  :straight t
  :init
  (+map-local! :keymaps '(emacs-lisp-mode-map lisp-mode-map)
    "m" '(macrostep-expand :wk "Expand macro")))

(use-package macrostep-geiser
  :straight t
  :after geiser
  :hook ((geiser-mode geiser-repl-mode) . macrostep-geiser-setup)
  :init
  (+map-local! :keymaps '(geiser-mode-map geiser-repl-mode-map)
    "m" '(macrostep-expand :wk "Expand macro")
    "M" #'macrostep-geiser-expand-all))

(use-package sly-macrostep
  :straight t
  :after sly
  :demand t
  :init
  (+map-local! :keymaps '(sly-mode-map sly-editing-mode-map sly-mrepl-mode-map)
    "m" '(macrostep-expand :wk "Expand macro")))

(use-package me-elisp-extras
  :after elisp-mode minemacs-loaded
  :demand t
  :config
  (+elisp-indent-setup)
  (+elisp-highlighting-setup))

(use-package elisp-demos
  :straight t
  :after elisp-mode minemacs-loaded
  :demand t
  :init
  (+map! :infix "he"
    "d" #'elisp-demos-find-demo
    "D" #'elisp-demos-add-demo)
  (advice-add 'describe-function-1 :after #'elisp-demos-advice-describe-function-1)
  (advice-add 'helpful-update :after #'elisp-demos-advice-helpful-update))

(use-package helpful
  :straight t
  :init
  (+map! :keymaps 'emacs-lisp-mode-map
    :infix "h"
    "p" #'helpful-at-point
    "o" #'helpful-symbol
    "c" #'helpful-command
    "F" #'helpful-function
    "f" #'helpful-callable))

(use-package info-colors
  :straight t
  :hook (Info-selection . info-colors-fontify-node))

(use-package eros
  :straight t
  :after elisp-mode minemacs-loaded
  :demand t
  :custom
  (eros-eval-result-prefix "⟹ ")
  :config
  (eros-mode 1)

  ;; Add an Elisp-like evaluation for Octave
  (with-eval-after-load 'octave
    (defun +eros-octave-eval-last-sexp ()
      "Wrapper for `+octave-eval-last-sexp' that overlays results."
      (interactive)
      (eros--eval-overlay (+octave-eval-last-sexp) (point)))

    (+map-local! :keymaps 'octave-mode-map
      "e"  '(nil :wk "eval")
      "ee" #'+eros-octave-eval-last-sexp)))


(provide 'me-lisp)

;;; me-lisp.el ends here
