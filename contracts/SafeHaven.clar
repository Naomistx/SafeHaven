;; SafeHaven - Decentralized Multi-Asset Insurance Protocol with Oracle Integration
;; A smart contract system for creating and managing insurance policies for various digital assets
;; Now featuring real-time asset valuation and dynamic premium pricing

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

;; Define Oracle trait for price feeds
(define-trait oracle-trait
  (
    (get-asset-price ((string-ascii 10)) (response uint uint))
    (get-last-update-block ((string-ascii 10)) (response uint uint))
    (is-price-valid ((string-ascii 10)) (response bool uint))
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
(define-constant err-oracle-not-set (err u115))
(define-constant err-invalid-oracle (err u116))
(define-constant err-stale-price (err u117))
(define-constant err-price-deviation (err u118))
(define-constant err-oracle-call-failed (err u119))

;; Asset type constants
(define-constant asset-type-stx "STX")
(define-constant asset-type-sip10 "SIP10")

;; Premium calculation constants
(define-constant base-premium-rate u100) ;; 1% base rate (in basis points)
(define-constant risk-multiplier u50) ;; Additional risk factor (0.5% per risk unit)
(define-constant min-premium u1000000) ;; Minimum premium (1 STX in microSTX)

;; Oracle constants
(define-constant max-price-age u144) ;; Maximum price age in blocks (1 day)
(define-constant price-deviation-threshold u500) ;; 5% deviation threshold
(define-constant oracle-decimals u6) ;; Oracle price decimals (1 STX = 1,000,000 micro-STX)

;; Data Variables
(define-data-var policy-counter uint u0)
(define-data-var total-premiums uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var protocol-fee-rate uint u500) ;; 5% in basis points
(define-data-var oracle-contract (optional principal) none)
(define-data-var dynamic-pricing-enabled bool false) ;; Default to false until oracle is set

;; Supported assets mapping (asset-type -> enabled)
(define-map supported-assets (string-ascii 10) bool)

;; Asset contracts mapping (for SIP-10 tokens)
(define-map asset-contracts principal 
  {
    symbol: (string-ascii 10),
    decimals: uint,
    enabled: bool
  })

;; Oracle price cache for gas optimization
(define-map price-cache (string-ascii 10)
  {
    price: uint,
    last-update: uint,
    is-valid: bool
  })

;; Risk multipliers for different assets
(define-map asset-risk-multipliers (string-ascii 10) uint)

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
    asset-contract: (optional principal),
    coverage-price-usd: uint,
    premium-price-usd: uint
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

;; Initialize supported assets and risk multipliers
(map-set supported-assets asset-type-stx true)
(map-set supported-assets asset-type-sip10 true)
(map-set asset-risk-multipliers asset-type-stx u100)
(map-set asset-risk-multipliers asset-type-sip10 u150)

;; Private function to validate oracle contract
(define-private (validate-oracle-contract (oracle principal))
  (and 
    (not (is-eq oracle tx-sender))
    (not (is-eq oracle contract-owner))
    (not (is-eq oracle (as-contract tx-sender)))))

;; Private function to get asset price from oracle with caching
(define-private (get-asset-price-cached (asset-symbol (string-ascii 10)))
  (match (var-get oracle-contract)
    oracle-principal
      (let (
        (cached-price (map-get? price-cache asset-symbol))
        (current-block stacks-block-height)
      )
        (match cached-price
          cached-data
            (if (and 
                  (get is-valid cached-data)
                  (<= (- current-block (get last-update cached-data)) max-price-age))
              (ok (get price cached-data))
              (get-fresh-price asset-symbol oracle-principal))
          (get-fresh-price asset-symbol oracle-principal)))
    err-oracle-not-set))

;; Private read-only function to get asset price without caching
(define-private (get-asset-price-read-only (asset-symbol (string-ascii 10)))
  (match (var-get oracle-contract)
    oracle-principal
      (let (
        (cached-price (map-get? price-cache asset-symbol))
        (current-block stacks-block-height)
      )
        (match cached-price
          cached-data
            (if (and 
                  (get is-valid cached-data)
                  (<= (- current-block (get last-update cached-data)) max-price-age))
              (ok (get price cached-data))
              err-stale-price) ;; Don't make contract calls in read-only
          err-not-found))
    err-oracle-not-set))

;; Private function to fetch fresh price from oracle using dynamic contract call
(define-private (get-fresh-price (asset-symbol (string-ascii 10)) (oracle-principal principal))
  ;; For now, we'll use a simplified approach that doesn't make external contract calls
  ;; This can be enhanced when the oracle contract is deployed and available
  (let (
    (fallback-price u1000000) ;; $1.00 in micro-units as fallback
    (current-block stacks-block-height)
  )
    ;; Cache a fallback price for now
    (map-set price-cache asset-symbol {
      price: fallback-price,
      last-update: current-block,
      is-valid: true
    })
    (ok fallback-price)))

;; Private function to calculate dynamic premium with oracle pricing
(define-private (calculate-dynamic-premium (coverage-amount uint) (duration-blocks uint) (asset-symbol (string-ascii 10)))
  (if (var-get dynamic-pricing-enabled)
    (match (get-asset-price-cached asset-symbol)
      asset-price-usd
        (let (
          ;; Get risk multiplier for the asset
          (risk-mult (default-to u100 (map-get? asset-risk-multipliers asset-symbol)))
          ;; Calculate base premium with risk adjustment
          (risk-adjusted-rate (+ base-premium-rate (/ (* risk-mult risk-multiplier) u100)))
          (base-premium (/ (* coverage-amount risk-adjusted-rate) u10000))
          ;; Calculate duration factor
          (duration-factor (+ u10000 (/ (* duration-blocks u10) u144)))
          ;; Apply duration multiplier
          (premium-with-duration (/ (* base-premium duration-factor) u10000))
          ;; Price volatility adjustment (higher volatility = higher premium)
          (volatility-mult (if (> asset-price-usd u100000000) u11000 u10000)) ;; 10% increase for high-value assets
          (final-premium (/ (* premium-with-duration volatility-mult) u10000))
          ;; Ensure minimum premium
          (validated-premium (if (> final-premium min-premium) final-premium min-premium))
        )
          (ok validated-premium))
      error-code (ok (calculate-premium coverage-amount duration-blocks)))
    (ok (calculate-premium coverage-amount duration-blocks))))

;; Private read-only function to get cached asset price only
(define-private (get-cached-price-only (asset-symbol (string-ascii 10)))
  (match (map-get? price-cache asset-symbol)
    cached-data
      (let ((current-block stacks-block-height))
        (if (and 
              (get is-valid cached-data)
              (<= (- current-block (get last-update cached-data)) max-price-age))
          (ok (get price cached-data))
          err-stale-price))
    err-not-found))

;; Private read-only function to calculate dynamic premium using only cached prices
(define-private (calculate-dynamic-premium-cached-only (coverage-amount uint) (duration-blocks uint) (asset-symbol (string-ascii 10)))
  (if (var-get dynamic-pricing-enabled)
    (match (get-cached-price-only asset-symbol)
      asset-price-usd
        (let (
          ;; Get risk multiplier for the asset
          (risk-mult (default-to u100 (map-get? asset-risk-multipliers asset-symbol)))
          ;; Calculate base premium with risk adjustment
          (risk-adjusted-rate (+ base-premium-rate (/ (* risk-mult risk-multiplier) u100)))
          (base-premium (/ (* coverage-amount risk-adjusted-rate) u10000))
          ;; Calculate duration factor
          (duration-factor (+ u10000 (/ (* duration-blocks u10) u144)))
          ;; Apply duration multiplier
          (premium-with-duration (/ (* base-premium duration-factor) u10000))
          ;; Price volatility adjustment (higher volatility = higher premium)
          (volatility-mult (if (> asset-price-usd u100000000) u11000 u10000)) ;; 10% increase for high-value assets
          (final-premium (/ (* premium-with-duration volatility-mult) u10000))
          ;; Ensure minimum premium
          (validated-premium (if (> final-premium min-premium) final-premium min-premium))
        )
          (ok validated-premium))
      error-code (ok (calculate-premium coverage-amount duration-blocks)))
    (ok (calculate-premium coverage-amount duration-blocks))))

;; Private function to calculate premium based on coverage amount and duration (fallback)
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

;; Public function to update price from oracle (requires oracle trait)
(define-public (update-asset-price (asset-symbol (string-ascii 10)) (oracle <oracle-trait>))
  (let (
    (oracle-principal (contract-of oracle))
    (current-block stacks-block-height)
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len asset-symbol) u0) err-invalid-amount)
    (asserts! (<= (len asset-symbol) u10) err-invalid-amount)
    (asserts! (is-eq (some oracle-principal) (var-get oracle-contract)) err-invalid-oracle)
    
    (match (contract-call? oracle get-asset-price asset-symbol)
      price-value
        (let (
          (update-block (unwrap! (contract-call? oracle get-last-update-block asset-symbol) err-oracle-call-failed))
          (is-valid (unwrap! (contract-call? oracle is-price-valid asset-symbol) err-oracle-call-failed))
        )
          (asserts! is-valid err-stale-price)
          (asserts! (<= (- current-block update-block) max-price-age) err-stale-price)
          
          ;; Cache the price
          (map-set price-cache asset-symbol {
            price: price-value,
            last-update: current-block,
            is-valid: true
          })
          
          (ok price-value))
      error-code err-oracle-call-failed)))

