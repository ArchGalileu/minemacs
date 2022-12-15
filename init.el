;; init.el --- MinEmacs -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa <abougouffa@fedoraproject.org>

;; Load vars if they have not been loaded (if Emacs has been loaded
;; directly from "init.el" without passing by "early-init.el")
(unless (featurep 'me-vars)
  ;; Load MinEmacs variables first
  (load (concat user-emacs-directory "core/me-vars.el") nil t))

;; Load Emacs 29 backports for earlier Emacs versions
(when (< emacs-major-version 29)
  (load (concat minemacs-modules-dir "me-backports-29.el") nil (not minemacs-verbose)))

;; Enable debugging on error when env variable "MINEMACS_DEBUG" is defined
(setq debug-on-error minemacs-debug)

;;; Byte compilation
(setq byte-compile-warnings minemacs-verbose
      byte-compile-verbose minemacs-verbose)

;;; Native compilation settings
(when (featurep 'native-compile)
  ;; Silence compiler warnings as they can be pretty disruptive
  (setq native-comp-async-report-warnings-errors (when minemacs-verbose 'silent)
        native-comp-verbose (if minemacs-verbose 3 0))

  ;; Make native compilation happens asynchronously
  (if (< emacs-major-version 29)
      (setq native-comp-deferred-compilation t)
    (setq inhibit-automatic-native-compilation nil))

  ;; Set the right directory to store the native compilation cache
  ;; NOTE the method for setting the eln-cache directory depends on the emacs version
  (let ((cache-dir (convert-standard-filename (concat minemacs-cache-dir "eln/"))))
    (if (fboundp 'startup-redirect-eln-cache)
        (startup-redirect-eln-cache cache-dir)
      (add-to-list 'native-comp-eln-load-path cache-dir))))

;; Add direcotries to `load-path'
(add-to-list 'load-path minemacs-core-dir)
(add-to-list 'load-path (concat minemacs-root-dir "elisp/"))
(add-to-list 'load-path (concat minemacs-modules-dir "extras/"))

(defun minemacs-generate-autoloads ()
  "Generate MinEmacs' autoloads file."
  (interactive)
  (when (file-exists-p minemacs-autoloads-file)
    (delete-file minemacs-autoloads-file))

  (let ((autoload-dirs nil))
    (dolist (dir (list minemacs-core-dir
                       minemacs-modules-dir
                       (concat minemacs-root-dir "elisp/")))
      (when (file-directory-p dir)
        (setq autoload-dirs
              (append autoload-dirs
                      (list dir)
                      (seq-filter
                       #'file-directory-p
                       (directory-files-recursively dir ".*" t))))))
    (loaddefs-generate autoload-dirs minemacs-autoloads-file)))

;; Auto-loads
(unless (file-exists-p minemacs-autoloads-file)
  (minemacs-generate-autoloads))

;; Load autoloads file
(load minemacs-autoloads-file nil (not minemacs-verbose))

;; Load environment variables when available
(+env-load)


;; Syncronization point!
;; Profile emacs startup and trigger `minemacs-loaded' 5s after loading Emacs
(add-hook
 'emacs-startup-hook
 (defun +minemacs--loaded-h ()
   (+log! "=============== Loaded Emacs ===============")
   (+info! "Loaded Emacs in %s." (emacs-init-time))

   (+log! "Applying `minemacs-fonts'.")
   ;; Load fonts, values are read from `minemacs-fonts' if set in config.el,
   ;; otherwise, they are read from the default `minemacs-default-fonts'.
   (+set-fonts)

   (+log! "Setting scratch buffer content.")
   ;; Print load time, and a quote to *scratch*
   (with-current-buffer (get-buffer-create "*scratch*")
     (erase-buffer)
     (insert (format ";; MinEmacs loaded in %.3f seconds.\n"
                     (string-to-number (car (string-split (emacs-init-time))))))
     (insert ";; ==============================\n")
     (when (executable-find "fortune")
       (insert (string-join
                (mapcar (lambda (l) (concat ";; " l))
                        (string-lines (shell-command-to-string "fortune")))
                "\n"))
       (insert "\n;; ==============================\n"))
     ;; Set initial scratch message.
     (setq initial-scratch-message (buffer-string)))

   ;; In `me-defaults', the `initial-major-mode' is set to `fundamental-mode'
   ;; to enhance startup time. However, I like to use the scratch buffer to
   ;; evaluate Elisp code, so we switch back to Elisp mode in the scratch
   ;; buffer when idle.
   (+eval-when-idle!
    (setq initial-major-mode 'emacs-lisp-mode)
    (with-current-buffer "*scratch*"
      (emacs-lisp-mode)))

   ;; Require the virtual package to triggre loading packages depending on it
   (require 'minemacs-loaded)

   ;; Run hooks
   (when (bound-and-true-p minemacs-after-startup-hook)
     (run-hooks 'minemacs-after-startup-hook))))

;;; Write user custom variables to separate file instead of init.el
(setq custom-file (concat minemacs-config-dir "custom-vars.el"))

;; Define default modules if they aren't already defined
(unless (bound-and-true-p minemacs-core-modules)
  (defcustom minemacs-core-modules
    '(defaults
      splash
      bootstrap
      core-ui
      keybindings
      evil
      completion)
    "MinEmacs enabled core modules."))

(unless (bound-and-true-p minemacs-modules)
  (defcustom minemacs-modules
    '(ui
      editor
      vc
      project
      prog
      lisp
      data
      org
      notes
      ;; mu4e
      docs
      ;; latex
      natural-langs
      files
      tools
      biblio
      ;; daemon
      rss
      ;; ros
      ;; embedded
      eaf
      ;; math
      window
      media
      binary)
    "MinEmacs enabled modules."))

;; The modules.el file can override minemacs-modules and minemacs-core-modules
(let ((mods (concat minemacs-config-dir "modules.el")))
  (when (file-exists-p mods)
    (+log! "Loading modules file from \"%s\"" mods)
    (load mods nil (not minemacs-verbose))))

(defun minemacs-load (&optional load-core-modules)
  "Reload all configuration, including user's config.el."

  ;; Load fonts early (they are read from the default `minemacs-default-fonts').
  (+set-fonts)

  ;; Core modules
  (when load-core-modules
    (dolist (module minemacs-core-modules)
      (+log! "Loading core module \"%s\"" module)
      (let ((filename (concat minemacs-core-dir (format "me-%s.el" module))))
        (if (file-exists-p filename)
            (load filename nil (not minemacs-verbose))
          (+info! "Core module \"%s\" not found!" module)))))

  ;; Modules
  (dolist (module minemacs-modules)
    (+log! "Loading module \"%s\"" module)
    (let ((filename (concat minemacs-modules-dir (format "me-%s.el" module))))
      (if (file-exists-p filename)
          (load filename nil (not minemacs-verbose))
        (+info! "Module \"%s\" not found!" module))))

  (when (and custom-file (file-exists-p custom-file))
    (+log! "Loafing user customs from custom.el")
    (load custom-file nil (not minemacs-verbose)))

  ;; Load user config when available
  (let ((user-config (concat minemacs-config-dir "config.el")))
    (when (file-exists-p user-config)
      (+log! "Loading user config file from \"%s\"" user-config)
      (load user-config nil (not minemacs-verbose))))

  (with-eval-after-load 'minemacs-loaded
    ;; Delete outdated natively compiled files
    (when (featurep 'native-compile)
      (+eval-when-idle!
       (+info! "Trying to clean outdated native compile cache")
       (+shutup!
        (native-compile-prune-cache))))

    ;; Load GC module lastly
    (+eval-when-idle!
     (+info! "Activating the garbage collector hacks")
     (load (concat minemacs-core-dir "me-gc.el")
           nil (not minemacs-verbose)))))

;; Load for the first time
(minemacs-load t)

(+log! "Loaded init.el")
