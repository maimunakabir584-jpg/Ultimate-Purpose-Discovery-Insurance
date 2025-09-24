;; Existential Crisis Monitor
;; Automated crisis detection algorithms and meaning preservation monitoring system
;; Provides real-time risk assessment for existential amplification events

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_DATA (err u400))
(define-constant ERR_CRISIS_ACTIVE (err u409))
(define-constant ERR_MONITORING_DISABLED (err u503))

;; Crisis severity levels
(define-constant CRISIS_NONE u0)
(define-constant CRISIS_MILD u1)
(define-constant CRISIS_MODERATE u2)
(define-constant CRISIS_SEVERE u3)
(define-constant CRISIS_CRITICAL u4)

;; Monitoring status constants
(define-constant MONITOR_ACTIVE u1)
(define-constant MONITOR_PAUSED u2)
(define-constant MONITOR_ALERT u3)

;; Risk factor thresholds
(define-constant MEANING_VOID_THRESHOLD u70)
(define-constant PURPOSE_DRIFT_THRESHOLD u60)
(define-constant EXISTENTIAL_FATIGUE_THRESHOLD u80)

;; Data Variables
(define-data-var monitoring-enabled bool true)
(define-data-var total-monitored-users uint u0)
(define-data-var crisis-alert-count uint u0)
(define-data-var last-global-assessment uint u0)
(define-data-var crisis-prevention-score uint u75)

;; Data Maps

;; User existential state tracking
(define-map user-crisis-states
  { user: principal }
  {
    current-level: uint,
    meaning-coherence-score: uint,
    purpose-clarity-index: uint,
    existential-stability: uint,
    last-crisis-event: uint,
    crisis-frequency: uint,
    monitoring-start: uint,
    total-assessments: uint,
    intervention-count: uint
  }
)

;; Crisis event records
(define-map crisis-events
  { user: principal, event-id: uint }
  {
    severity: uint,
    trigger-factors: (list 10 uint),
    symptoms: (list 5 (string-ascii 100)),
    detected-at: uint,
    resolution-time: uint,
    intervention-type: (string-ascii 200),
    recovery-score: uint,
    notes: (string-ascii 1000)
  }
)

;; Meaning preservation metrics
(define-map meaning-metrics
  { user: principal, metric-date: uint }
  {
    coherence-level: uint,
    stability-index: uint,
    drift-indicators: (list 8 uint),
    preservation-score: uint,
    risk-factors: (list 6 uint),
    protective-factors: (list 6 uint)
  }
)

;; Crisis intervention protocols
(define-map intervention-protocols
  { protocol-id: uint }
  {
    name: (string-ascii 100),
    severity-target: uint,
    intervention-steps: (list 10 (string-ascii 200)),
    success-rate: uint,
    average-resolution-time: uint,
    enabled: bool
  }
)

;; Monitoring configurations
(define-map monitoring-config
  { setting: (string-ascii 50) }
  { value: uint, enabled: bool }
)

;; Private Functions

;; Calculate crisis risk score based on multiple factors
(define-private (calculate-crisis-risk 
    (meaning-coherence uint) 
    (purpose-clarity uint) 
    (existential-stability uint)
    (recent-events uint))
  (let (
    (coherence-risk (if (< meaning-coherence MEANING_VOID_THRESHOLD) u30 u0))
    (clarity-risk (if (< purpose-clarity PURPOSE_DRIFT_THRESHOLD) u25 u0))
    (stability-risk (if (< existential-stability u50) u20 u0))
    (event-risk (if (> (* recent-events u15) u25) u25 (* recent-events u15)))
    (total-risk (+ coherence-risk clarity-risk stability-risk event-risk))
  )
    (if (> total-risk u100) u100 total-risk)
  )
)

;; Determine crisis level from risk score
(define-private (risk-to-crisis-level (risk-score uint))
  (if (>= risk-score u80) 
    CRISIS_CRITICAL
    (if (>= risk-score u60)
      CRISIS_SEVERE
      (if (>= risk-score u40)
        CRISIS_MODERATE
        (if (>= risk-score u20)
          CRISIS_MILD
          CRISIS_NONE
        )
      )
    )
  )
)