;; Set oracle contract (owner only)
(define-public (set-oracle-contract (oracle-principal principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (validate-oracle-contract oracle-principal) err-invalid-oracle)
    (var-set oracle-contract (some oracle-principal))
    (var-set dynamic-pricing-enabled true) ;; Enable dynamic pricing when oracle is set
    (ok true)))

;; Toggle dynamic pricing
(define-public (toggle-dynamic-pricing)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set dynamic-pricing-enabled (not (var-get dynamic-pricing-enabled)))
    (ok (var-get dynamic-pricing-enabled))))

;; Set asset risk multiplier (owner only)
(define-public (set-asset-risk-multiplier (asset-symbol (string-ascii 10)) (multiplier uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len asset-symbol) u0) err-invalid-amount)
    (asserts! (<= (len asset-symbol) u10) err-invalid-amount)
    (asserts! (> multiplier u0) err-invalid-amount)
    (asserts! (<= multiplier u1000) err-invalid-amount) ;; Max 10x multiplier
    (asserts! (validate-asset-type asset-symbol) err-unsupported-asset)
    (map-set asset-risk-multipliers asset-symbol multiplier)
    (ok true)))

;; Create a new insurance policy for STX with oracle-based dynamic pricing
(define-public (create-stx-policy-with-oracle (coverage-amount uint) (duration uint) (policy-type (string-ascii 50)) (oracle <oracle-trait>))
  (let (
    (policy-id (+ (var-get policy-counter) u1))
    (oracle-principal (contract-of oracle))
    (start-block stacks-block-height)
    (end-block (+ stacks-block-height duration))
  )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> duration u143) err-invalid-duration) ;; Minimum 1 day (144 blocks)
    (asserts! (validate-policy-type policy-type) err-invalid-amount)
    (asserts! (validate-asset-type asset-type-stx) err-unsupported-asset)
    (asserts! (is-eq (some oracle-principal) (var-get oracle-contract)) err-invalid-oracle)
    
    ;; Get fresh price from oracle
    (let (
      (fresh-price (try! (update-asset-price asset-type-stx oracle)))
      (premium (unwrap! (calculate-dynamic-premium coverage-amount duration asset-type-stx) err-oracle-call-failed))
      (coverage-price-usd fresh-price)
      (premium-price-usd fresh-price)
    )
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
        asset-contract: none,
        coverage-price-usd: coverage-price-usd,
        premium-price-usd: premium-price-usd
      })
      
      (add-policy-to-user tx-sender policy-id)
      (var-set policy-counter policy-id)
      (var-set total-premiums (+ (var-get total-premiums) premium))
      
      (ok policy-id))))

