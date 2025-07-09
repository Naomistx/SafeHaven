# SafeHaven - Decentralized Insurance Protocol

## Overview

SafeHaven is a decentralized insurance protocol built on the Stacks blockchain that enables users to create and manage insurance policies for digital assets. The protocol provides a trustless, transparent, and efficient way to handle insurance claims while maintaining security through smart contracts.

## Features

- **Policy Creation**: Users can create custom insurance policies with flexible coverage amounts and durations
- **Claims Management**: Streamlined claim submission and approval process
- **Premium Calculation**: Automated premium calculation based on coverage amount and policy duration
- **Multi-Policy Support**: Users can hold multiple active policies simultaneously
- **Transparent Operations**: All transactions and policy states are recorded on-chain
- **Admin Controls**: Protocol governance features for claim approval and fee management

## Smart Contract Functions

### Core Functions

- `create-policy`: Create a new insurance policy with specified coverage and duration
- `submit-claim`: Submit a claim against an active policy
- `approve-claim`: Approve a submitted claim (admin only)
- `deny-claim`: Deny a submitted claim (admin only)
- `cancel-policy`: Cancel an active policy before expiration

### Read-Only Functions

- `get-policy`: Retrieve policy details by ID
- `get-user-policies`: Get all policies owned by a user
- `get-claim`: Get claim details by policy ID
- `get-contract-stats`: View protocol statistics
- `is-policy-active`: Check if a policy is currently active
- `get-premium-quote`: Calculate premium for given parameters

## Installation

1. Clone the repository
2. Install Clarinet: `curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64.tar.gz | tar xz`
3. Run `clarinet check` to verify contract syntax
4. Run `clarinet test` to execute test suite

## Usage

### Creating a Policy

```clarity
(contract-call? .safehaven create-policy u10000 u1440 "Digital Asset Protection")
```

### Submitting a Claim

```clarity
(contract-call? .safehaven submit-claim u1 u5000 "Asset lost due to protocol hack")
```

### Checking Policy Status

```clarity
(contract-call? .safehaven get-policy u1)
```

## Policy Types

- Digital Asset Protection
- DeFi Protocol Insurance
- NFT Collection Coverage
- Smart Contract Risk Protection
- Staking Rewards Insurance

## Technical Specifications

- **Minimum Policy Duration**: 144 blocks (approximately 1 day)
- **Base Premium Rate**: 1% of coverage amount
- **Maximum Policies per User**: 20
- **Protocol Fee**: 5% of premiums (adjustable)

## Security Features

- Comprehensive input validation
- Proper error handling for all edge cases
- Access control for administrative functions
- Prevention of double-spending and replay attacks
- Time-based policy validation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all tests pass
5. Submit a pull request

