# SafeHaven - Decentralized Multi-Asset Insurance Protocol with Oracle Integration

## Overview

SafeHaven is a decentralized insurance protocol built on the Stacks blockchain that enables users to create and manage insurance policies for various digital assets. The protocol provides a trustless, transparent, and efficient way to handle insurance claims while maintaining security through smart contracts. **Now featuring real-time asset valuation and dynamic premium pricing through oracle integration.**

## Features

- **Oracle Integration**: Real-time asset price feeds for accurate valuation and dynamic pricing
- **Dynamic Premium Calculation**: Risk-adjusted premiums based on current market conditions and asset volatility
- **Multi-Asset Support**: Create insurance policies for STX and SIP-10 tokens with asset-specific risk assessments
- **Policy Creation**: Users can create custom insurance policies with flexible coverage amounts and durations
- **Claims Management**: Streamlined claim submission and approval process
- **Premium Calculation**: Automated premium calculation based on coverage amount, policy duration, and real-time market data
- **Multi-Policy Support**: Users can hold multiple active policies simultaneously for different assets
- **Transparent Operations**: All transactions and policy states are recorded on-chain
- **Asset Management**: Admin controls for adding/removing supported SIP-10 tokens and risk parameters
- **Admin Controls**: Protocol governance features for claim approval, fee management, and oracle configuration
- **Price Caching**: Optimized gas usage through intelligent price caching mechanisms
- **Risk Assessment**: Configurable risk multipliers for different asset types

## Smart Contract Functions

### Oracle Functions

- `set-oracle-contract`: Configure the oracle contract for price feeds (admin only)
- `toggle-dynamic-pricing`: Enable/disable dynamic pricing based on oracle data (admin only)
- `set-asset-risk-multiplier`: Configure risk multipliers for different assets (admin only)
- `clear-price-cache`: Clear cached price data for an asset (admin only)

### Core Functions

- `create-stx-policy`: Create a new insurance policy for STX with dynamic pricing
- `create-sip10-policy`: Create a new insurance policy for SIP-10 tokens with dynamic pricing
- `submit-claim`: Submit a claim against an active policy
- `approve-stx-claim`: Approve a submitted claim for STX policies (admin only)
- `approve-sip10-claim`: Approve a submitted claim for SIP-10 policies with token contract (admin only)
- `deny-claim`: Deny a submitted claim (admin only)
- `cancel-policy`: Cancel an active policy before expiration

### Asset Management Functions

- `add-sip10-asset`: Add a new supported SIP-10 token with risk parameters (admin only)
- `remove-sip10-asset`: Remove support for a SIP-10 token (admin only)
- `update-sip10-asset`: Update SIP-10 asset details and parameters (admin only)

### Read-Only Functions

- `get-policy`: Retrieve policy details by ID (includes asset type, contract, and USD pricing)
- `get-user-policies`: Get all policies owned by a user
- `get-claim`: Get claim details by policy ID
- `get-contract-stats`: View protocol statistics including oracle status
- `is-policy-active`: Check if a policy is currently active
- `get-dynamic-premium-quote`: Calculate premium with oracle pricing for given parameters
- `get-premium-quote`: Calculate premium using fallback pricing (no oracle)
- `get-current-asset-price`: Get real-time asset price from oracle
- `get-price-cache-data`: View cached price information for an asset
- `is-asset-supported`: Check if an asset type is supported
- `get-asset-contract`: Get details of a registered SIP-10 asset
- `is-sip10-asset-supported`: Check if a specific SIP-10 token is supported
- `get-oracle-contract`: Get the current oracle contract address
- `get-asset-risk-multiplier`: Get risk multiplier for an asset
- `is-dynamic-pricing-enabled`: Check if dynamic pricing is active

## Installation

1. Clone the repository
2. Install Clarinet: `curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64.tar.gz | tar xz`
3. Run `clarinet check` to verify contract syntax
4. Run `clarinet test` to execute test suite

## Usage

### Setting Up Oracle Integration

```clarity
;; Admin sets up oracle contract
(contract-call? .safehaven set-oracle-contract 'SP1234...ORACLE-CONTRACT)

;; Enable dynamic pricing
(contract-call? .safehaven toggle-dynamic-pricing)

;; Configure asset risk multipliers
(contract-call? .safehaven set-asset-risk-multiplier "STX" u100)  ;; 1.0x base risk
(contract-call? .safehaven set-asset-risk-multiplier "BTC" u150)  ;; 1.5x higher risk
```

### Creating Policies with Dynamic Pricing

```clarity
;; Create STX policy with oracle-based pricing
(contract-call? .safehaven create-stx-policy u10000 u1440 "STX Asset Protection")

;; Create SIP-10 token policy with dynamic pricing
(contract-call? .safehaven create-sip10-policy u5000 u2160 "BTC Protection" 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.wrapped-bitcoin)
```

### Getting Premium Quotes

```clarity
;; Get dynamic premium quote with oracle pricing
(contract-call? .safehaven get-dynamic-premium-quote u10000 u1440 "STX")

;; Get fallback premium quote (no oracle)
(contract-call? .safehaven get-premium-quote u10000 u1440)

;; Check current asset price
(contract-call? .safehaven get-current-asset-price "STX")
```