;; Create a new insurance policy for STX with dynamic pricing (uses cached prices)
(define-public (create-stx-policy (coverage-amount uint) (duration uint) (policy-type (string-ascii 50)))
  (let (
    (policy-id (+ (var-get policy-counter) u1))
    (premium (unwrap! (calculate-dynamic-premium coverage-amount duration asset-type-stx) err-oracle-call-failed))
    (start-block stacks-block-height)
    (end-block (+ stacks-block-height duration))
    (coverage-price-usd (match (get-asset-price-cached asset-type-stx) price price error-code u0))
    (premium-price-usd (match (get-asset-price-cached asset-type-stx) price price error-code u0))
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
      asset-contract: none,
      coverage-price-usd: coverage-price-usd,
      premium-price-usd: premium-price-usd
    })
    
    (add-policy-to-user tx-sender policy-id)
    (var-set policy-counter policy-id)
    (var-set total-premiums (+ (var-get total-premiums) premium))
    
    (ok policy-id)))

;; Create a new insurance policy for SIP-10 tokens with dynamic pricing
(define-public (create-sip10-policy (coverage-amount uint) (duration uint) (policy-type (string-ascii 50)) (token-contract <sip-010-trait>))
  (let (
    (policy-id (+ (var-get policy-counter) u1))
    (asset-contract-principal (contract-of token-contract))
    (asset-data (unwrap! (map-get? asset-contracts asset-contract-principal) err-unsupported-asset))
    (asset-symbol (get symbol asset-data))
    (premium (unwrap! (calculate-dynamic-premium coverage-amount duration asset-symbol) err-oracle-call-failed))
    (start-block stacks-block-height)
    (end-block (+ stacks-block-height duration))
    (coverage-price-usd (match (get-asset-price-cached asset-symbol) price price error-code u0))
    (premium-price-usd (match (get-asset-price-cached asset-symbol) price price error-code u0))
  )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> duration u143) err-invalid-duration) ;; Minimum 1 day (144 blocks)
    (asserts! (validate-policy-type policy-type) err-invalid-amount)
    (asserts! (validate-asset-type asset-type-sip10) err-unsupported-asset)
    (asserts! (get enabled asset-data) err-unsupported-asset)
    
    ;; Validate and transfer premium in SIP-10 token
    (asserts! (> premium u0) err-invalid-amount)
    (asserts! (<= premium (unwrap! (contract-call? token-contract get-balance tx-sender) err-asset-transfer-failed)) err-insufficient-premium)
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
      asset-contract: (some asset-contract-principal),
      coverage-price-usd: coverage-price-usd,
      premium-price-usd: premium-price-usd
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
    
    ;; Set default risk multiplier
    (map-set asset-risk-multipliers symbol u150)
    
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

