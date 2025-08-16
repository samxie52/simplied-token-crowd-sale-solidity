import { parseEther, Contract, ethers } from 'ethers';
import { useCallback, useEffect, useState } from 'react';
import { toast } from 'react-hot-toast';
import { useWallet } from './useWallet';
import { useCrowdsaleStore } from '@/stores/crowdsaleStore';
import { useWalletStore } from '@/stores/walletStore';
import { CrowdsaleConfig, CrowdsaleStats, CrowdsalePhase } from '@/types/contracts';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';
import { TransactionType, TransactionStatus } from '@/types/wallet';

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

    const contractAddress = address || currentCrowdsale || getContractAddress('TOKENCROWDSALE');
    if (!contractAddress) {
      console.warn('No crowdsale contract address available');
      return null;
    }

    const abi = getContractABI('TokenCrowdsale');
    return new ethers.Contract(contractAddress, abi, provider);
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
      console.log('Fetching crowdsale data from contract...');
      
      const [currentConfig, currentStats, currentPhase] = await Promise.all([
        contract.getCrowdsaleConfig(),
        contract.getCrowdsaleStats(),
        contract.getCurrentPhase(),
      ]);

      console.log('Raw contract data:', { currentConfig, currentStats, currentPhase });

      // Parse config - ethers v6 returns struct objects directly
      const parsedConfig: CrowdsaleConfig = {
        presaleStartTime: BigInt(currentConfig.presaleStartTime.toString()),
        presaleEndTime: BigInt(currentConfig.presaleEndTime.toString()),
        publicSaleStartTime: BigInt(currentConfig.publicSaleStartTime.toString()),
        publicSaleEndTime: BigInt(currentConfig.publicSaleEndTime.toString()),
        softCap: BigInt(currentConfig.softCap.toString()),
        hardCap: BigInt(currentConfig.hardCap.toString()),
        minPurchase: BigInt(currentConfig.minPurchase.toString()),
        maxPurchase: BigInt(currentConfig.maxPurchase.toString()),
      };

      // Parse stats - ethers v6 returns struct objects directly
      const parsedStats: CrowdsaleStats = {
        totalRaised: BigInt(currentStats.totalRaised.toString()),
        totalTokensSold: BigInt(currentStats.totalTokensSold.toString()),
        totalPurchases: BigInt(currentStats.totalPurchases.toString()),
        totalParticipants: BigInt(currentStats.totalParticipants.toString()),
        participantCount: BigInt(currentStats.participantCount.toString()),
        presaleRaised: BigInt(currentStats.presaleRaised.toString()),
        publicSaleRaised: BigInt(currentStats.publicSaleRaised.toString()),
      };

      console.log('Parsed data:', { parsedConfig, parsedStats, currentPhase });

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
      toast.error('加载众筹数据失败: ' + handleContractError(error));
    } finally {
      if (useLocalState) {
        setLocalLoading(false);
      } else {
        setLoading(false);
      }
    }
  }, [getCrowdsaleContract, setLoading, setConfig, setStats, setPhase, useLocalState]);

  // Purchase tokens
  const purchaseTokens = useCallback(async (amount: string) => {
    console.log('purchaseTokens called with amount:', amount);
    
    if (!isConnected || !address) {
      console.log('Wallet not connected');
      toast.error('请先连接钱包');
      return;
    }

    // Validate input amount
    if (!amount || amount.trim() === '' || isNaN(Number(amount)) || Number(amount) <= 0) {
      console.log('Invalid amount provided:', amount);
      toast.error('请输入有效的购买金额');
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
    
    // Check if purchase amount would exceed hard cap
    const weiAmount = parseEther(amount);
    const wouldExceedHardCap = currentStats.totalRaised + weiAmount > currentConfig.hardCap;
    
    if (!isActivePhase) {
      console.log('Cannot purchase - not in active phase:', currentPhase);
      toast.error('众筹未激活或已结束');
      return;
    }
    
    if (!hasNotReachedHardCap || wouldExceedHardCap) {
      console.log('Cannot purchase - hard cap reached or would be exceeded');
      toast.error('众筹已达到硬顶或购买金额将超过硬顶限制');
      return;
    }
    
    // Validate purchase amount against min/max limits
    if (weiAmount < currentConfig.minPurchase) {
      console.log('Purchase amount below minimum:', amount);
      const minEth = ethers.formatEther(currentConfig.minPurchase);
      toast.error(`购买金额不能低于最小限制: ${minEth} ETH`);
      return;
    }
    
    if (weiAmount > currentConfig.maxPurchase) {
      console.log('Purchase amount above maximum:', amount);
      const maxEth = ethers.formatEther(currentConfig.maxPurchase);
      toast.error(`购买金额不能超过最大限制: ${maxEth} ETH`);
      return;
    }

    console.log('Getting signer and contract...');
    const signer = await getSigner();
    const contract = await getCrowdsaleContract(crowdsaleAddress);
    
    if (!signer || !contract) {
      console.log('Failed to get signer or contract');
      toast.error('获取合约实例失败');
      return;
    }

    console.log('Setting purchasing state...');
    setPurchasing(true);

    try {
      // Use the already calculated weiAmount from validation above
      const canPurchaseResult = await contract.canPurchase(address, weiAmount);
      
      if (!canPurchaseResult) {
        toast.error('购买验证失败，请检查购买条件');
        return;
      }

      const contractWithSigner = contract.connect(signer);
      
      // Call purchaseTokens function with ETH value
      const tx = await contractWithSigner.purchaseTokens({
        value: weiAmount,
        gasLimit: 300000 // Set reasonable gas limit
      });

      // Add transaction to store
      addTransaction({
        hash: tx.hash,
        type: TransactionType.TOKEN_PURCHASE,
        status: TransactionStatus.PENDING,
        amount: amount,
        timestamp: Date.now()
      });
      
      console.log('Transaction sent:', tx.hash);
      toast.success('交易已发送，等待确认...');

      // Wait for confirmation
      const receipt = await tx.wait();

      if (receipt?.status === 1) {
        console.log('Transaction confirmed');
        
        // Update transaction status
        updateTransaction(tx.hash, {
          status: TransactionStatus.SUCCESS,
          gasUsed: receipt.gasUsed?.toString()
        });
        
        toast.success('购买成功！代币已发送到您的钱包');
        
        // Refresh data
        await fetchCrowdsaleData(crowdsaleAddress);
      } else {
        console.log('Transaction failed');
        updateTransaction(tx.hash, {
          status: TransactionStatus.FAILED
        });
        toast.error('交易失败');
      }
    } catch (error: any) {
      console.error('Purchase failed:', error);
      
      let errorMessage = handleContractError(error);
      
      // Handle specific error cases
      if (error.message?.includes('insufficient funds')) {
        errorMessage = '余额不足，请检查您的ETH余额';
      } else if (error.message?.includes('not whitelisted')) {
        errorMessage = '预售阶段需要白名单权限';
      } else if (error.message?.includes('hard cap')) {
        errorMessage = '已达到硬顶，无法继续购买';
      } else if (error.message?.includes('exceeds hard cap')) {
        errorMessage = '购买金额超过硬顶限制';
      } else if (error.message?.includes('invalid purchase')) {
        errorMessage = '购买金额不符合要求';
      } else if (error.message?.includes('user rejected') || error.code === 'ACTION_REJECTED') {
        errorMessage = '用户取消了交易';
      } else if (error.message?.includes('purchase cooldown')) {
        errorMessage = '购买冷却时间未到，请稍后再试';
      } else if (error.message?.includes('sale not active')) {
        errorMessage = '众筹销售未激活';
      } else if (error.message?.includes('paused')) {
        errorMessage = '众筹已暂停';
      }
      
      toast.error(errorMessage);
    } finally {
      setPurchasing(false);
    }
  }, [
    isConnected,
    address,
    useLocalState,
    localPhase,
    localStats,
    localConfig,
    phase,
    stats,
    config,
    getSigner,
    getCrowdsaleContract,
    crowdsaleAddress,
    setPurchasing,
    addTransaction,
    updateTransaction,
    fetchCrowdsaleData,
  ]);

  // Check if user is whitelisted
  const checkWhitelistStatus = useCallback(async (userAddress?: string) => {
    const contract = await getCrowdsaleContract();
    if (!contract) return { isWhitelisted: false, tier: 'NONE' as const, discount: 0 };

    try {
      const whitelistManagerAddress = await contract.whitelistManager();
      const provider = await getProvider();
      if (!provider) return { isWhitelisted: false, tier: 'NONE' as const, discount: 0 };

      const whitelistABI = getContractABI('WhitelistManager');
      const whitelistContract = new ethers.Contract(whitelistManagerAddress, whitelistABI, provider);

      const targetAddress = userAddress || address;
      if (!targetAddress) return { isWhitelisted: false, tier: 'NONE' as const, discount: 0 };

      const [isWhitelisted, isVIP] = await Promise.all([
        whitelistContract.isWhitelisted(targetAddress),
        whitelistContract.isVIP(targetAddress)
      ]);

      if (isVIP) {
        return { isWhitelisted: true, tier: 'VIP' as const, discount: 20 };
      } else if (isWhitelisted) {
        return { isWhitelisted: true, tier: 'WHITELISTED' as const, discount: 10 };
      } else {
        return { isWhitelisted: false, tier: 'NONE' as const, discount: 0 };
      }
    } catch (error) {
      console.error('Failed to check whitelist status:', error);
      return { isWhitelisted: false, tier: 'NONE' as const, discount: 0 };
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
