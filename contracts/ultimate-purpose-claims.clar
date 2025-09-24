;; Ultimate Purpose Claims
;; Automated compensation for purpose discovery failures and existential meaning loss
;; Processes claims based on policy data and eligibility checks without cross-contract calls

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_DUPLICATE (err u409))
(define-constant ERR_NOT_ELIGIBLE (err u412))
(define-constant ERR_POLICY_INACTIVE (err u410))
(define-constant ERR_PAYOUT_FAILED (err u500))

;; Claim status constants
(define-constant CLAIM_SUBMITTED u1)
(define-constant CLAIM_UNDER_REVIEW u2)
(define-constant CLAIM_APPROVED u3)
(define-constant CLAIM_REJECTED u4)
(define-constant CLAIM_PAID u5)

;; Local mirrors of policy-like data (decoupled; no cross-contract calls)
(define-map mirrored-policies 
  { policy-id: uint }
  {
    owner: principal,
    coverage-amount: uint,
    premium-amount: uint,
    created-at: uint,
    expires-at: uint,
    status: uint,
    progress-score: uint
  }
)

;; Claims data map
(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    claim-type: (string-ascii 80),
    description: (string-ascii 1000),
    submitted-at: uint,
    status: uint,
    review-notes: (string-ascii 1000),
    decision-at: uint,
    payout-amount: uint
  }
)

;; Per-policy claim index
(define-map policy-claims
  { policy-id: uint }
  { claims: (list 50 uint), total: uint }
)

;; Auto-increment counters and totals
(define-data-var next-claim-id uint u1)
(define-data-var total-claims uint u0)
(define-data-var total-paid uint u0)
(define-data-var claims-open uint u0)
(define-data-var claims-closed uint u0)

;; Private helpers

;; Validate mirrored policy existence and eligibility
(define-private (validate-policy-eligibility (policy-id uint))
  (match (map-get? mirrored-policies { policy-id: policy-id })
    p
    (let (
      (now (default-to u0 (get-stacks-block-info? time (- stacks-block-height u1))))
    )
      (ok (and 
        (is-eq (get status p) u1) ;; active
        (< now (get expires-at p))
      ))
    )
    ERR_NOT_FOUND
  )
)

;; Calculate payout based on rules: low progress -> higher payout
(define-private (calculate-payout (coverage uint) (progress-score uint) (claim-type (string-ascii 80)))
  (let (
    (base (/ (* coverage u50) u100))
    (penalty (/ (* progress-score u30) u100))
    (type-bonus (if (is-eq claim-type "purpose-discovery-failure") u20 (if (is-eq claim-type "meaning-loss") u15 u10)))
    (payout (/ (* (+ base (* coverage type-bonus)) (- u100 penalty)) u100))
  )
    (if (> payout coverage) coverage payout)
  )
)

;; Append claim to policy list
(define-private (append-policy-claim (policy-id uint) (claim-id uint))
  (let (
    (entry (default-to { claims: (list), total: u0 } (map-get? policy-claims { policy-id: policy-id })))
    (updated (unwrap! (as-max-len? (append (get claims entry) claim-id) u50) false))
  )
    (map-set policy-claims { policy-id: policy-id } { claims: updated, total: (+ (get total entry) u1) })
  )
)

;; Public functions

;; Mirror policy data from external source (admin controlled; avoids cross-contract calls)
(define-public (mirror-policy 
    (policy-id uint)
    (owner principal)
    (coverage uint)
    (premium uint)
    (created-at uint)
    (expires-at uint)
    (status uint)
    (progress-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set mirrored-policies { policy-id: policy-id } {
      owner: owner,
      coverage-amount: coverage,
      premium-amount: premium,
      created-at: created-at,
      expires-at: expires-at,
      status: status,
      progress-score: progress-score
    })
    (ok true)
  )
)

;; File a new claim
(define-public (file-claim 
    (policy-id uint)
    (claim-type (string-ascii 80))
    (description (string-ascii 1000)))
  (let (
    (elig (unwrap! (validate-policy-eligibility policy-id) ERR_NOT_FOUND))
    (now (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND))
    (policy (unwrap! (map-get? mirrored-policies { policy-id: policy-id }) ERR_NOT_FOUND))
  )
    (asserts! elig ERR_NOT_ELIGIBLE)
    (asserts! (> (len description) u20) ERR_INVALID_INPUT)
    
    (let (
      (cid (var-get next-claim-id))
    )
      (map-set claims { claim-id: cid } {
        policy-id: policy-id,
        claimant: tx-sender,
        claim-type: claim-type,
        description: description,
        submitted-at: now,
        status: CLAIM_SUBMITTED,
        review-notes: "",
        decision-at: u0,
        payout-amount: u0
      })
      (append-policy-claim policy-id cid)
      (var-set next-claim-id (+ cid u1))
      (var-set total-claims (+ (var-get total-claims) u1))
      (var-set claims-open (+ (var-get claims-open) u1))
      (ok cid)
    )
  )
)

;; Review a claim and set status/notes
(define-public (review-claim (claim-id uint) (approve bool) (notes (string-ascii 1000)))
  (let (
    (cl (unwrap! (map-get? claims { claim-id: claim-id }) ERR_NOT_FOUND))
    (policy (unwrap! (map-get? mirrored-policies { policy-id: (get policy-id cl) }) ERR_NOT_FOUND))
    (now (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set claims { claim-id: claim-id } (merge cl {
      status: (if approve CLAIM_APPROVED CLAIM_REJECTED),
      review-notes: notes,
      decision-at: now
    }))
    (ok (if approve CLAIM_APPROVED CLAIM_REJECTED))
  )
)

;; Pay out an approved claim
(define-public (payout-claim (claim-id uint))
  (let (
    (cl (unwrap! (map-get? claims { claim-id: claim-id }) ERR_NOT_FOUND))
    (policy (unwrap! (map-get? mirrored-policies { policy-id: (get policy-id cl) }) ERR_NOT_FOUND))
    (approved (is-eq (get status cl) CLAIM_APPROVED))
    (amount (calculate-payout (get coverage-amount policy) (get progress-score policy) (get claim-type cl)))
  )
    (asserts! approved ERR_NOT_ELIGIBLE)
    ;; Attempt transfer to claimant from contract balance (simulation; requires contract funded)
    (match (stx-transfer? amount (as-contract tx-sender) (get claimant cl))
      result (begin
        (map-set claims { claim-id: claim-id } (merge cl { status: CLAIM_PAID, payout-amount: amount }))
        (var-set total-paid (+ (var-get total-paid) amount))
        (var-set claims-open (- (var-get claims-open) u1))
        (var-set claims-closed (+ (var-get claims-closed) u1))
        (ok amount)
      )
      err-val ERR_PAYOUT_FAILED
    )
  )
)

;; Read-only functions

(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-policy-mirror (policy-id uint))
  (map-get? mirrored-policies { policy-id: policy-id })
)

(define-read-only (get-policy-claims (policy-id uint))
  (map-get? policy-claims { policy-id: policy-id })
)

(define-read-only (get-claims-stats)
  {
    total-claims: (var-get total-claims),
    claims-open: (var-get claims-open),
    claims-closed: (var-get claims-closed),
    total-paid: (var-get total-paid)
  }
)

