# DeFi Insurance Platform

## Overview
A decentralized insurance platform built on ICP blockchain, offering protection against crypto-related risks like exchange hacks, smart contract failures, and wallet compromises. The platform integrates with Plug wallet for ICP connectivity.

## Technical Stack
- Next.js + TypeScript
- ICP Blockchain + Canister Smart Contracts
- TailwindCSS for styling

## Smart Contracts
The platform uses two main Canister smart contracts:

### InsurancePool
Manages staking pools where users can provide liquidity:
- Stake management
- APY calculations
- Lockup periods
- Rewards distribution

### InsurancePolicy
Handles insurance policies and claims:
- Policy creation and management
- Claims processing
- Coverage tracking
- Premium calculations

## Plug Wallet Integration

### Wallet Connection
```typescript
// Define type for window with IC Plug
declare global {
  interface Window {
    ic?: {
      plug?: {
        requestConnect: () => Promise<boolean>;
        isConnected: () => Promise<boolean>;
        agent?: any;
        principalId?: string;
        disconnect: () => Promise<void>;
      };
    };
  }
}

// Connect wallet
const connectWallet = async () => {
  try {
    console.log('Attempting to connect to Plug wallet...');
    
    if (typeof window === 'undefined' || !window.ic?.plug) {
      throw new Error('Plug wallet not found. Please install the Plug wallet extension.');
    }
    
    const hasAllowed = await window.ic.plug.requestConnect();
    
    if (hasAllowed) {
      console.log('Plug wallet is connected');
      setIsConnected(true);
      if (window.ic.plug.principalId) {
        setAddress(window.ic.plug.principalId);
      }
      return window.ic.plug.principalId;
    } else {
      console.log('Plug wallet connection was refused');
      throw new Error('Wallet connection refused');
    }
  } catch (error) {
    console.error('Failed to connect wallet:', error);
    throw error;
  }
};

// Disconnect wallet
const disconnectWallet = async () => {
  try {
    if (typeof window !== 'undefined' && window.ic?.plug) {
      await window.ic.plug.disconnect();
    }
    setAddress(null);
    setIsConnected(false);
  } catch (error) {
    console.error('Failed to disconnect wallet:', error);
  }
};
```

### Transaction Execution
```typescript
// Purchase insurance policy
const purchasePolicy = async (policyId: string, coverage: bigint, duration: bigint) => {
  try {
    // Make sure Plug wallet is connected
    if (typeof window === 'undefined' || !window.ic?.plug) {
      throw new Error('Plug wallet not connected');
    }

    // Create an actor to interact with the insurance canister
    const insuranceActor = await window.ic.plug.createActor({
      canisterId: process.env.NEXT_PUBLIC_INSURANCE_CANISTER_ID || '',
      interfaceFactory: insuranceIDL,
    });

    // Call the insurance policy purchase method
    const result = await insuranceActor.purchasePolicy({
      policyId: policyId,
      coverage: coverage,
      duration: duration
    });
    
    return result;
  } catch (error) {
    console.error('Policy purchase failed:', error);
    throw error;
  }
}
```

## Humanity Protocol Integration

### Identity Verification
```typescript
import { HumanityProtocol } from "@humanity-protocol/sdk";

const humanityProtocol = new HumanityProtocol({
  network: "testnet",
  apiKey: process.env.HUMANITY_API_KEY
});

// Verify user identity
const verifyIdentity = async (address: string) => {
  try {
    const verification = await humanityProtocol.verify({
      address: address,
      requiredCredentials: ["KYC", "PROOF_OF_HUMANITY"]
    });
    
    return verification.status === "VERIFIED";
  } catch (error) {
    console.error("Identity verification failed:", error);
    return false;
  }
}

// Check verification status
const checkVerificationStatus = async (address: string) => {
  const status = await humanityProtocol.getVerificationStatus(address);
  return status;
}
```

## Setup & Development

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```env
NEXT_PUBLIC_DFX_NETWORK=local
NEXT_PUBLIC_INSURANCE_CANISTER_ID=your_canister_id
HUMANITY_API_KEY=your_api_key
```

3. Deploy canisters:
```bash
dfx deploy --network=ic
```

4. Run development server:
```bash
npm run dev
```

## Smart Contract Deployment

1. Deploy InsurancePool canister:
```bash
dfx deploy InsurancePool
```

2. Deploy InsurancePolicy canister:
```bash
dfx deploy InsurancePolicy
```

## Security Considerations
- All smart contracts should be audited before mainnet deployment
- Implement rate limiting for claims
- Use secure random number generation for policy IDs
- Implement proper access control in smart contracts
- Regular security updates and monitoring

## Testing
Run canister tests:
```bash
dfx test
```
