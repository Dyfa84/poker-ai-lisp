;; Benchmark: plays full games with SBCL and prints win rates.
;; Run from the repository root:
;;   sbcl --non-interactive --load benchmark.lisp
;; Smaller run:
;;   sbcl --non-interactive --eval "(defvar *table-games* 200)" --eval "(defvar *heads-up-games* 100)" --load benchmark.lisp

(setf *random-state* (make-random-state t))
(load "main.lisp")

(defvar *table-games* 5000)
(defvar *heads-up-games* 1000)

;; Plays one game with the engine's output silenced.
;; Returns :ok, :engine-error or :crash, and the captured log.
(defun play-silently (thunk)
  (let* ((out (make-string-output-stream))
         (result (handler-case
                     (let ((*standard-output* out)
                           (*standard-input* (make-string-input-stream "")))
                       (funcall thunk)
                       :ok)
                   (end-of-file () :engine-error)
                   (error () :crash))))
    (values result (get-output-stream-string out))))

(defun count-occurrences (sub text)
  (loop with start = 0
        for pos = (search sub text :start2 start)
        while pos
        count t
        do (setf start (1+ pos))))

(defun game-winner (log)
  (let ((end (search " takes all" log)))
    (if end
        (subseq log (+ (search "Game finished: " log :from-end t) 15) end)
        "NONE")))

(defun percent (n total)
  (if (zerop total) 0 (/ (* 100.0 n) total)))

;; 4-player table: the AI against the three course bots
(let ((wins (make-hash-table :test 'equal))
      (errors 0)
      (hands 0))
  (dotimes (i *table-games*)
    (multiple-value-bind (result log) (play-silently #'test-full-AI)
      (if (eq result :ok)
          (progn
            (incf (gethash (game-winner log) wins 0))
            (incf hands (count-occurrences "Shuffled deck" log)))
          (incf errors))))
  (format t "~%4-player table, ~a games (~a hands, ~a errors)~%" *table-games* hands errors)
  (dolist (player '("AI" "NOOB1" "NOOB2" "NOOB3"))
    (let ((n (gethash player wins 0)))
      (format t "  ~6a ~5,1f%  (~a wins)~%" player (percent n *table-games*) n))))

;; Heads-up: the AI against each bot alone
(dolist (bot '(noob1 noob2 noob3))
  (let ((set-hand (intern (format nil "~a-SET-HAND" bot)))
        (get-hand (intern (format nil "~a-GET-HAND" bot)))
        (ai-wins 0)
        (errors 0))
    (dotimes (i *heads-up-games*)
      (multiple-value-bind (result log)
          (play-silently
           (lambda ()
             (full-game (list (list bot 1000 0 'in) (list 'AI 1000 0 'in))
                        (list set-hand 'AI-set-hand)
                        (list get-hand 'AI-get-hand))))
        (if (eq result :ok)
            (when (string= (game-winner log) "AI") (incf ai-wins))
            (incf errors))))
    (format t "Heads-up vs ~a: AI wins ~5,1f% of ~a games (~a errors)~%"
            bot (percent ai-wins *heads-up-games*) *heads-up-games* errors)))
