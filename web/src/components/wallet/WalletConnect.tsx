import React from 'react';
import { useWallet } from '@/hooks/useWallet';
import { Button } from '@/components/ui/Button';
import { formatAddress } from '@/utils/formatters';
import { SUPPORTED_NETWORKS } from '@/utils/constants';
import { WalletIcon, ChevronDownIcon } from '@heroicons/react/24/outline';

export const WalletConnect: React.FC = () => {
  const {
    address,
    chainId,
    isConnected,
    isConnecting,
    balance,
    ensName,
    error,
    connect,
    disconnect,
    switchNetwork,
    isMetaMaskInstalled,
    isCorrectNetwork,
  } = useWallet();

  if (!isMetaMaskInstalled()) {
    return (
      <div className="text-center p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
        <p className="text-yellow-800 mb-3">MetaMask is required to use this application</p>
        <a
          href="https://metamask.io/download/"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-colors"
        >
          Install MetaMask
        </a>
      </div>
    );
  }

  if (!isConnected) {
    return (
      <div className="text-center">
        <Button
          onClick={connect}
          loading={isConnecting}
          className="inline-flex items-center"
        >
          <WalletIcon className="w-5 h-5 mr-2" />
          Connect Wallet
        </Button>
        {error && (
          <p className="text-error-600 text-sm mt-2">{error.message}</p>
        )}
      </div>
    );
  }

  const currentNetwork = chainId ? SUPPORTED_NETWORKS[chainId as keyof typeof SUPPORTED_NETWORKS] : null;

  return (
    <div className="flex items-center space-x-4">
      {/* Network Status */}
      {!isCorrectNetwork() && (
        <div className="flex items-center space-x-2 px-3 py-1 bg-warning-100 text-warning-800 rounded-lg text-sm">
          <span>Wrong Network</span>
          <Button
            size="sm"
            variant="outline"
            onClick={() => switchNetwork(31337)}
            className="ml-2"
          >
            Switch
          </Button>
        </div>
      )}

      {/* Wallet Info */}
      <div className="flex items-center space-x-3 bg-gray-50 rounded-lg px-4 py-2">
        <div className="flex flex-col items-end">
          <div className="text-sm font-medium text-gray-900">
            {ensName || formatAddress(address!)}
          </div>
          <div className="text-xs text-gray-500">
            {balance} ETH
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          {currentNetwork && (
            <div className="text-xs text-gray-500">
              {currentNetwork.name}
            </div>
          )}
          
          <button
            onClick={disconnect}
            className="p-1 text-gray-400 hover:text-gray-600 transition-colors"
            title="Disconnect"
          >
            <ChevronDownIcon className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
};