;; Generate intervention recommendation
(define-private (recommend-intervention (crisis-level uint) (user-history uint))
  (if (is-eq crisis-level CRISIS_CRITICAL)
    "Immediate professional intervention required"
    (if (is-eq crisis-level CRISIS_SEVERE)
      "Structured meaning reconstruction protocol"
      (if (is-eq crisis-level CRISIS_MODERATE)
        "Purpose clarification exercises and monitoring"
        (if (is-eq crisis-level CRISIS_MILD)
          "Preventive meaning maintenance activities"
          "Continue regular existential wellness practices"
        )
      )
    )
  )
)

;; Update global crisis statistics
(define-private (update-crisis-stats (new-crisis-detected bool))
  (if new-crisis-detected
    (var-set crisis-alert-count (+ (var-get crisis-alert-count) u1))
    true
  )
)

;; Validate assessment data
(define-private (validate-assessment-data 
    (meaning-coherence uint) 
    (purpose-clarity uint) 
    (existential-stability uint))
  (and 
    (<= meaning-coherence u100)
    (<= purpose-clarity u100)
    (<= existential-stability u100)
    (> meaning-coherence u0)
    (> purpose-clarity u0)
    (> existential-stability u0)
  )
)

;; Public Functions

;; Initialize crisis monitoring for a user
(define-public (initialize-monitoring 
    (user principal)
    (initial-meaning-coherence uint)
    (initial-purpose-clarity uint)
    (initial-existential-stability uint))
  (let (
    (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND))
  )
    ;; Check if monitoring is enabled
    (asserts! (var-get monitoring-enabled) ERR_MONITORING_DISABLED)
    
    ;; Validate input data
    (asserts! (validate-assessment-data initial-meaning-coherence initial-purpose-clarity initial-existential-stability) ERR_INVALID_DATA)
    
    ;; Check if user already has monitoring
    (asserts! (is-none (map-get? user-crisis-states { user: user })) ERR_CRISIS_ACTIVE)
    
    ;; Calculate initial crisis level
    (let (
      (initial-risk (calculate-crisis-risk initial-meaning-coherence initial-purpose-clarity initial-existential-stability u0))
      (initial-crisis-level (risk-to-crisis-level initial-risk))
    )
      ;; Create user crisis state record
      (map-set user-crisis-states
        { user: user }
        {
          current-level: initial-crisis-level,
          meaning-coherence-score: initial-meaning-coherence,
          purpose-clarity-index: initial-purpose-clarity,
          existential-stability: initial-existential-stability,
          last-crisis-event: u0,
          crisis-frequency: u0,
          monitoring-start: current-time,
          total-assessments: u1,
          intervention-count: u0
        }
      )
      
      ;; Create initial meaning metrics
      (map-set meaning-metrics
        { user: user, metric-date: current-time }
        {
          coherence-level: initial-meaning-coherence,
          stability-index: initial-existential-stability,
          drift-indicators: (list u0 u0 u0 u0 u0 u0 u0 u0),
          preservation-score: (/ (+ initial-meaning-coherence initial-existential-stability) u2),
          risk-factors: (list u0 u0 u0 u0 u0 u0),
          protective-factors: (list u0 u0 u0 u0 u0 u0)
        }
      )
      
      ;; Update global stats
      (var-set total-monitored-users (+ (var-get total-monitored-users) u1))
      
      (ok { 
        monitoring-initialized: true, 
        initial-crisis-level: initial-crisis-level,
        risk-score: initial-risk 
      })
    )
  )
)

