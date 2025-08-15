import { useEffect, useCallback } from 'react';
import { Contract } from 'ethers';
import { useWallet } from './useWallet';
import { useCrowdsaleStore } from '@/stores/crowdsaleStore';
import { useWalletStore } from '@/stores/walletStore';
import { CONTRACT_ABIS } from '@/utils/contracts';
import { APP_CONFIG, ERROR_MESSAGES, SUCCESS_MESSAGES } from '@/utils/constants';
import { TransactionType, TransactionStatus } from '@/types/wallet';
import { CrowdsaleConfig, CrowdsaleStats, CrowdsalePhase } from '@/types/contracts';
import toast from 'react-hot-toast';

export const useCrowdsale = (crowdsaleAddress?: string) => {
  const { getProvider, getSigner, isConnected, address } = useWallet();
  const { addTransaction, updateTransaction } = useWalletStore();
  const {
    currentCrowdsale,
    config,
    stats,
    phase,
    isLoading,
    isPurchasing,
    setCurrentCrowdsale,
    setConfig,
    setStats,
    setPhase,
    setLoading,
    setPurchasing,
    getFundingProgress,
    getRemainingTime,
    isActive,
    canPurchase,
  } = useCrowdsaleStore();

  // Set current crowdsale
  useEffect(() => {
    if (crowdsaleAddress && crowdsaleAddress !== currentCrowdsale) {
      setCurrentCrowdsale(crowdsaleAddress);
    }
  }, [crowdsaleAddress, currentCrowdsale, setCurrentCrowdsale]);

  // Get crowdsale contract instance
  const getCrowdsaleContract = useCallback(async (address?: string) => {
    const provider = await getProvider();
    if (!provider) return null;

    const contractAddress = address || currentCrowdsale;
    if (!contractAddress) return null;

    return new Contract(contractAddress, CONTRACT_ABIS.TokenCrowdsale, provider);
  }, [getProvider, currentCrowdsale]);

  // Fetch crowdsale data
  const fetchCrowdsaleData = useCallback(async (address?: string) => {
    const contract = await getCrowdsaleContract(address);
    if (!contract) return;

    setLoading(true);

    try {
      const [currentConfig, currentStats, currentPhase] = await Promise.all([
        contract.getCrowdsaleConfig(),
        contract.getCrowdsaleStats(),
        contract.getCurrentPhase(),
      ]);

      // Parse config
      const parsedConfig: CrowdsaleConfig = {
        presaleStartTime: currentConfig[0],
        presaleEndTime: currentConfig[1],
        publicSaleStartTime: currentConfig[2],
        publicSaleEndTime: currentConfig[3],
        softCap: currentConfig[4],
        hardCap: currentConfig[5],
        minPurchase: currentConfig[6],
        maxPurchase: currentConfig[7],
      };

      // Parse stats
      const parsedStats: CrowdsaleStats = {
        totalRaised: currentStats[0],
        totalTokensSold: currentStats[1],
        totalPurchases: currentStats[2],
        totalParticipants: currentStats[3],
        participantCount: currentStats[4],
        presaleRaised: currentStats[5],
        publicSaleRaised: currentStats[6],
      };

      setConfig(parsedConfig);
      setStats(parsedStats);
      setPhase(currentPhase as CrowdsalePhase);
    } catch (error) {
      console.error('Failed to fetch crowdsale data:', error);
      toast.error('Failed to load crowdsale data');
    } finally {
      setLoading(false);
    }
  }, [getCrowdsaleContract, setLoading, setConfig, setStats, setPhase]);

  // Purchase tokens
  const purchaseTokens = useCallback(async (amount: string) => {
    if (!isConnected || !address) {
      toast.error(ERROR_MESSAGES.WALLET_NOT_CONNECTED);
      return;
    }

    if (!canPurchase()) {
      toast.error(ERROR_MESSAGES.CROWDSALE_NOT_ACTIVE);
      return;
    }

    const signer = await getSigner();
    const contract = await getCrowdsaleContract();
    
    if (!signer || !contract) {
      toast.error('Failed to get contract instance');
      return;
    }

    setPurchasing(true);

    try {
      const contractWithSigner = contract.connect(signer);
      const tx = await (contractWithSigner as any).purchaseTokens({
        value: amount,
      }) as any;

      // Add transaction to store
      addTransaction({
        hash: tx.hash,
        type: TransactionType.PURCHASE,
        status: TransactionStatus.PENDING,
        data: { amount, crowdsale: currentCrowdsale },
      });

      toast.success(SUCCESS_MESSAGES.TRANSACTION_SENT);

      // Wait for confirmation
      const receipt = await tx.wait();

      if (receipt?.status === 1) {
        updateTransaction(tx.hash, {
          status: TransactionStatus.CONFIRMED,
          gasUsed: receipt.gasUsed,
        });
        toast.success(SUCCESS_MESSAGES.PURCHASE_SUCCESSFUL);
        
        // Refresh data
        await fetchCrowdsaleData();
      } else {
        updateTransaction(tx.hash, {
          status: TransactionStatus.FAILED,
          error: 'Transaction failed',
        });
        toast.error(ERROR_MESSAGES.TRANSACTION_FAILED);
      }
    } catch (error: any) {
      console.error('Purchase failed:', error);
      
      let errorMessage: string = ERROR_MESSAGES.TRANSACTION_FAILED;
      if (error.message?.includes('insufficient funds')) {
        errorMessage = ERROR_MESSAGES.INSUFFICIENT_BALANCE;
      } else if (error.message?.includes('not whitelisted')) {
        errorMessage = ERROR_MESSAGES.NOT_WHITELISTED;
      } else if (error.message?.includes('hard cap')) {
        errorMessage = ERROR_MESSAGES.HARD_CAP_REACHED;
      }
      
      toast.error(errorMessage);
    } finally {
      setPurchasing(false);
    }
  }, [
    isConnected,
    address,
    canPurchase,
    getSigner,
    getCrowdsaleContract,
    currentCrowdsale,
    setPurchasing,
    addTransaction,
    updateTransaction,
    fetchCrowdsaleData,
  ]);

  // Check if user is whitelisted
  const checkWhitelistStatus = useCallback(async (userAddress?: string) => {
    const contract = await getCrowdsaleContract();
    if (!contract) return false;

    try {
      const whitelistManagerAddress = await contract.whitelistManager();
      const provider = await getProvider();
      if (!provider) return false;

      const whitelistContract = new Contract(
        whitelistManagerAddress,
        CONTRACT_ABIS.WhitelistManager,
        provider
      );

      const targetAddress = userAddress || address;
      if (!targetAddress) return false;

      return await whitelistContract.isWhitelisted(targetAddress);
    } catch (error) {
      console.error('Failed to check whitelist status:', error);
      return false;
    }
  }, [getCrowdsaleContract, getProvider, address]);

  // Auto-refresh data
  useEffect(() => {
    if (!currentCrowdsale) return;

    // Initial fetch
    fetchCrowdsaleData();

    // Set up interval for auto-refresh
    const interval = setInterval(() => {
      fetchCrowdsaleData();
    }, APP_CONFIG.REFRESH_INTERVAL);

    return () => clearInterval(interval);
  }, [currentCrowdsale, fetchCrowdsaleData]);

  return {
    // State
    crowdsaleAddress: currentCrowdsale,
    config,
    stats,
    phase,
    isLoading,
    isPurchasing,
    
    // Computed values
    fundingProgress: getFundingProgress(),
    remainingTime: getRemainingTime(),
    isActive: isActive(),
    canPurchase: canPurchase(),
    
    // Actions
    fetchCrowdsaleData,
    purchaseTokens,
    checkWhitelistStatus,
    
    // Utils
    getCrowdsaleContract,
  };
};
