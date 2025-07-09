;; SafeHaven - Decentralized Insurance Protocol for Digital Assets
;; A smart contract system for creating and managing insurance policies

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-policy-expired (err u104))
(define-constant err-policy-active (err u105))
(define-constant err-insufficient-premium (err u106))
(define-constant err-claim-denied (err u107))
(define-constant err-already-claimed (err u108))
(define-constant err-invalid-duration (err u109))
(define-constant err-policy-not-active (err u110))

;; Data Variables
(define-data-var policy-counter uint u0)
(define-data-var total-premiums uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var protocol-fee-rate uint u500) ;; 5% in basis points

;; Data Maps
(define-map policies 
  uint 
  {
    owner: principal,
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    claim-submitted: bool,
    claim-approved: bool,
    policy-type: (string-ascii 50)
  })

(define-map user-policies principal (list 20 uint))
(define-map claims 
  uint 
  {
    policy-id: uint,
    claimant: principal,
    claim-amount: uint,
    claim-reason: (string-ascii 200),
    submitted-at: uint,
    status: (string-ascii 20)
  })

;; Private Functions
(define-private (calculate-premium (coverage-amount uint) (duration uint))
  (let ((base-rate u100)) ;; 1% base rate
    (/ (* coverage-amount base-rate duration) u10000)))

(define-private (is-policy-valid (policy-id uint))
  (match (map-get? policies policy-id)
    policy-data 
      (and 
        (get is-active policy-data)
        (>= stacks-block-height (get start-block policy-data))
        (<= stacks-block-height (get end-block policy-data)))
    false))

(define-private (add-policy-to-user (user principal) (policy-id uint))
  (let ((current-policies (default-to (list) (map-get? user-policies user))))
    (map-set user-policies user (unwrap-panic (as-max-len? (append current-policies policy-id) u20)))))

(define-private (validate-policy-type (policy-type (string-ascii 50)))
  (and 
    (> (len policy-type) u0)
    (<= (len policy-type) u50)))

(define-private (validate-claim-reason (claim-reason (string-ascii 200)))
  (and 
    (> (len claim-reason) u0)
    (<= (len claim-reason) u200)))

;; Public Functions

;; Create a new insurance policy
(define-public (create-policy (coverage-amount uint) (duration uint) (policy-type (string-ascii 50)))
  (let (
    (policy-id (+ (var-get policy-counter) u1))
    (premium (calculate-premium coverage-amount duration))
    (start-block stacks-block-height)
    (end-block (+ stacks-block-height duration))
  )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> duration u143) err-invalid-duration) ;; Minimum 1 day (144 blocks)
    (asserts! (validate-policy-type policy-type) err-invalid-amount)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set policies policy-id {
      owner: tx-sender,
      coverage-amount: coverage-amount,
      premium-paid: premium,
      start-block: start-block,
      end-block: end-block,
      is-active: true,
      claim-submitted: false,
      claim-approved: false,
      policy-type: policy-type
    })
    
    (add-policy-to-user tx-sender policy-id)
    (var-set policy-counter policy-id)
    (var-set total-premiums (+ (var-get total-premiums) premium))
    
    (ok policy-id)))

;; Submit a claim for an existing policy
(define-public (submit-claim (policy-id uint) (claim-amount uint) (claim-reason (string-ascii 200)))
  (let ((policy-data (unwrap! (map-get? policies policy-id) err-not-found)))
    (asserts! (is-eq tx-sender (get owner policy-data)) err-unauthorized)
    (asserts! (is-policy-valid policy-id) err-policy-not-active)
    (asserts! (not (get claim-submitted policy-data)) err-already-claimed)
    (asserts! (> claim-amount u0) err-invalid-amount)
    (asserts! (<= claim-amount (get coverage-amount policy-data)) err-invalid-amount)
    (asserts! (validate-claim-reason claim-reason) err-invalid-amount)
    
    (map-set policies policy-id 
      (merge policy-data { claim-submitted: true }))
    
    (map-set claims policy-id {
      policy-id: policy-id,
      claimant: tx-sender,
      claim-amount: claim-amount,
      claim-reason: claim-reason,
      submitted-at: stacks-block-height,
      status: "pending"
    })
    
    (ok true)))

;; Approve a claim (owner only)
(define-public (approve-claim (policy-id uint))
  (let (
    (policy-data (unwrap! (map-get? policies policy-id) err-not-found))
    (claim-data (unwrap! (map-get? claims policy-id) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get claim-submitted policy-data) err-not-found)
    (asserts! (not (get claim-approved policy-data)) err-already-claimed)
    
    (try! (as-contract (stx-transfer? (get claim-amount claim-data) tx-sender (get claimant claim-data))))
    
    (map-set policies policy-id 
      (merge policy-data { claim-approved: true, is-active: false }))
    
    (map-set claims policy-id 
      (merge claim-data { status: "approved" }))
    
    (var-set total-claims-paid (+ (var-get total-claims-paid) (get claim-amount claim-data)))
    
    (ok true)))

;; Deny a claim (owner only)
(define-public (deny-claim (policy-id uint))
  (let (
    (policy-data (unwrap! (map-get? policies policy-id) err-not-found))
    (claim-data (unwrap! (map-get? claims policy-id) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get claim-submitted policy-data) err-not-found)
    (asserts! (not (get claim-approved policy-data)) err-already-claimed)
    
    (map-set claims policy-id 
      (merge claim-data { status: "denied" }))
    
    (ok true)))

;; Cancel a policy (policy owner only)
(define-public (cancel-policy (policy-id uint))
  (let ((policy-data (unwrap! (map-get? policies policy-id) err-not-found)))
    (asserts! (is-eq tx-sender (get owner policy-data)) err-unauthorized)
    (asserts! (get is-active policy-data) err-policy-not-active)
    (asserts! (not (get claim-submitted policy-data)) err-already-claimed)
    
    (map-set policies policy-id 
      (merge policy-data { is-active: false }))
    
    (ok true)))

;; Read-only functions

;; Get policy details
(define-read-only (get-policy (policy-id uint))
  (map-get? policies policy-id))

;; Get user policies
(define-read-only (get-user-policies (user principal))
  (default-to (list) (map-get? user-policies user)))

;; Get claim details
(define-read-only (get-claim (policy-id uint))
  (map-get? claims policy-id))

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-policies: (var-get policy-counter),
    total-premiums: (var-get total-premiums),
    total-claims-paid: (var-get total-claims-paid),
    protocol-fee-rate: (var-get protocol-fee-rate)
  })

;; Check if policy is currently active
(define-read-only (is-policy-active (policy-id uint))
  (is-policy-valid policy-id))

;; Get premium calculation for given parameters
(define-read-only (get-premium-quote (coverage-amount uint) (duration uint))
  (calculate-premium coverage-amount duration))

;; Get current block height
(define-read-only (get-current-block)
  stacks-block-height)

;; Get contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))

;; Admin function to update protocol fee rate
(define-public (set-protocol-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set protocol-fee-rate new-rate)
    (ok true)))

;; Emergency withdraw function (owner only)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (as-contract (stx-transfer? amount tx-sender contract-owner))))