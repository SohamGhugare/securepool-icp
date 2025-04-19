'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { VerificationDialog } from './ui/VerificationDialog';

// Define type for window with IC Plug
declare global {
  interface Window {
    ic?: {
      plug?: {
        requestConnect: () => Promise<boolean>;
        isConnected: () => Promise<boolean>;
        agent?: unknown;
        principalId?: string;
        disconnect: () => Promise<void>;
      };
    };
  }
}

interface WalletContextType {
  isConnected: boolean;
  address: string | null;
  connect: () => Promise<void>;
  disconnect: () => void;
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [isConnected, setIsConnected] = useState(false);
  const [address, setAddress] = useState<string | null>(null);
  const [showVerification, setShowVerification] = useState(false);

  // Check if wallet is already connected on mount
  useEffect(() => {
    const checkConnection = async () => {
      if (typeof window !== 'undefined' && window.ic?.plug) {
        try {
          const connected = await window.ic.plug.isConnected();
          if (connected) {
            setIsConnected(true);
            if (window.ic.plug.principalId) {
              setAddress(window.ic.plug.principalId);
            }
          }
        } catch (error) {
          console.error('Failed to check Plug wallet connection:', error);
        }
      }
    };

    checkConnection();
  }, []);

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
        setShowVerification(true);
      } else {
        console.log('Plug wallet connection was refused');
        throw new Error('Wallet connection refused');
      }
    } catch (error) {
      console.error('Failed to connect wallet:', error);
      throw error;
    }
  };

  const disconnect = async () => {
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

  return (
    <WalletContext.Provider value={{ isConnected, address, connect: connectWallet, disconnect }}>
      {children}
      <VerificationDialog 
        isOpen={showVerification}
        onClose={() => setShowVerification(false)}
      />
    </WalletContext.Provider>
  );
}

export const useWallet = () => {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
}; 