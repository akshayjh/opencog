;; Tools generally useful for testing / debugging GHOST

(define-public (ghost-debug-mode)
 "
  Print the debug messages to stdout.
"
  (cog-logger-set-level! ghost-logger "debug")
  (cog-logger-set-stdout! ghost-logger #t))

; ----------
(define-public (ghost-debug-mode-off)
"
  Change the logger level to \"info\".
"
  (cog-logger-set-level! ghost-logger "info"))

; ----------
(define ghost-with-ecan #f)

(define-public (ecan-based-ghost-rules flag)
"
  For experimental purpose
  To create GHOST rules that are slimmer.
"
  (set! ghost-with-ecan flag)
)

; ----------
; TODO: Remove once experimentation is over
(define expt-var '())
; TODO: Should be removed as this is using 'ghost-find-rules',
; which will be obsolete soon
(define-public (test-ghost TXT)
"
  Try to find (and execute) the matching rules given an input TXT.
"
  (ghost TXT)
  (let ((rule (cog-outgoing-set (ghost-find-rules (ghost-get-curr-sent)))))
    (map (lambda (r) (psi-imply r)) rule)
    ; not using ghost-last-executed, because getting back to the rule
    ; from the alias atom is a hassle.
    (set! expt-var rule)
  )
  *unspecified*)

(define-public (ghost-action-executed?)
  (if (null? expt-var) (stv 0 1) (psi-action-executed? (car expt-var)))
)

; ----------
(define-public (ghost-get-result)
"
  Return the most recent result generated by executed an action.
"
  ghost-result)

; ----------
; For experimental purpose
; To get psi-rules only from the attentional focus (default),
; or get all psi-rules from the atomspace in case none of them reach
; the attentional focus
; Either way the rules will be selected based on their weights
(define ghost-af-only? #t)
(define-public (ghost-af-only AF-ONLY)
"
  To decide whether or not to get rules only from the attentional focus
  when doing action selection.
"
  (if AF-ONLY
    (set! ghost-af-only? #t)
    (set! ghost-af-only? #f)))

; ----------
(define-public (ghost-show-lemmas)
"
  Show the lemmas that havn been queried via 'get-lemma'.
"
  (display lemma-alist)
  (newline))

; ----------
(define-public (ghost-check-lemma WORD)
"
  Show the lemma of the word.
"
  (assoc-ref lemma-alist WORD)
)

; ----------
(define-public (ghost-add-lemma WORD LEMMA)
"
  Add an entry to the lemma list.
"
  (set! lemma-alist (assoc-set! lemma-alist WORD LEMMA))
)

; ----------
(define-public (ghost-remove-lemma WORD)
"
  Remove an entry from the lemma list.
"
  (set! lemma-alist (assoc-remove! lemma-alist WORD))
)

; ----------
(define-public (ghost-show-vars)
"
  Show the groundings of the user variables that has been assigned to
  some value.
"
  (format #t "=== User Variables\n~a\n" uvars))

; ----------
(define-public (ghost-get-curr-sent)
"
  Get the SentenceNode that is being processed currently.
"
  (define sent (cog-chase-link 'StateLink 'SentenceNode ghost-curr-proc))
  (if (null? sent) '() (car sent)))

; ----------
(define-public (ghost-get-curr-topic)
"
  Get the current topic.
"
  (gar (cog-execute! (Get (State ghost-curr-topic (Variable "$x"))))))

; ----------
(define-public (ghost-currently-processing)
"
  Get the sentence that is currently being processed.
"
  (let ((sent (ghost-get-curr-sent)))
    (if (null? sent)
        '()
        (car (filter (lambda (e) (equal? ghost-word-seq (gar e)))
                     (cog-get-pred (ghost-get-curr-sent) 'PredicateNode))))))

; ----------
(define*-public (ghost-get-relex-outputs #:optional (SENT (ghost-get-curr-sent)))
"
  Get the RelEx outputs generated for the current sentence.
"
  (parse-get-relex-outputs (car (sentence-get-parses SENT))))

; ----------
(define*-public (ghost-show-relation #:optional (SENT (ghost-get-curr-sent)))
"
  Get a subset of the RelEx outputs of a sentence that GHOST cares.
  SENT is a SentenceNode, if not given, it will be the current input.
"
  (define parses (sentence-get-parses SENT))
  (define relex-outputs (append-map parse-get-relex-outputs parses))
  (filter
    (lambda (r)
      (define type (cog-type r))
      (or (equal? 'ParseLink type)
          (equal? 'WordInstanceLink type)
          (equal? 'ReferenceLink type)
          (equal? 'LemmaLink type)))
    relex-outputs))

; ----------
(define-public (ghost-get-rule LABEL)
"
  Return the rule with the given label.
"
  (get-rule-from-label LABEL))

; ----------
(define-public (ghost-rule-av LABEL)
"
  Given the label of a rule in string, return the AV of the rule with that label.
"
  (cog-av (get-rule-from-label LABEL)))

; ----------
(define-public (ghost-rule-tv LABEL)
"
  Given the label of a rule in string, return the TV of the rule with that label.
"
  (cog-tv (get-rule-from-label LABEL)))

; ----------
(define-public (ghost-show-rule-status LABEL)
"
  Given the label of a rule in string, return both the STI and TV of the rule
  with that label.
"
  (define rule (get-rule-from-label LABEL))
  (define next-responder (cog-value rule ghost-next-responder))
  (define next-rejoinder (cog-value rule ghost-next-rejoinder))
  (if (not (null? rule))
    (format #t (string-append
      "AV = ~a\n"
      "TV = ~a\n"
      "Satisfiability: ~a\n"
      "Next responder: ~a\n"
      "Next rejoinder: ~a\n")
      (cog-av rule)
      (cog-tv rule)
      (every
        (lambda (x) (> (cdr (assoc 'mean (cog-tv->alist (cog-evaluate! x)))) 0))
        (psi-get-context rule))
      (if (null? next-responder)
        (list)
        (append-map psi-rule-alias (cog-value->list next-responder)))
      (if (null? next-rejoinder)
        (list)
        (append-map psi-rule-alias (cog-value->list next-rejoinder))))))

; ----------
(define-public (ghost-show-status)
"
  Show current status of GHOST.
"
  (define last-rule (cog-chase-link 'StateLink 'ConceptNode ghost-last-executed))
  (display
    (format #f
      (string-append
        "GHOST loop count: ~a\n"
        "AF only? ~a\n"
        "-----\n"
        "Strength weight: ~a\n"
        "Context weight: ~a\n"
        "STI weight: ~a\n"
        "Urge weight: ~a\n"
        "-----\n"
        "Rules Found: ~a\n"
        "Rules Evaluated: ~a\n"
        "Rules Satisfied: ~a\n"
        "Last Triggered Rule: (~a)\n\n")
      (psi-loop-count (ghost-get-component))
      (if ghost-af-only? "T" "F")
      strength-weight
      context-weight
      sti-weight
      urge-weight
      num-rules-found
      num-rules-evaluated
      num-rules-satisfied
      (if (null? last-rule) "N.A." (cog-name (car last-rule))))))

; ----------
(define-public (ghost-show-executed-rules)
"
  Show a list of rules that have been executed.
"
  (define rset (cog-execute! (Get
    (Evaluation (Predicate "GHOST Rule Executed") (List (Variable "$x"))))))

  (define rtn (cog-outgoing-set rset))

  ; Remove the SetLink
  (cog-extract rset)

  rtn
)

; ----------
(define-public (ghost-set-strength-weight VAL)
"
  Set the weight of the strength used duing action selection.
"
  (if (number? VAL)
    (set! strength-weight VAL)
    (cog-logger-warn ghost-logger
      "The weight has to be a numeric value!"))
)

; ----------
(define-public (ghost-set-context-weight VAL)
"
  Set the weight of the context used duing action selection.
"
  (if (number? VAL)
    (set! context-weight VAL)
    (cog-logger-warn ghost-logger
      "The weight has to be a numeric value!"))
)

; ----------
(define-public (ghost-set-sti-weight VAL)
"
  Set the weight of the STI used duing action selection.
"
  (if (number? VAL)
    (set! sti-weight VAL)
    (cog-logger-warn ghost-logger
      "The weight has to be a numeric value!"))
)

; ----------
(define-public (ghost-set-urge-weight VAL)
"
  Set the weight of the urge used duing action selection.
"
  (if (number? VAL)
    (set! urge-weight VAL)
    (cog-logger-warn ghost-logger
      "The weight has to be a numeric value!"))
)

; ----------
(define-public (ghost-set-rep-sti-boost VAL)
"
  ghost-set-rep-sti-boost VAL

  Set how much of a default stimulus will be given to
  the next responder after triggering the previous
  one in the sequence.
"
  (if (number? VAL)
    (set! responder-sti-boost VAL)
    (cog-logger-warn ghost-logger
      "The responder STI boost has to be a numberic value!"))
)

; ----------
(define-public (ghost-set-rej-sti-boost VAL)
"
  ghost-set-rej-sti-boost VAL

  Set how much of a default stimulus will be given to
  the next rejoinder(s) after triggering the parent rule.
"
  (if (number? VAL)
    (set! rejoinder-sti-boost VAL)
    (cog-logger-warn ghost-logger
      "The rejoinder STI boost has to be a numberic value!"))
)
