;; Poker AI for Texas Hold'em: hand evaluation + threshold-based decision policy
(let
    (
        (hand nil)                   ; my cards
        (round-counter 0)            
        (previous-action `in)        ; dernière action effectuée
        (hand-base-strength 0.0)     ; force de la main préflop (mémorisée)
    )


    ;; Init
    (defun AI-set-hand (cards)
        (setf hand cards)
        (setf hand-base-strength 0.0)
        (setf round-counter 0)
    )

    (defun AI-get-hand () hand)



 ;ÉVALUATION DE LA MAIN
 (defun hand-strength (cards-on-table)
  (let* (
          (cards hand)
          (values (mapcar (lambda (card)
                            (let ((rank (first card)))
                              (if (= rank 1) 12 (- rank 2))))
                          cards))
          (v1 (first values))
          (v2 (second values))
          (suit1 (second (first cards)))
          (suit2 (second (second cards)))
          (score (+ v1 v2))
          (synergy 0)
          (color-bonus 0)
        )

    ;; Couleur
    (when (equal suit1 suit2)
      (setf color-bonus 10)
      (incf score color-bonus))

    ;; Synergy: connected cards
    (let* ((diff (min (abs (- v1 v2)) (- 13 (abs (- v1 v2))))))
      (cond
        ((= diff 0) (setf synergy 26))
        ((= diff 1) (setf synergy 15))
        ((= diff 2) (setf synergy 10))
        ((= diff 3) (setf synergy 5))
        ((= diff 4) (setf synergy 2))
        (t (setf synergy 0)))
      (incf score synergy))

    ;; Normalisation
    (let* ((max-score 52.0)
           (base-strength (min 1.0 (/ score max-score)))
           (board-strength 0.0))




;; Board penalties: dangerous boards
(when cards-on-table
  (let ((board-values (mapcar (lambda (card)
                                (let ((r (first card)))
                                  (if (= r 1) 12 (- r 2))))
                              cards-on-table))
        (board-suits (mapcar #'second cards-on-table)))

    ;; Pair sur le board 
    (when (some (lambda (v)
                  (> (count v board-values) 1))
                board-values)
      (decf board-strength 0.15)) ; paire sur board

    ;; Couleur 
    (let ((max-suit-count (apply #'max (mapcar (lambda (s)
                                                 (count s board-suits))
                                               (remove-duplicates board-suits)))))
      (when (>= max-suit-count 3)
        (decf board-strength 0.10))) ; 3+ memes couleurs sur board 

    ;; Séquence sur le board 
    (let* ((sorted (sort (remove-duplicates board-values) #'<))
           (straight 0))
      (loop for i from 0 below (- (length sorted) 1)
            do (when (= (1+ (nth i sorted)) (nth (1+ i) sorted))
                 (incf straight)))
      (when (>= straight 3)
        (decf board-strength 0.25))))) ; 3+ consécutives board dangereux










;board + cards
(let* ((all-cards (append hand cards-on-table))
       (values (mapcar (lambda (card)
                         (let ((rank (first card)))
                           (if (= rank 1) 12 (- rank 2))))
                       all-cards))
       (suits (mapcar #'second all-cards))
       (counts (mapcar (lambda (v)
                         (count v values))
                       (remove-duplicates values)))
       (max-count (apply #'max counts)))

  (cond
    ;; carré 
    ((= max-count 4)
     (incf board-strength 1))
    ;; full house 
    ((and (member 3 counts) (member 2 counts))
     (incf board-strength 0.85))
    ;; brelan
    ((= max-count 3)
     (incf board-strength 0.7))
    ;; double paire
    ((>= (count 2 counts) 2)
     (incf board-strength 0.5))
    ;; paire 
    ((= max-count 2)
     (incf board-strength 0.2)))

  ;; flush
  (when (>= (apply #'max (mapcar (lambda (s)
                                   (count s suits))
                                 (remove-duplicates suits)))
            5)
    (incf board-strength 0.8))

  ;; suite
  (let* ((sorted (sort (remove-duplicates values) #'<))
         (straight-run 1)
         (best-run 1))
    (loop for i from 1 below (length sorted) do
          (if (= (1+ (nth (- i 1) sorted)) (nth i sorted))
              (incf straight-run)
              (setf straight-run 1))
          (setf best-run (max best-run straight-run)))
    (when (>= best-run 5)
      (incf board-strength 0.5))))

      

      (setf board-strength (min 1.0 board-strength))
      (setf board-strength (max 0 board-strength))






(let* ((decay (case round-counter
                (0 1.0)
                (1 (+ 0.6 (* (random 1.0) (- 0.8 0.6)))) ; 0.6 , 0.8
                (2 (+ 0.4 (* (random 1.0) (- 0.6 0.4)))) ; 0.4 , 0.6
                (3 (+ 0.4 (* (random 1.0) (- 0.6 0.4)))) ; 0.4 , 0.6
                (t (+ 0.4 (* (random 1.0) (- 0.6 0.4)))))) ; 0.4 , 0.6
       (final-strength (+ (* decay base-strength)
                          (* (- 1 decay) board-strength))))
  (format t "[AI-LOG] Round: ~A | Base: ~,2F | Board: ~,2F | Decay: ~,2F | Final: ~,2F~%"
          round-counter base-strength board-strength decay final-strength)
  final-strength)
))
)








    ;; MDP 
    (defun mdp-decision (strength current-bet chips)
        (let* (
                (max-raise (max 0 (- chips current-bet)))
                (proposed-raise (truncate (* strength 0.3 max-raise)))
              )
          (format t "[AI-LOG] chips=~A | current-bet=~A | max-raise=~A | proposed=~A | strength=~,2F~%"
                  chips current-bet max-raise proposed-raise strength)

          (cond
            ((and (< strength 0.3) (> current-bet (* 0.2 chips)))
              (format t "[AI-DECISION] Weak hand + high bet → FOLD~%")
              `fold)

            ((< strength 0.6)
              (format t "[AI-DECISION] Medium hand → CALL/CHECK~%")
              `in)

            (t
              (if (and (> proposed-raise 0)
                       (> (random 1.0) 0.4))
                  (progn
                    (format t "[AI-DECISION] Strong hand → RAISE (~A)~%" (+ current-bet proposed-raise))
                    (min max-raise (+ current-bet proposed-raise)))
                  (progn
                    (format t "[AI-DECISION] Strong hand but cautious → CALL/CHECK~%")
                    `in))))))
    




    ;; Fonction principale 
    (defun AI (cards-on-table game-state)
        (let* (
                (state (find-if (lambda (x) (equal (nth 0 x) `AI)) game-state))
                (chips (nth 1 state))
                (current-bet (nth 2 state))
                (strength (hand-strength cards-on-table))
                (action (mdp-decision strength current-bet chips))
              )

          ;; Mise à jour des infos
          (setf previous-action action)
          (incf round-counter)

          ;; Reset 
          (when (> round-counter 999)
            (setf round-counter 0)
            (setf hand-base-strength 0.0))

          (format t "[AI-ROUND ~A] Action: ~A | Chips: ~A | Bet: ~A | Strength: ~,2F~%"
                  round-counter action chips current-bet strength)

          (if (or (null action)
                  (not (or (symbolp action)
                           (integerp action))))
              (progn
                (format t "[AI-WARNING] Invalid action (~A), defaulting to `in`.~%" action)
                `in)
              action)))
)














;simple player, never raises 
(let
	(
		(hand nil)
	)
	(defun noob1-set-hand (cards)
		(setf hand cards)
	)
	(defun noob1-get-hand ()
		hand
	)
	(defun noob1 
		(
			cards-on-table
			game-state	
		)
		;noob1 never raises, either checks/calls or folds
		(if (> (random 10) 7)
			`fold
			`in
		)		
  )
)

;simple player, never folds
(let
	(
		(hand nil)
	)
	(defun noob2-set-hand (cards)
		(setf hand cards)
	)
	(defun noob2-get-hand ()
		hand
	)
	(defun noob2
		(
			cards-on-table
			game-state	
		)
		(let
			(
				;our current state: chips, current bet
				(state 	(find-if 
									(lambda (x) 
										(if (equal (nth 0 x) `noob2)
											t
											nil
										)
									)
									game-state
								)
				)
			)
			;noob2 never folds, 
			;either checks/calls or raises big blind
			;if it has enough money
			(if (> (random 10) 7)
				(if (>= (nth 1 state) 40)
					40
					(nth 1 state)
				)
				`in
			)
		)		
  )
)

;simple player, never folds
(let
	(
		(hand nil)
	)
	(defun noob3-set-hand (cards)
		(setf hand cards)
	)
	(defun noob3-get-hand ()
		hand
	)
	(defun noob3
		(
			cards-on-table
			game-state	
		)
		;noob3 never raises, either checks/calls or folds
		(if (> (random 10) 7)
			`fold
			`in
		)
  )		
)
