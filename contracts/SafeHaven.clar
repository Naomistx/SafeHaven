;; SafeHaven - Decentralized Multi-Asset Insurance Protocol
;; A smart contract system for creating and managing insurance policies for various digital assets

;; Define SIP-010 trait for token transfers
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

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
(define-constant err-unsupported-asset (err u111))
(define-constant err-invalid-asset-address (err u112))
(define-constant err-asset-transfer-failed (err u113))
(define-constant err-asset-already-exists (err u114))

;; Asset type constants
(define-constant asset-type-stx "STX")
(define-constant asset-type-sip10 "SIP10")

;; Premium calculation constants
(define-constant base-premium-rate u100) ;; 1% base rate (in basis points)
(define-constant risk-multiplier u50) ;; Additional risk factor (0.5% per risk unit)
(define-constant min-premium u1000000) ;; Minimum premium (1 STX in microSTX)

;; Data Variables
(define-data-var policy-counter uint u0)
(define-data-var total-premiums uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var protocol-fee-rate uint u500) ;; 5% in basis points

;; Supported assets mapping (asset-type -> enabled)
(define-map supported-assets (string-ascii 10) bool)

;; Asset contracts mapping (for SIP-10 tokens)
(define-map asset-contracts principal 
  {
    symbol: (string-ascii 10),
    decimals: uint,
    enabled: bool
  })

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
    policy-type: (string-ascii 50),
    asset-type: (string-ascii 10),
    asset-contract: (optional principal)
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

;; Initialize supported assets
(map-set supported-assets asset-type-stx true)
(map-set supported-assets asset-type-sip10 true)

;; Private function to calculate premium based on coverage amount and duration
(define-private (calculate-premium (coverage-amount uint) (duration-blocks uint))
  (let (
    ;; Calculate base premium as percentage of coverage amount
    (base-premium (/ (* coverage-amount base-premium-rate) u10000))
    ;; Calculate duration factor (longer duration = higher premium)
    (duration-factor (+ u10000 (/ (* duration-blocks u10) u144))) ;; ~0.1% per day
    ;; Apply duration multiplier
    (premium-with-duration (/ (* base-premium duration-factor) u10000))
    ;; Ensure minimum premium
    (final-premium (if (> premium-with-duration min-premium) 
                      premium-with-duration 
                      min-premium))
  )
    final-premium))

;; Private function to validate principal address
(define-private (is-valid-principal (addr principal))
  (and 
    (not (is-eq addr tx-sender))
    (not (is-eq addr contract-owner))
    (not (is-eq addr (as-contract tx-sender)))))

;; Private function to safely set asset data
(define-private (safe-set-asset (asset-contract principal) (asset-data {symbol: (string-ascii 10), decimals: uint, enabled: bool}))
  (if (is-valid-principal asset-contract)
    (begin
      (map-set asset-contracts asset-contract asset-data)
      true)
    false))

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

(define-private (validate-asset-type (asset-type (string-ascii 10)))
  (default-to false (map-get? supported-assets asset-type)))

(define-private (validate-asset-contract (asset-contract principal))
  (match (map-get? asset-contracts asset-contract)
    asset-data (get enabled asset-data)
    false))

(define-private (transfer-stx (amount uint) (sender principal) (recipient principal))
  (stx-transfer? amount sender recipient))

;; Public Functions

;; Create a new insurance policy for STX
(define-public (create-stx-policy (coverage-amount uint) (duration uint) (policy-type (string-ascii 50)))
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
    (asserts! (validate-asset-type asset-type-stx) err-unsupported-asset)
    
    ;; Transfer premium in STX
    (try! (transfer-stx premium tx-sender (as-contract tx-sender)))
    
    (map-set policies policy-id {
      owner: tx-sender,
      coverage-amount: coverage-amount,
      premium-paid: premium,
      start-block: start-block,
      end-block: end-block,
      is-active: true,
      claim-submitted: false,
      claim-approved: false,
      policy-type: policy-type,
      asset-type: asset-type-stx,
      asset-contract: none
    })
    
    (add-policy-to-user tx-sender policy-id)
    (var-set policy-counter policy-id)
    (var-set total-premiums (+ (var-get total-premiums) premium))
    
    (ok policy-id)))