;; Submit crisis assessment update
(define-public (submit-crisis-assessment
    (user principal)
    (meaning-coherence uint)
    (purpose-clarity uint)
    (existential-stability uint)
    (recent-triggers (list 5 uint))
    (symptom-notes (string-ascii 500)))
  (let (
    (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND))
    (user-state (unwrap! (map-get? user-crisis-states { user: user }) ERR_NOT_FOUND))
  )
    ;; Validate assessment data
    (asserts! (validate-assessment-data meaning-coherence purpose-clarity existential-stability) ERR_INVALID_DATA)
    (asserts! (var-get monitoring-enabled) ERR_MONITORING_DISABLED)
    
    ;; Calculate new risk level
    (let (
      (trigger-count (len recent-triggers))
      (new-risk-score (calculate-crisis-risk meaning-coherence purpose-clarity existential-stability trigger-count))
      (new-crisis-level (risk-to-crisis-level new-risk-score))
      (crisis-escalated (> new-crisis-level (get current-level user-state)))
      (event-id current-time)
    )
      ;; Update user crisis state
      (map-set user-crisis-states
        { user: user }
        (merge user-state {
          current-level: new-crisis-level,
          meaning-coherence-score: meaning-coherence,
          purpose-clarity-index: purpose-clarity,
          existential-stability: existential-stability,
          last-crisis-event: (if crisis-escalated current-time (get last-crisis-event user-state)),
          crisis-frequency: (if crisis-escalated (+ (get crisis-frequency user-state) u1) (get crisis-frequency user-state)),
          total-assessments: (+ (get total-assessments user-state) u1)
        })
      )
      
      ;; Create crisis event record if escalated
      (if crisis-escalated
        (map-set crisis-events
          { user: user, event-id: event-id }
          {
            severity: new-crisis-level,
            trigger-factors: recent-triggers,
            symptoms: (list),
            detected-at: current-time,
            resolution-time: u0,
            intervention-type: (recommend-intervention new-crisis-level (get total-assessments user-state)),
            recovery-score: u0,
            notes: symptom-notes
          }
        )
        true
      )
      
      ;; Update meaning metrics
      (map-set meaning-metrics
        { user: user, metric-date: current-time }
        {
          coherence-level: meaning-coherence,
          stability-index: existential-stability,
          drift-indicators: recent-triggers,
          preservation-score: (/ (+ meaning-coherence existential-stability purpose-clarity) u3),
          risk-factors: recent-triggers,
          protective-factors: (list u0 u0 u0 u0 u0 u0)
        }
      )
      
      ;; Update global stats
      (update-crisis-stats crisis-escalated)
      (var-set last-global-assessment current-time)
      
      (ok {
        crisis-level: new-crisis-level,
        risk-score: new-risk-score,
        escalated: crisis-escalated,
        intervention-recommendation: (recommend-intervention new-crisis-level (get total-assessments user-state))
      })
    )
  )
)

;; Read-only Functions

;; Get user crisis state
(define-read-only (get-crisis-state (user principal))
  (map-get? user-crisis-states { user: user })
)

;; Get crisis event details
(define-read-only (get-crisis-event (user principal) (event-id uint))
  (map-get? crisis-events { user: user, event-id: event-id })
)

;; Get meaning preservation metrics
(define-read-only (get-meaning-metrics (user principal) (metric-date uint))
  (map-get? meaning-metrics { user: user, metric-date: metric-date })
)

;; Check if user needs intervention
(define-read-only (needs-intervention (user principal))
  (match (map-get? user-crisis-states { user: user })
    user-state 
    (ok {
      needs-intervention: (>= (get current-level user-state) CRISIS_MODERATE),
      crisis-level: (get current-level user-state),
      recommendation: (recommend-intervention (get current-level user-state) (get total-assessments user-state)),
      urgency: (if (>= (get current-level user-state) CRISIS_CRITICAL)
        "IMMEDIATE"
        (if (>= (get current-level user-state) CRISIS_SEVERE)
          "HIGH"
          (if (>= (get current-level user-state) CRISIS_MODERATE)
            "MEDIUM"
            "LOW"
          )
        )
      )
    })
    ERR_NOT_FOUND
  )
)

;; Calculate overall risk assessment for user
(define-read-only (assess-overall-risk (user principal))
  (match (map-get? user-crisis-states { user: user })
    user-state
    (let (
      (current-risk (calculate-crisis-risk 
        (get meaning-coherence-score user-state)
        (get purpose-clarity-index user-state)
        (get existential-stability user-state)
        (get crisis-frequency user-state)
      ))
      (historical-factor (let ((calc (/ (get total-assessments user-state) u10))) (if (> calc u10) u10 calc)))
      (adjusted-risk (+ current-risk historical-factor))
    )
      (ok {
        current-risk-score: current-risk,
        historical-factor: historical-factor,
        overall-risk: (if (> adjusted-risk u100) u100 adjusted-risk),
        monitoring-duration: (get total-assessments user-state),
        last-assessment: (get total-assessments user-state)
      })
    )
    ERR_NOT_FOUND
  )
)

;; Admin function to toggle monitoring
(define-public (toggle-monitoring)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set monitoring-enabled (not (var-get monitoring-enabled)))
    (ok (var-get monitoring-enabled))
  )
)

;; Get global monitoring statistics
(define-read-only (get-monitoring-stats)
  {
    total-monitored-users: (var-get total-monitored-users),
    crisis-alert-count: (var-get crisis-alert-count),
    last-global-assessment: (var-get last-global-assessment),
    monitoring-enabled: (var-get monitoring-enabled),
    crisis-prevention-score: (var-get crisis-prevention-score)
  }
)

