import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { useWallet } from '@/hooks/useWallet';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';
import { getTokenPrice } from '@/utils/priceApi';

export interface CrowdsaleProject {
  address: string;
  name: string;
  tokenSymbol: string;
  tokenAddress: string;
  softCap: string;
  hardCap: string;
  startTime: number;
  endTime: number;
  currentPhase: 'PENDING' | 'PRESALE' | 'PUBLIC_SALE' | 'FINALIZED';
  totalRaised: string;
  tokenPrice: number;
  progress: number;
  isActive: boolean;
}

export interface UserCrowdsaleInvestment {
  crowdsaleAddress: string;
  projectName: string;
  tokenSymbol: string;
  ethAmount: string;
  tokenAmount: string;
  investmentDate: number;
  currentValue: string;
  profitLoss: string;
  profitLossPercentage: number;
}

export const useMultiCrowdsale = () => {
  const { getProvider } = useWallet();
  const [projects, setProjects] = useState<CrowdsaleProject[]>([]);
  const [userInvestments, setUserInvestments] = useState<UserCrowdsaleInvestment[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getCrowdsaleContract = useCallback(async (address: string) => {
    const provider = await getProvider();
    if (!provider) throw new Error('No provider available');
    
    const abi = getContractABI('TokenCrowdsale');
    return new ethers.Contract(address, abi, provider);
  }, [getProvider]);

  const getTokenContract = useCallback(async (address: string) => {
    const provider = await getProvider();
    if (!provider) throw new Error('No provider available');
    
    const abi = getContractABI('CrowdsaleToken');
    return new ethers.Contract(address, abi, provider);
  }, [getProvider]);

  const fetchProjectDetails = useCallback(async (crowdsaleAddress: string): Promise<CrowdsaleProject | null> => {
    try {
      const crowdsaleContract = await getCrowdsaleContract(crowdsaleAddress);
      
      // 获取基本信息
      const [config, stats, currentPhase, tokenAddress] = await Promise.all([
        crowdsaleContract.getCrowdsaleConfig(),
        crowdsaleContract.getCrowdsaleStats(),
        crowdsaleContract.getCurrentPhase(),
        crowdsaleContract.token()
      ]);

      // 获取代币信息
      const tokenContract = await getTokenContract(tokenAddress);
      const [tokenName, tokenSymbol] = await Promise.all([
        tokenContract.name(),
        tokenContract.symbol()
      ]);

      // 获取代币价格
      const tokenPrice = await getTokenPrice(tokenAddress);

      // 计算进度
      const totalRaised = parseFloat(ethers.formatEther(stats.totalRaised));
      const hardCap = parseFloat(ethers.formatEther(config.hardCap));
      const progress = hardCap > 0 ? (totalRaised / hardCap) * 100 : 0;

      // 转换阶段枚举
      const phaseNames = ['PENDING', 'PRESALE', 'PUBLIC_SALE', 'FINALIZED'];
      const phaseName = phaseNames[currentPhase] || 'PENDING';

      return {
        address: crowdsaleAddress,
        name: tokenName,
        tokenSymbol,
        tokenAddress,
        softCap: ethers.formatEther(config.softCap),
        hardCap: ethers.formatEther(config.hardCap),
        startTime: Number(config.startTime),
        endTime: Number(config.endTime),
        currentPhase: phaseName as any,
        totalRaised: ethers.formatEther(stats.totalRaised),
        tokenPrice: tokenPrice.priceUSD,
        progress,
        isActive: currentPhase < 3 && Date.now() / 1000 < Number(config.endTime)
      };
    } catch (error) {
      console.error(`Failed to fetch project details for ${crowdsaleAddress}:`, error);
      return null;
    }
  }, [getCrowdsaleContract, getTokenContract]);

  const fetchUserInvestments = useCallback(async (userAddress: string, crowdsaleAddresses: string[]) => {
    if (!userAddress || crowdsaleAddresses.length === 0) {
      setUserInvestments([]);
      return;
    }

    try {
      const investments: UserCrowdsaleInvestment[] = [];

      for (const crowdsaleAddress of crowdsaleAddresses) {
        try {
          const crowdsaleContract = await getCrowdsaleContract(crowdsaleAddress);
          
          // 获取用户购买历史
          const totalPurchased = await crowdsaleContract.totalPurchased(userAddress);
          
          if (totalPurchased > 0) {
            // 获取项目详情
            const project = await fetchProjectDetails(crowdsaleAddress);
            if (!project) continue;

            // 获取用户购买记录
            const purchaseHistory = await crowdsaleContract.getUserPurchaseHistory(userAddress);
            
            let totalEthAmount = 0;
            let totalTokenAmount = 0;
            let latestDate = 0;

            for (const record of purchaseHistory) {
              totalEthAmount += parseFloat(ethers.formatEther(record.weiAmount));
              totalTokenAmount += parseFloat(ethers.formatEther(record.tokenAmount));
              latestDate = Math.max(latestDate, Number(record.timestamp));
            }

            // 计算当前价值和盈亏
            const currentValue = totalTokenAmount * project.tokenPrice;
            const profitLoss = currentValue - totalEthAmount;
            const profitLossPercentage = totalEthAmount > 0 ? (profitLoss / totalEthAmount) * 100 : 0;

            investments.push({
              crowdsaleAddress,
              projectName: project.name,
              tokenSymbol: project.tokenSymbol,
              ethAmount: totalEthAmount.toFixed(4),
              tokenAmount: totalTokenAmount.toFixed(4),
              investmentDate: latestDate,
              currentValue: currentValue.toFixed(2),
              profitLoss: profitLoss.toFixed(2),
              profitLossPercentage
            });
          }
        } catch (error) {
          console.error(`Failed to fetch investments for ${crowdsaleAddress}:`, error);
        }
      }

      setUserInvestments(investments);
    } catch (error) {
      console.error('Failed to fetch user investments:', error);
      handleContractError(error);
    }
  }, [getCrowdsaleContract, fetchProjectDetails]);

  const fetchAllProjects = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      // 由于CrowdsaleFactory未部署，我们使用已知的众筹合约地址
      const knownCrowdsales = [
        getContractAddress('TOKENCROWDSALE')
      ].filter(Boolean);

      if (knownCrowdsales.length === 0) {
        setProjects([]);
        setLoading(false);
        return;
      }

      const projectPromises = knownCrowdsales.map(address => fetchProjectDetails(address as string));
      const projectResults = await Promise.all(projectPromises);
      
      const validProjects = projectResults.filter(project => project !== null) as CrowdsaleProject[];
      setProjects(validProjects);

    } catch (error) {
      console.error('Failed to fetch projects:', error);
      setError('Failed to fetch crowdsale projects');
      handleContractError(error);
    } finally {
      setLoading(false);
    }
  }, [fetchProjectDetails]);

  const refreshData = useCallback(async (userAddress?: string) => {
    await fetchAllProjects();
    
    if (userAddress && projects.length > 0) {
      const crowdsaleAddresses = projects.map(p => p.address);
      await fetchUserInvestments(userAddress, crowdsaleAddresses);
    }
  }, [fetchAllProjects, fetchUserInvestments, projects]);

  useEffect(() => {
    fetchAllProjects();
  }, [fetchAllProjects]);

  return {
    projects,
    userInvestments,
    loading,
    error,
    refreshData,
    fetchUserInvestments: (userAddress: string) => {
      const crowdsaleAddresses = projects.map(p => p.address);
      return fetchUserInvestments(userAddress, crowdsaleAddresses);
    }
  };
};