;; Create a new insurance policy for SIP-10 tokens
(define-public (create-sip10-policy (coverage-amount uint) (duration uint) (policy-type (string-ascii 50)) (token-contract <sip-010-trait>))
  (let (
    (policy-id (+ (var-get policy-counter) u1))
    (premium (calculate-premium coverage-amount duration))
    (start-block stacks-block-height)
    (end-block (+ stacks-block-height duration))
    (asset-contract-principal (contract-of token-contract))
  )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> duration u143) err-invalid-duration) ;; Minimum 1 day (144 blocks)
    (asserts! (validate-policy-type policy-type) err-invalid-amount)
    (asserts! (validate-asset-type asset-type-sip10) err-unsupported-asset)
    (asserts! (match (map-get? asset-contracts asset-contract-principal)
                asset-data (get enabled asset-data)
                false) err-unsupported-asset)
    
    ;; Transfer premium in SIP-10 token
    (try! (contract-call? token-contract transfer premium tx-sender (as-contract tx-sender) none))
    
    (map-set policies policy-id {
      owner: tx-sender,
      coverage-amount: coverage-amount,
      premium-paid: premium,
      start-block: start-block,
      end-block: end-block,
      is-active: true,
      claim-submitted: false,
      claim-approved: false,
      policy-type: policy-type,
      asset-type: asset-type-sip10,
      asset-contract: (some asset-contract-principal)
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

;; Approve a claim for STX policy (owner only)
(define-public (approve-stx-claim (policy-id uint))
  (let (
    (policy-data (unwrap! (map-get? policies policy-id) err-not-found))
    (claim-data (unwrap! (map-get? claims policy-id) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get claim-submitted policy-data) err-not-found)
    (asserts! (not (get claim-approved policy-data)) err-already-claimed)
    (asserts! (is-eq (get asset-type policy-data) asset-type-stx) err-unsupported-asset)
    
    (try! (as-contract (transfer-stx (get claim-amount claim-data) tx-sender (get claimant claim-data))))
    
    (map-set policies policy-id 
      (merge policy-data { claim-approved: true, is-active: false }))
    
    (map-set claims policy-id 
      (merge claim-data { status: "approved" }))
    
    (var-set total-claims-paid (+ (var-get total-claims-paid) (get claim-amount claim-data)))
    
    (ok true)))

;; Approve a claim for SIP-10 policy (owner only)
(define-public (approve-sip10-claim (policy-id uint) (token-contract <sip-010-trait>))
  (let (
    (policy-data (unwrap! (map-get? policies policy-id) err-not-found))
    (claim-data (unwrap! (map-get? claims policy-id) err-not-found))
    (asset-contract-principal (contract-of token-contract))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get claim-submitted policy-data) err-not-found)
    (asserts! (not (get claim-approved policy-data)) err-already-claimed)
    (asserts! (is-eq (get asset-type policy-data) asset-type-sip10) err-unsupported-asset)
    (asserts! (is-eq (some asset-contract-principal) (get asset-contract policy-data)) err-invalid-asset-address)
    
    (try! (as-contract (contract-call? token-contract transfer (get claim-amount claim-data) tx-sender (get claimant claim-data) none)))
    
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

;; Add a new SIP-10 asset (owner only)
(define-public (add-sip10-asset (asset-contract principal) (symbol (string-ascii 10)) (decimals uint))
  (let (
    (validated-symbol (if (and (> (len symbol) u0) (<= (len symbol) u10)) symbol "INVALID"))
    (validated-decimals (if (<= decimals u18) decimals u0))
    (new-asset-data {
      symbol: validated-symbol,
      decimals: validated-decimals,
      enabled: true
    })
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len symbol) u0) err-invalid-amount)
    (asserts! (<= (len symbol) u10) err-invalid-amount)
    (asserts! (<= decimals u18) err-invalid-amount)
    (asserts! (not (is-eq validated-symbol "INVALID")) err-invalid-amount)
    (asserts! (not (is-eq validated-decimals u0)) err-invalid-amount)
    (asserts! (is-valid-principal asset-contract) err-invalid-asset-address)
    
    ;; Check if asset already exists to prevent overwriting
    (asserts! (is-none (map-get? asset-contracts asset-contract)) err-asset-already-exists)
    
    ;; Safe map-set operation with validated data and principal
    (asserts! (safe-set-asset asset-contract new-asset-data) err-asset-transfer-failed)
    (ok true)))

;; Remove a SIP-10 asset (owner only)
(define-public (remove-sip10-asset (asset-contract principal))
  (let (
    (existing-asset-data (unwrap! (map-get? asset-contracts asset-contract) err-not-found))
    (updated-asset-data {
      symbol: (get symbol existing-asset-data),
      decimals: (get decimals existing-asset-data), 
      enabled: false
    })
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get enabled existing-asset-data) err-unsupported-asset)
    (asserts! (is-valid-principal asset-contract) err-invalid-asset-address)
    
    ;; Safely update with existing data structure
    (asserts! (safe-set-asset asset-contract updated-asset-data) err-asset-transfer-failed)
    (ok true)))

;; Update SIP-10 asset details (owner only)
(define-public (update-sip10-asset (asset-contract principal) (symbol (string-ascii 10)) (decimals uint) (enabled bool))
  (let (
    (existing-asset-data (unwrap! (map-get? asset-contracts asset-contract) err-not-found))
    (validated-symbol (if (and (> (len symbol) u0) (<= (len symbol) u10)) symbol (get symbol existing-asset-data)))
    (validated-decimals (if (<= decimals u18) decimals (get decimals existing-asset-data)))
    (new-asset-data {
      symbol: validated-symbol,
      decimals: validated-decimals,
      enabled: enabled
    })
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len symbol) u0) err-invalid-amount)
    (asserts! (<= (len symbol) u10) err-invalid-amount)
    (asserts! (<= decimals u18) err-invalid-amount)
    (asserts! (is-valid-principal asset-contract) err-invalid-asset-address)
    
    ;; Safely update with validated data
    (asserts! (safe-set-asset asset-contract new-asset-data) err-asset-transfer-failed)
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

;; Get contract balance (STX only)
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))

;; Check if asset type is supported
(define-read-only (is-asset-supported (asset-type (string-ascii 10)))
  (validate-asset-type asset-type))

;; Get asset contract details
(define-read-only (get-asset-contract (asset-contract principal))
  (map-get? asset-contracts asset-contract))

;; Check if SIP-10 asset is supported
(define-read-only (is-sip10-asset-supported (asset-contract principal))
  (match (map-get? asset-contracts asset-contract)
    asset-data (get enabled asset-data)
    false))

;; Admin function to update protocol fee rate
(define-public (set-protocol-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set protocol-fee-rate new-rate)
    (ok true)))

;; Emergency withdraw function for STX (owner only)
(define-public (emergency-withdraw-stx (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (as-contract (stx-transfer? amount tx-sender contract-owner))))

;; Emergency withdraw function for SIP-10 tokens (owner only)
(define-public (emergency-withdraw-sip10 (amount uint) (token-contract <sip-010-trait>))
  (let ((asset-contract-principal (contract-of token-contract)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (match (map-get? asset-contracts asset-contract-principal)
                asset-data (get enabled asset-data)
                false) err-unsupported-asset)
    (as-contract (contract-call? token-contract transfer amount tx-sender contract-owner none))))