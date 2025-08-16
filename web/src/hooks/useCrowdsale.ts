import { parseEther, Contract } from 'ethers';
import { useCallback, useEffect, useState } from 'react';
import { toast } from 'react-hot-toast';
import { useWallet } from './useWallet';
import { useCrowdsaleStore } from '@/stores/crowdsaleStore';
import { useWalletStore } from '@/stores/walletStore';
import { CrowdsaleConfig, CrowdsaleStats, CrowdsalePhase } from '@/types/contracts';

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

  // Local state for individual crowdsale data (when not using global store)
  const [localConfig, setLocalConfig] = useState<CrowdsaleConfig | null>(null);
  const [localStats, setLocalStats] = useState<CrowdsaleStats | null>(null);
  const [localPhase, setLocalPhase] = useState<CrowdsalePhase | null>(null);
  const [localLoading, setLocalLoading] = useState(false);

  // Use local state when a specific address is provided and it's different from current
  const useLocalState = crowdsaleAddress && crowdsaleAddress !== currentCrowdsale;
  const finalConfig = useLocalState ? localConfig : config;
  const finalStats = useLocalState ? localStats : stats;
  const finalPhase = useLocalState ? localPhase : phase;
  const finalIsLoading = useLocalState ? localLoading : isLoading;

  // Get crowdsale contract instance
  const getCrowdsaleContract = useCallback(async (address?: string) => {
    const provider = await getProvider();
    if (!provider) return null;

    const contractAddress = address || currentCrowdsale;
    if (!contractAddress) return null;

    // For now, return a mock contract object for testing
    return {
      getCrowdsaleConfig: async () => [
        BigInt(Math.floor(Date.now() / 1000) - 3600), // presaleStartTime
        BigInt(Math.floor(Date.now() / 1000) + 3600), // presaleEndTime
        BigInt(Math.floor(Date.now() / 1000) + 7200), // publicSaleStartTime
        BigInt(Math.floor(Date.now() / 1000) + 10800), // publicSaleEndTime
        BigInt('1000000000000000000'), // softCap (1 ETH)
        BigInt('10000000000000000000'), // hardCap (10 ETH)
        BigInt('100000000000000000'), // minPurchase (0.1 ETH)
        BigInt('1000000000000000000'), // maxPurchase (1 ETH)
      ],
      getCrowdsaleStats: async () => [
        BigInt('2000000000000000000'), // totalRaised (2 ETH)
        BigInt('2000000000000000000000'), // totalTokensSold
        BigInt(10), // totalPurchases
        BigInt(5), // totalParticipants
        BigInt(5), // participantCount
        BigInt('1000000000000000000'), // presaleRaised
        BigInt('1000000000000000000'), // publicSaleRaised
      ],
      getCurrentPhase: async () => 1, // PRESALE phase
      whitelistManager: async () => '0x1234567890123456789012345678901234567890',
      connect: (signer: any) => ({
        purchaseTokens: async (options: any) => ({
          hash: '0x' + Math.random().toString(16).substring(2),
          wait: async () => ({ status: 1, gasUsed: BigInt(21000) })
        })
      })
    };
  }, [getProvider, currentCrowdsale]);

  // Fetch crowdsale data
  const fetchCrowdsaleData = useCallback(async (address?: string) => {
    const contract = await getCrowdsaleContract(address);
    if (!contract) return;

    if (useLocalState) {
      setLocalLoading(true);
    } else {
      setLoading(true);
    }

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

      if (useLocalState) {
        setLocalConfig(parsedConfig);
        setLocalStats(parsedStats);
        setLocalPhase(currentPhase as CrowdsalePhase);
      } else {
        setConfig(parsedConfig);
        setStats(parsedStats);
        setPhase(currentPhase as CrowdsalePhase);
      }
    } catch (error) {
      console.error('Failed to fetch crowdsale data:', error);
      toast.error('Failed to load crowdsale data');
    } finally {
      if (useLocalState) {
        setLocalLoading(false);
      } else {
        setLoading(false);
      }
    }
  }, [getCrowdsaleContract, setLoading, setConfig, setStats, setPhase]);

  // Purchase tokens
  const purchaseTokens = useCallback(async (amount: string) => {
    console.log('purchaseTokens called with amount:', amount);
    
    if (!isConnected || !address) {
      console.log('Wallet not connected');
      toast.error('请先连接钱包');
      return;
    }

    // Check if we can purchase using local state when available
    const currentPhase = useLocalState ? localPhase : phase;
    const currentStats = useLocalState ? localStats : stats;
    const currentConfig = useLocalState ? localConfig : config;
    
    console.log('Purchase validation:', {
      currentPhase,
      currentStats,
      currentConfig,
      useLocalState
    });
    
    if (!currentPhase || !currentStats || !currentConfig) {
      console.log('Cannot purchase - missing data');
      toast.error('众筹数据加载中，请稍后再试');
      return;
    }
    
    const isActivePhase = currentPhase === CrowdsalePhase.PRESALE || currentPhase === CrowdsalePhase.PUBLIC_SALE;
    const hasNotReachedHardCap = currentStats.totalRaised < currentConfig.hardCap;
    
    if (!isActivePhase) {
      console.log('Cannot purchase - not in active phase:', currentPhase);
      toast.error('众筹未激活或已结束');
      return;
    }
    
    if (!hasNotReachedHardCap) {
      console.log('Cannot purchase - hard cap reached');
      toast.error('众筹已达到硬顶，无法继续购买');
      return;
    }

    console.log('Getting signer and contract...');
    const signer = await getSigner();
    const contract = await getCrowdsaleContract(crowdsaleAddress);
    
    if (!signer || !contract) {
      console.log('Failed to get signer or contract');
      toast.error('Failed to get contract instance');
      return;
    }

    console.log('Setting purchasing state...');
    setPurchasing(true);

    try {
      const contractWithSigner = contract.connect(signer);
      const tx = await (contractWithSigner as any).purchaseTokens({
        value: parseEther(amount),
      }) as any;

      // Add transaction to store (simplified)
      console.log('Transaction sent:', tx.hash);
      toast.success('交易已发送');

      // Wait for confirmation
      const receipt = await tx.wait();

      if (receipt?.status === 1) {
        console.log('Transaction confirmed');
        toast.success('购买成功！');
        
        // Refresh data
        await fetchCrowdsaleData();
      } else {
        console.log('Transaction failed');
        toast.error('交易失败');
      }
    } catch (error: any) {
      console.error('Purchase failed:', error);
      
      let errorMessage: string = '交易失败';
      if (error.message?.includes('insufficient funds')) {
        errorMessage = '余额不足';
      } else if (error.message?.includes('not whitelisted')) {
        errorMessage = '未通过白名单验证';
      } else if (error.message?.includes('hard cap')) {
        errorMessage = '已达到硬顶';
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

      // Mock whitelist contract for testing
      const whitelistContract = {
        isWhitelisted: async () => true
      };

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
    const targetAddress = crowdsaleAddress || currentCrowdsale;
    if (!targetAddress) return;

    // Initial fetch
    fetchCrowdsaleData(crowdsaleAddress);

    // Set up interval for auto-refresh
    const interval = setInterval(() => {
      fetchCrowdsaleData(crowdsaleAddress);
    }, 30000);

    return () => clearInterval(interval);
  }, [crowdsaleAddress, currentCrowdsale, fetchCrowdsaleData]);

  return {
    // State
    crowdsaleAddress: crowdsaleAddress || currentCrowdsale,
    crowdsaleData: useLocalState ? { config: finalConfig, stats: finalStats, phase: finalPhase } : { config, stats, phase },
    config: finalConfig,
    stats: finalStats,
    phase: finalPhase,
    isLoading: finalIsLoading,
    isPurchasing,
    error: null, // Add error state for CrowdsaleDetail component
    
    // Computed values
    fundingProgress: getFundingProgress(),
    remainingTime: getRemainingTime(),
    isActive: isActive(),
    canPurchase: canPurchase(),
    
    // Actions
    refreshData: () => fetchCrowdsaleData(crowdsaleAddress),
    fetchCrowdsaleData,
    purchaseTokens,
    checkWhitelistStatus,
    
    // Utils
    getCrowdsaleContract,
  };
};