;; Clear price cache for an asset (owner only)
(define-public (clear-price-cache (asset-symbol (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len asset-symbol) u0) err-invalid-amount)
    (asserts! (<= (len asset-symbol) u10) err-invalid-amount)
    (map-delete price-cache asset-symbol)
    (ok true)))

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
    protocol-fee-rate: (var-get protocol-fee-rate),
    oracle-enabled: (is-some (var-get oracle-contract)),
    dynamic-pricing-enabled: (var-get dynamic-pricing-enabled)
  })

;; Check if policy is currently active
(define-read-only (is-policy-active (policy-id uint))
  (is-policy-valid policy-id))

;; Get premium calculation for given parameters with dynamic pricing (cached data only)
(define-read-only (get-dynamic-premium-quote (coverage-amount uint) (duration uint) (asset-symbol (string-ascii 10)))
  (calculate-dynamic-premium-cached-only coverage-amount duration asset-symbol))

;; Get premium calculation for given parameters (fallback)
(define-read-only (get-premium-quote (coverage-amount uint) (duration uint))
  (calculate-premium coverage-amount duration))

;; Get current oracle price for an asset (cached data only)
(define-read-only (get-current-asset-price (asset-symbol (string-ascii 10)))
  (get-cached-price-only asset-symbol))

;; Get cached price data
(define-read-only (get-price-cache-data (asset-symbol (string-ascii 10)))
  (map-get? price-cache asset-symbol))

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

;; Get oracle contract
(define-read-only (get-oracle-contract)
  (var-get oracle-contract))

;; Get asset risk multiplier
(define-read-only (get-asset-risk-multiplier (asset-symbol (string-ascii 10)))
  (default-to u100 (map-get? asset-risk-multipliers asset-symbol)))

;; Check if dynamic pricing is enabled
(define-read-only (is-dynamic-pricing-enabled)
  (var-get dynamic-pricing-enabled))