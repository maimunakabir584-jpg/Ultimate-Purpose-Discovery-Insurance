;; Purpose Discovery Oracle
;; Universal purpose detection monitoring and meaning revelation verification system
;; Provides comprehensive tracking of existential journey progress and purpose clarity metrics

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_POLICY (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_POLICY_EXPIRED (err u410))
(define-constant ERR_ALREADY_EXISTS (err u409))

;; Policy status constants
(define-constant POLICY_ACTIVE u1)
(define-constant POLICY_SUSPENDED u2)
(define-constant POLICY_EXPIRED u3)
(define-constant POLICY_CLAIMED u4)

;; Purpose clarity levels
(define-constant CLARITY_UNKNOWN u0)
(define-constant CLARITY_SEARCHING u1)
(define-constant CLARITY_EMERGING u2)
(define-constant CLARITY_DEFINED u3)
(define-constant CLARITY_ACTUALIZED u4)

;; Data Variables
(define-data-var next-policy-id uint u1)
(define-data-var oracle-active bool true)
(define-data-var total-policies uint u0)
(define-data-var total-premiums uint u0)

;; Data Maps
;; Policy structure mapping
(define-map policies 
  { policy-id: uint }
  {
    owner: principal,
    purpose-description: (string-ascii 500),
    coverage-amount: uint,
    premium-amount: uint,
    duration-days: uint,
    created-at: uint,
    expires-at: uint,
    status: uint,
    clarity-level: uint,
    progress-score: uint,
    last-assessment: uint
  }
)

;; User policy mapping for quick lookup
(define-map user-policies
  { owner: principal }
  { active-policies: (list 10 uint), total-policies: uint }
)

;; Purpose assessment records
(define-map purpose-assessments
  { policy-id: uint, assessment-id: uint }
  {
    assessor: principal,
    clarity-score: uint,
    progress-indicators: (list 5 uint),
    narrative-summary: (string-ascii 1000),
    timestamp: uint,
    verification-hash: (buff 32)
  }
)

;; Oracle configuration
(define-map oracle-config
  { key: (string-ascii 50) }
  { value: uint }
)

;; Premium calculation factors
(define-map premium-factors
  { factor-type: (string-ascii 50) }
  { multiplier: uint, base-rate: uint }
)

;; Private Functions

;; Calculate premium based on coverage amount and risk factors
(define-private (calculate-premium (coverage-amount uint) (duration-days uint) (risk-level uint))
  (let (
    (base-rate (default-to u100 (get base-rate (map-get? premium-factors { factor-type: "base" }))))
    (risk-multiplier (+ u100 (* risk-level u25)))
    (duration-factor (if (> duration-days u365) u120 u100))
  )
    (/ (* (* coverage-amount base-rate) (* risk-multiplier duration-factor)) u1000000)
  )
)

;; Validate policy parameters
(define-private (validate-policy-params (purpose-desc (string-ascii 500)) (coverage uint) (duration uint))
  (and 
    (> (len purpose-desc) u10)
    (>= coverage u1000)
    (<= coverage u10000000)
    (>= duration u30)
    (<= duration u1095)
  )
)

;; Update user policy list
(define-private (add-policy-to-user (owner principal) (policy-id uint))
  (let (
    (current-data (default-to { active-policies: (list), total-policies: u0 } 
                               (map-get? user-policies { owner: owner })))
    (updated-list (unwrap! (as-max-len? 
                           (append (get active-policies current-data) policy-id) u10) 
                          false))
  )
    (map-set user-policies 
      { owner: owner }
      {
        active-policies: updated-list,
        total-policies: (+ (get total-policies current-data) u1)
      }
    )
  )
)

;; Calculate progress score based on multiple factors
(define-private (calculate-progress-score (clarity-level uint) (duration-active uint) (assessments-count uint))
  (let (
    (clarity-weight (* clarity-level u25))
    (duration-weight (if (> (* duration-active u2) u50) u50 (* duration-active u2)))
    (assessment-weight (if (> (* assessments-count u10) u25) u25 (* assessments-count u10)))
    (total-score (+ clarity-weight duration-weight assessment-weight))
  )
    (if (> total-score u100) u100 total-score)
  )
)

;; Public Functions