### Submitting Claims

```clarity
(contract-call? .safehaven submit-claim u1 u5000 "Asset lost due to protocol hack")
```

### Checking Policy Status

```clarity
;; Get detailed policy information including USD pricing at creation
(contract-call? .safehaven get-policy u1)

;; Check if policy is active
(contract-call? .safehaven is-policy-active u1)
```

### Asset and Oracle Management

```clarity
;; Check oracle status
(contract-call? .safehaven get-oracle-contract)
(contract-call? .safehaven is-dynamic-pricing-enabled)

;; View cached price data
(contract-call? .safehaven get-price-cache-data "STX")

;; Check asset risk multipliers
(contract-call? .safehaven get-asset-risk-multiplier "BTC")
```

## Oracle Integration Details

### Supported Oracle Functions

The protocol integrates with oracle contracts that implement the `oracle-trait`:

- `get-asset-price`: Retrieve current asset price in USD (with 6 decimal precision)
- `get-last-update-block`: Get the block height of the last price update
- `is-price-valid`: Check if the current price data is valid

### Price Validation

- **Maximum Price Age**: 144 blocks (approximately 1 day)
- **Price Caching**: Intelligent caching to reduce gas costs
- **Stale Price Protection**: Automatic fallback to static pricing if oracle data is stale
- **Price Deviation Monitoring**: Configurable thresholds for price volatility detection

### Dynamic Pricing Algorithm

1. **Base Premium**: Calculated as percentage of coverage amount
2. **Risk Adjustment**: Applied based on asset-specific risk multipliers
3. **Duration Factor**: Longer policies incur higher premiums
4. **Volatility Premium**: High-value assets (>$100M market cap) incur additional 10% premium
5. **Minimum Premium**: Ensures protocol sustainability

## Supported Asset Types

### Native Assets
- **STX**: Native Stacks token with real-time pricing

### SIP-10 Tokens
- Support for any SIP-10 compliant token with oracle price feeds
- Configurable risk multipliers per asset
- Examples of popular SIP-10 tokens that can be supported:
  - xBTC (Wrapped Bitcoin)
  - USDA (USD Anchor)
  - MiamiCoin (MIA)
  - NewYorkCityCoin (NYC)
  - And any other SIP-10 compliant tokens with oracle support

## Policy Types

- STX Asset Protection
- SIP-10 Token Insurance
- DeFi Protocol Insurance
- NFT Collection Coverage
- Smart Contract Risk Protection
- Cross-Chain Bridge Insurance
- Staking Rewards Insurance
- Market Volatility Protection (with oracle pricing)

## Technical Specifications

- **Minimum Policy Duration**: 144 blocks (approximately 1 day)
- **Base Premium Rate**: 1% of coverage amount
- **Risk Multipliers**: 1.0x (STX) to 1.5x (volatile assets)
- **Maximum Policies per User**: 20
- **Protocol Fee**: 5% of premiums (adjustable)
- **Oracle Price Precision**: 6 decimal places (1,000,000 = $1.00)
- **Maximum Price Age**: 144 blocks
- **Price Cache Duration**: Optimized for gas efficiency
- **Maximum Risk Multiplier**: 10x
- **Volatility Premium**: 10% for high-value assets

## Oracle Features

### Price Feed Management
- Real-time asset valuation from trusted oracle sources
- Automatic price validation and staleness checks
- Intelligent caching system for gas optimization
- Fallback to static pricing when oracle unavailable

### Risk Assessment
- Asset-specific risk multipliers
- Market volatility adjustments
- Dynamic premium calculation based on current market conditions
- Protection against price manipulation

### Administrative Controls
- Oracle contract configuration
- Dynamic pricing toggle
- Risk parameter updates
- Price cache management

## Security Features

- Comprehensive input validation for all asset types and oracle data
- Proper error handling for multi-asset operations and oracle failures
- Access control for administrative functions
- Prevention of double-spending and replay attacks
- Time-based policy validation with oracle price timestamping
- Asset contract validation for SIP-10 tokens
- Safe transfer mechanisms for all supported assets
- Oracle data validation and staleness protection
- Price manipulation safeguards

## Error Codes

### Oracle-Specific Errors
- `err-oracle-not-set` (u115): Oracle contract not configured
- `err-invalid-oracle` (u116): Invalid oracle contract address
- `err-stale-price` (u117): Oracle price data is too old
- `err-price-deviation` (u118): Price deviation exceeds threshold
- `err-oracle-call-failed` (u119): Oracle contract call failed

### General Errors
- `err-owner-only` (u100): Function restricted to contract owner
- `err-not-found` (u101): Requested data not found
- `err-unauthorized` (u102): Unauthorized access attempt
- `err-invalid-amount` (u103): Invalid amount or parameter
- `err-policy-expired` (u104): Policy has expired
- `err-insufficient-premium` (u106): Premium amount too low
- Additional error codes for comprehensive error handling

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all tests pass (including oracle integration tests)
5. Test with local oracle mock contracts
6. Submit a pull request

## Oracle Integration Testing

The protocol includes comprehensive testing for oracle integration:

- Mock oracle contracts for development
- Price feed validation tests
- Dynamic pricing calculation tests
- Fallback mechanism tests
- Cache optimization tests
- Staleness protection tests