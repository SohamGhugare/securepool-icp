# SecurePool Insurance Smart Contracts

This directory contains the Motoko canisters for the SecurePool DeFi Insurance Platform.

## Canisters

### InsurancePool

The InsurancePool canister manages the staking pool for users to provide liquidity. It handles:

- Stake creation and management
- APY calculations based on lock periods
- Rewards distribution for stakers
- Pool statistics tracking

### InsurancePolicy

The InsurancePolicy canister handles insurance policies and claims. It provides:

- Policy creation and management
- Premium calculations based on risk factor
- Claims filing and processing
- Policy and claim status tracking

## Development

### Prerequisites

- [dfx](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove) - The DFINITY Canister SDK
- Node.js and npm

### Local Development

1. Start the local Internet Computer replica:

```bash
dfx start --background
```

2. Deploy the canisters to the local replica:

```bash
dfx deploy
```

3. Generate the Candid interface files for frontend integration:

```bash
node utils/idl.js
```

### Testing

Run the test canister:

```bash
dfx deploy insurance_test
dfx canister call insurance_test runTests
```

## Smart Contract Details

### InsurancePool Functions

- `stake(amount: Nat, lockPeriod: Nat)` - Stake tokens in the pool
- `unstake(stakeId: StakeId)` - Unstake tokens (after lock period)
- `getStake(stakeId: StakeId)` - Get stake information
- `getUserStakes(user: Principal)` - Get all stakes for a user
- `getPoolStats()` - Get pool statistics
- `updateBaseApy(newApy: Float)` - Update base APY (admin only)

### InsurancePolicy Functions

- `createPolicy(policyType: PolicyType, coverage: Nat, durationDays: Nat)` - Create a new policy
- `fileClaim(policyId: PolicyId, amount: Nat, evidence: Text)` - File a claim for a policy
- `processClaim(claimId: ClaimId, approved: Bool, notes: ?Text)` - Process a claim (admin only)
- `getPolicy(policyId: PolicyId)` - Get policy details
- `getUserPolicies(user: Principal)` - Get all policies for a user
- `getClaim(claimId: ClaimId)` - Get claim details
- `getPolicyClaims(policyId: PolicyId)` - Get all claims for a policy
- `updateParameters(...)` - Update insurance parameters (admin only)
- `getParameters()` - Get insurance parameters

## Deployment to ICP Mainnet

To deploy to the ICP mainnet:

```bash
dfx deploy --network=ic
``` 