;; Create a new purpose discovery policy
(define-public (create-policy 
    (purpose-description (string-ascii 500))
    (coverage-amount uint)
    (duration-days uint))
  (let (
    (policy-id (var-get next-policy-id))
    (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND))
    (expires-at (+ current-time (* duration-days u86400)))
    (premium (calculate-premium coverage-amount duration-days u3))
  )
    ;; Validate inputs
    (asserts! (validate-policy-params purpose-description coverage-amount duration-days) ERR_INVALID_POLICY)
    (asserts! (var-get oracle-active) ERR_UNAUTHORIZED)
    
    ;; Check if user can afford premium (simplified check)
    (asserts! (>= (stx-get-balance tx-sender) premium) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer premium to contract
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    ;; Create policy record
    (map-set policies
      { policy-id: policy-id }
      {
        owner: tx-sender,
        purpose-description: purpose-description,
        coverage-amount: coverage-amount,
        premium-amount: premium,
        duration-days: duration-days,
        created-at: current-time,
        expires-at: expires-at,
        status: POLICY_ACTIVE,
        clarity-level: CLARITY_SEARCHING,
        progress-score: u0,
        last-assessment: current-time
      }
    )
    
    ;; Update user policies
    (asserts! (add-policy-to-user tx-sender policy-id) ERR_INVALID_POLICY)
    
    ;; Update contract state
    (var-set next-policy-id (+ policy-id u1))
    (var-set total-policies (+ (var-get total-policies) u1))
    (var-set total-premiums (+ (var-get total-premiums) premium))
    
    (ok policy-id)
  )
)

;; Submit purpose assessment for a policy
(define-public (submit-assessment
    (policy-id uint)
    (clarity-score uint)
    (progress-indicators (list 5 uint))
    (narrative-summary (string-ascii 1000)))
  (let (
    (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) ERR_NOT_FOUND))
    (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND))
    (assessment-id current-time)
  )
    ;; Validate policy is active and not expired
    (asserts! (is-eq (get status policy-data) POLICY_ACTIVE) ERR_INVALID_POLICY)
    (asserts! (< current-time (get expires-at policy-data)) ERR_POLICY_EXPIRED)
    
    ;; Validate assessment parameters
    (asserts! (<= clarity-score u100) ERR_INVALID_POLICY)
    (asserts! (> (len narrative-summary) u20) ERR_INVALID_POLICY)
    
    ;; Create assessment record
    (map-set purpose-assessments
      { policy-id: policy-id, assessment-id: assessment-id }
      {
        assessor: tx-sender,
        clarity-score: clarity-score,
        progress-indicators: progress-indicators,
        narrative-summary: narrative-summary,
        timestamp: current-time,
        verification-hash: (keccak256 (concat (concat (unwrap-panic (to-consensus-buff? policy-id)) 
                                                      (unwrap-panic (to-consensus-buff? clarity-score)))
                                              (unwrap-panic (to-consensus-buff? current-time))))
      }
    )
    
    ;; Update policy with new assessment data
    (let (
      (new-clarity-level (if (>= clarity-score u80)
        CLARITY_ACTUALIZED
        (if (>= clarity-score u60)
          CLARITY_DEFINED
          (if (>= clarity-score u40)
            CLARITY_EMERGING
            (if (>= clarity-score u20)
              CLARITY_SEARCHING
              CLARITY_UNKNOWN
            )
          )
        )
      ))
      (duration-active (/ (- current-time (get created-at policy-data)) u86400))
      (new-progress-score (calculate-progress-score new-clarity-level duration-active u1))
    )
      (map-set policies
        { policy-id: policy-id }
        (merge policy-data {
          clarity-level: new-clarity-level,
          progress-score: new-progress-score,
          last-assessment: current-time
        })
      )
    )
    
    (ok assessment-id)
  )
)

;; Read-only Functions

;; Get policy details
(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

;; Get user policies
(define-read-only (get-user-policies (owner principal))
  (map-get? user-policies { owner: owner })
)

;; Get assessment details
(define-read-only (get-assessment (policy-id uint) (assessment-id uint))
  (map-get? purpose-assessments { policy-id: policy-id, assessment-id: assessment-id })
)

;; Check policy eligibility for claims
(define-read-only (check-claim-eligibility (policy-id uint))
  (match (map-get? policies { policy-id: policy-id })
    policy-data 
    (let (
      (current-time (default-to u0 (get-stacks-block-info? time (- stacks-block-height u1))))
      (policy-age (/ (- current-time (get created-at policy-data)) u86400))
      (progress-threshold u20)
    )
      (ok {
        eligible: (and 
          (is-eq (get status policy-data) POLICY_ACTIVE)
          (> policy-age u90)
          (< (get progress-score policy-data) progress-threshold)
        ),
        reason: (if (< (get progress-score policy-data) progress-threshold)
          "Insufficient purpose discovery progress"
          "Policy requirements not met"
        ),
        coverage-amount: (get coverage-amount policy-data)
      })
    )
    ERR_NOT_FOUND
  )
)

;; Admin function to update oracle configuration
(define-public (update-oracle-config (key (string-ascii 50)) (value uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set oracle-config { key: key } { value: value })
    (ok true)
  )
)

;; Admin function to toggle oracle status
(define-public (toggle-oracle-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set oracle-active (not (var-get oracle-active)))
    (ok (var-get oracle-active))
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-policies: (var-get total-policies),
    total-premiums: (var-get total-premiums),
    next-policy-id: (var-get next-policy-id),
    oracle-active: (var-get oracle-active)
  }
)

