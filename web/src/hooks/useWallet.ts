import { useEffect, useCallback } from 'react';
import { BrowserProvider, JsonRpcSigner } from 'ethers';
import { useWalletStore } from '@/stores/walletStore';
import { SUPPORTED_NETWORKS, APP_CONFIG, ERROR_MESSAGES } from '@/utils/constants';
import { formatWeiToEther } from '@/utils/formatters';

declare global {
  interface Window {
    ethereum?: any;
  }
}

export const useWallet = () => {
  const {
    address,
    chainId,
    isConnected,
    isConnecting,
    balance,
    ensName,
    error,
    setAddress,
    setChainId,
    setConnected,
    setConnecting,
    setBalance,
    setEnsName,
    setError,
    reset,
  } = useWalletStore();

  // Check if MetaMask is installed
  const isMetaMaskInstalled = useCallback(() => {
    return typeof window !== 'undefined' && typeof window.ethereum !== 'undefined';
  }, []);

  // Get provider and signer
  const getProvider = useCallback(async (): Promise<BrowserProvider | null> => {
    if (!isMetaMaskInstalled()) return null;
    return new BrowserProvider(window.ethereum);
  }, [isMetaMaskInstalled]);

  const getSigner = useCallback(async (): Promise<JsonRpcSigner | null> => {
    const provider = await getProvider();
    if (!provider) return null;
    return await provider.getSigner();
  }, [getProvider]);

  // Connect wallet
  const connect = useCallback(async () => {
    if (!isMetaMaskInstalled()) {
      setError({
        code: -1,
        message: 'MetaMask is not installed. Please install MetaMask to continue.',
      });
      return;
    }

    setConnecting(true);
    setError(null);

    try {
      const provider = await getProvider();
      if (!provider) throw new Error('Failed to get provider');

      // Request account access
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts',
      });

      if (accounts.length === 0) {
        throw new Error('No accounts found');
      }

      const account = accounts[0];
      const network = await provider.getNetwork();
      const balance = await provider.getBalance(account);

      setAddress(account);
      setChainId(Number(network.chainId));
      setBalance(formatWeiToEther(balance));
      setConnected(true);

      // Try to get ENS name
      try {
        const ensName = await provider.lookupAddress(account);
        setEnsName(ensName || undefined);
      } catch {
        // ENS lookup failed, ignore
      }

    } catch (error: any) {
      setError({
        code: error.code || -1,
        message: error.message || 'Failed to connect wallet',
      });
      reset();
    } finally {
      setConnecting(false);
    }
  }, [isMetaMaskInstalled, getProvider, setAddress, setChainId, setBalance, setConnected, setEnsName, setError, setConnecting, reset]);

  // Disconnect wallet
  const disconnect = useCallback(() => {
    reset();
  }, [reset]);

  // Switch network
  const switchNetwork = useCallback(async (networkId: number) => {
    if (!isMetaMaskInstalled() || !isConnected) {
      setError({
        code: -1,
        message: ERROR_MESSAGES.WALLET_NOT_CONNECTED,
      });
      return;
    }

    const network = SUPPORTED_NETWORKS[networkId as keyof typeof SUPPORTED_NETWORKS];
    if (!network) {
      setError({
        code: -1,
        message: 'Unsupported network',
      });
      return;
    }

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${networkId.toString(16)}` }],
      });
    } catch (switchError: any) {
      // This error code indicates that the chain has not been added to MetaMask
      if (switchError.code === 4902) {
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [
              {
                chainId: `0x${networkId.toString(16)}`,
                chainName: network.name,
                nativeCurrency: network.nativeCurrency,
                rpcUrls: network.rpcUrls,
                blockExplorerUrls: network.blockExplorerUrls,
              },
            ],
          });
        } catch (addError: any) {
          setError({
            code: addError.code || -1,
            message: addError.message || 'Failed to add network',
          });
        }
      } else {
        setError({
          code: switchError.code || -1,
          message: switchError.message || 'Failed to switch network',
        });
      }
    }
  }, [isMetaMaskInstalled, isConnected, setError]);

  // Update balance
  const updateBalance = useCallback(async () => {
    if (!address || !isConnected) return;

    try {
      const provider = await getProvider();
      if (!provider) return;

      const balance = await provider.getBalance(address);
      setBalance(formatWeiToEther(balance));
    } catch (error) {
      console.error('Failed to update balance:', error);
    }
  }, [address, isConnected, getProvider, setBalance]);

  // Check if on correct network
  const isCorrectNetwork = useCallback(() => {
    return chainId === APP_CONFIG.DEFAULT_NETWORK_ID;
  }, [chainId]);

  // Setup event listeners
  useEffect(() => {
    if (!isMetaMaskInstalled()) return;

    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts.length === 0) {
        disconnect();
      } else if (accounts[0] !== address) {
        setAddress(accounts[0]);
        updateBalance();
      }
    };

    const handleChainChanged = (chainId: string) => {
      setChainId(parseInt(chainId, 16));
      updateBalance();
    };

    const handleDisconnect = () => {
      disconnect();
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);
    window.ethereum.on('disconnect', handleDisconnect);

    return () => {
      if (window.ethereum.removeListener) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
        window.ethereum.removeListener('disconnect', handleDisconnect);
      }
    };
  }, [isMetaMaskInstalled, address, disconnect, setAddress, setChainId, updateBalance]);

  // Auto-connect if previously connected
  useEffect(() => {
    const autoConnect = async () => {
      if (!isMetaMaskInstalled()) return;

      try {
        const accounts = await window.ethereum.request({
          method: 'eth_accounts',
        });

        if (accounts.length > 0) {
          await connect();
        }
      } catch (error) {
        console.error('Auto-connect failed:', error);
      }
    };

    autoConnect();
  }, []);

  return {
    // State
    address,
    chainId,
    isConnected,
    isConnecting,
    balance,
    ensName,
    error,
    
    // Actions
    connect,
    disconnect,
    switchNetwork,
    updateBalance,
    
    // Utils
    getProvider,
    getSigner,
    isMetaMaskInstalled,
    isCorrectNetwork,
  };
};
