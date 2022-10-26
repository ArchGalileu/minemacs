;; -*- lexical-binding: t; -*-


(defun +daemon--setup-background-apps ()
  (with-eval-after-load 'minemacs-loaded
    (+eval-when-idle!
     ;; mu4e
     (when (require 'mu4e nil t)
       (unless (mu4e-running-p)
         (let ((inhibit-message t))
           (mu4e t)
           (+info! "Started `mu4e' in background.")))))

    ;; RSS
    (+eval-when-idle!
     (run-at-time
      (* 60 5)
      (* 60 60 3)
      (lambda ()
        (let ((inhibit-message t))
          (+info! "Updating RSS feed.")
          (elfeed-update)))))

    (+eval-when-idle!
     (unless (daemonp)
       (let ((inhibit-message t))
         (+info! "Starting Emacs daemon in background.")
         (server-start nil t))))))


;; At daemon startup
(add-hook 'emacs-startup-hook #'+daemon--setup-background-apps)

;; Reload theme on Daemon
(add-hook
 'server-after-make-frame-hook
 (lambda ()
   (load-theme minemacs-theme t)))

(provide 'me-daemon)
