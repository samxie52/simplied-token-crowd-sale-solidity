import { useState, useEffect, useCallback } from 'react';
import { ethers, formatEther } from 'ethers';
import { useWallet } from './useWallet';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';

interface CrowdsaleData {
  address: string;
  name: string;
  status: 'active' | 'paused' | 'finalized';
  phase: number;
  raised: string;
  target: string;
  participants: number;
  startTime: number;
  endTime: number;
  isPaused: boolean;
}

export const useCrowdsaleManagement = () => {
  const { getSigner, getProvider } = useWallet();
  const [crowdsales, setCrowdsales] = useState<CrowdsaleData[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getCrowdsaleContract = useCallback(async (address?: string) => {
    const contractAddress = address || getContractAddress('TOKENCROWDSALE');
    if (!contractAddress) {
      throw new Error('TokenCrowdsale contract address not configured. Please set VITE_TOKENCROWDSALE_ADDRESS in .env.local');
    }
    
    const abi = getContractABI('TokenCrowdsale');
    
    // Try to get signer first, fallback to provider
    let runner;
    try {
      runner = await getSigner();
    } catch {
      runner = await getProvider();
    }
    
    if (!runner) throw new Error('No wallet connection found');
    
    return new ethers.Contract(contractAddress, abi, runner);
  }, [getSigner, getProvider]);

  const getFactoryContract = useCallback(async () => {
    const contractAddress = getContractAddress('CROWDSALEFACTORY');
    if (!contractAddress) {
      throw new Error('CrowdsaleFactory contract address not configured. Please set VITE_CROWDSALEFACTORY_ADDRESS in .env.local');
    }
    
    const abi = getContractABI('CrowdsaleFactory');
    
    // Try to get signer first, fallback to provider
    let runner;
    try {
      runner = await getSigner();
    } catch {
      runner = await getProvider();
    }
    
    if (!runner) throw new Error('No wallet connection found');
    
    return new ethers.Contract(contractAddress, abi, runner);
  }, [getSigner, getProvider]);

  // 获取众筹列表
  const fetchCrowdsales = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      // 目前只获取主要的众筹合约
      const mainCrowdsaleAddress = getContractAddress('TOKENCROWDSALE');
      if (!mainCrowdsaleAddress) {
        throw new Error('Main crowdsale address not found');
      }

      const contract = await getCrowdsaleContract(mainCrowdsaleAddress);
      
      const [config, stats, isPaused, currentPhase] = await Promise.all([
        contract.getCrowdsaleConfig().catch(() => ({
          presaleStartTime: 0n,
          presaleEndTime: 0n,
          publicSaleStartTime: 0n,
          publicSaleEndTime: 0n,
          softCap: 0n,
          hardCap: ethers.parseEther("1000"),
          minPurchase: ethers.parseEther("0.01"),
          maxPurchase: ethers.parseEther("10")
        })),
        contract.getCrowdsaleStats().catch(() => ({
          totalRaised: 0n,
          totalTokensSold: 0n,
          totalPurchases: 0n,
          totalParticipants: 0n,
          participantCount: 0n,
          presaleRaised: 0n,
          publicSaleRaised: 0n
        })),
        contract.paused().catch(() => false),
        contract.getCurrentPhase().catch(() => 0)
      ]);

      const crowdsaleData: CrowdsaleData = {
        address: mainCrowdsaleAddress,
        name: 'Main Token Crowdsale',
        status: isPaused ? 'paused' : (currentPhase === 3 ? 'finalized' : 'active'),
        phase: Number(currentPhase),
        raised: formatEther(stats.totalRaised),
        target: formatEther(config.hardCap),
        participants: Number(stats.totalParticipants),
        startTime: Number(config.presaleStartTime),
        endTime: Number(config.publicSaleEndTime),
        isPaused
      };

      setCrowdsales([crowdsaleData]);
    } catch (error) {
      console.error('Failed to fetch crowdsale data:', error);
      setError(handleContractError(error));
    } finally {
      setLoading(false);
    }
  }, [getCrowdsaleContract]);

  // 暂停众筹
  const pauseCrowdsale = useCallback(async (address: string) => {
    try {
      const contract = await getCrowdsaleContract(address);
      const tx = await contract.emergencyPause("Admin pause via web interface");
      await tx.wait();
      
      // 更新本地状态
      setCrowdsales(prev => prev.map(cs => 
        cs.address === address ? { ...cs, status: 'paused', isPaused: true } : cs
      ));
      
      return { success: true, txHash: tx.hash };
    } catch (error) {
      throw new Error(handleContractError(error));
    }
  }, [getCrowdsaleContract]);

  // 恢复众筹
  const resumeCrowdsale = useCallback(async (address: string) => {
    try {
      const contract = await getCrowdsaleContract(address);
      const tx = await contract.emergencyResume("Admin resume via web interface");
      await tx.wait();
      
      // 更新本地状态
      setCrowdsales(prev => prev.map(cs => 
        cs.address === address ? { ...cs, status: 'active', isPaused: false } : cs
      ));
      
      return { success: true, txHash: tx.hash };
    } catch (error) {
      throw new Error(handleContractError(error));
    }
  }, [getCrowdsaleContract]);

  // 结束众筹
  const finalizeCrowdsale = useCallback(async (address: string) => {
    try {
      const contract = await getCrowdsaleContract(address);
      const tx = await contract.finalizeCrowdsale();
      await tx.wait();
      
      // 更新本地状态
      setCrowdsales(prev => prev.map(cs => 
        cs.address === address ? { ...cs, status: 'finalized', phase: 3 } : cs
      ));
      
      return { success: true, txHash: tx.hash };
    } catch (error) {
      throw new Error(handleContractError(error));
    }
  }, [getCrowdsaleContract]);

  useEffect(() => {
    fetchCrowdsales();
    
    // 设置定时刷新
    const interval = setInterval(fetchCrowdsales, 30000); // 30秒刷新一次
    return () => clearInterval(interval);
  }, [fetchCrowdsales]);

  return {
    crowdsales,
    loading,
    error,
    refreshCrowdsales: fetchCrowdsales,
    pauseCrowdsale,
    resumeCrowdsale,
    finalizeCrowdsale
  };
};
