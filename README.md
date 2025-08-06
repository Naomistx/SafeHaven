# SafeHaven - Decentralized Multi-Asset Insurance Protocol

## Overview

SafeHaven is a decentralized insurance protocol built on the Stacks blockchain that enables users to create and manage insurance policies for various digital assets. The protocol provides a trustless, transparent, and efficient way to handle insurance claims while maintaining security through smart contracts. **Now supporting multiple cryptocurrency assets including STX and SIP-10 tokens.**

## Features

- **Multi-Asset Support**: Create insurance policies for STX and SIP-10 tokens
- **Policy Creation**: Users can create custom insurance policies with flexible coverage amounts and durations
- **Claims Management**: Streamlined claim submission and approval process
- **Premium Calculation**: Automated premium calculation based on coverage amount and policy duration
- **Multi-Policy Support**: Users can hold multiple active policies simultaneously for different assets
- **Transparent Operations**: All transactions and policy states are recorded on-chain
- **Asset Management**: Admin controls for adding/removing supported SIP-10 tokens
- **Admin Controls**: Protocol governance features for claim approval and fee management

## Smart Contract Functions

### Core Functions

- `create-stx-policy`: Create a new insurance policy for STX with specified coverage and duration
- `create-sip10-policy`: Create a new insurance policy for SIP-10 tokens with specified asset contract
- `submit-claim`: Submit a claim against an active policy
- `approve-stx-claim`: Approve a submitted claim for STX policies (admin only)
- `approve-sip10-claim`: Approve a submitted claim for SIP-10 policies with token contract (admin only)
- `deny-claim`: Deny a submitted claim (admin only)
- `cancel-policy`: Cancel an active policy before expiration

### Asset Management Functions

- `add-sip10-asset`: Add a new supported SIP-10 token (admin only)
- `remove-sip10-asset`: Remove support for a SIP-10 token (admin only)

### Read-Only Functions

- `get-policy`: Retrieve policy details by ID (includes asset type and contract)
- `get-user-policies`: Get all policies owned by a user
- `get-claim`: Get claim details by policy ID
- `get-contract-stats`: View protocol statistics
- `is-policy-active`: Check if a policy is currently active
- `get-premium-quote`: Calculate premium for given parameters
- `is-asset-supported`: Check if an asset type is supported
- `get-asset-contract`: Get details of a registered SIP-10 asset
- `is-sip10-asset-supported`: Check if a specific SIP-10 token is supported

## Installation

1. Clone the repository
2. Install Clarinet: `curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64.tar.gz | tar xz`
3. Run `clarinet check` to verify contract syntax
4. Run `clarinet test` to execute test suite

## Usage

### Creating an STX Policy

```clarity
(contract-call? .safehaven create-stx-policy u10000 u1440 "STX Asset Protection")
```

### Creating a SIP-10 Token Policy

```clarity
;; First, the asset must be registered by an admin
(contract-call? .safehaven add-sip10-asset 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token "MIA" u6)

;; Then users can create policies for that asset (passing the token contract as trait)
(contract-call? .safehaven create-sip10-policy u5000 u2160 "MIA Token Protection" 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token)
```

### Submitting a Claim

```clarity
(contract-call? .safehaven submit-claim u1 u5000 "Asset lost due to protocol hack")
```

### Checking Policy Status

```clarity
(contract-call? .safehaven get-policy u1)
```

### Checking Asset Support

```clarity
;; Check if asset type is supported
(contract-call? .safehaven is-asset-supported "SIP10")

;; Check specific SIP-10 token support
(contract-call? .safehaven is-sip10-asset-supported 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token)
```

## Supported Asset Types

### Native Assets
- **STX**: Native Stacks token

### SIP-10 Tokens
- Support for any SIP-10 compliant token
- Tokens must be registered by protocol administrators
- Examples of popular SIP-10 tokens that can be supported:
  - xBTC (Wrapped Bitcoin)
  - USDA (USD Anchor)
  - MiamiCoin (MIA)
  - NewYorkCityCoin (NYC)
  - And any other SIP-10 compliant tokens

## Policy Types

- STX Asset Protection
- SIP-10 Token Insurance
- DeFi Protocol Insurance
- NFT Collection Coverage
- Smart Contract Risk Protection
- Cross-Chain Bridge Insurance
- Staking Rewards Insurance

## Technical Specifications

- **Minimum Policy Duration**: 144 blocks (approximately 1 day)
- **Base Premium Rate**: 1% of coverage amount
- **Maximum Policies per User**: 20
- **Protocol Fee**: 5% of premiums (adjustable)
- **Supported Asset Types**: STX, SIP-10 tokens
- **Maximum SIP-10 Token Symbol Length**: 10 characters
- **Maximum Token Decimals**: 18

## Multi-Asset Features

### Asset Type Validation
- Automatic validation of supported asset types
- SIP-10 token contract verification
- Asset-specific transfer handling

### Premium Handling
- Premiums paid in the same asset as the policy coverage
- Separate accounting for different asset types
- Asset-specific emergency withdrawal functions

### Claim Payouts
- Claims paid in the same asset as the policy
- Automatic asset type detection for payouts
- Support for different token decimal configurations

## Security Features

- Comprehensive input validation for all asset types
- Proper error handling for multi-asset operations
- Access control for administrative functions
- Prevention of double-spending and replay attacks
- Time-based policy validation
- Asset contract validation for SIP-10 tokens
- Safe transfer mechanisms for all supported assets

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all tests pass (including multi-asset tests)
5. Submit a pull request
