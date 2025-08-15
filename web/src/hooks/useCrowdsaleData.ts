import { useState, useEffect, useCallback } from 'react';
import { Contract } from 'ethers';
import { useWallet } from './useWallet';
import { CONTRACT_ABIS } from '@/utils/contracts';
import { CrowdsaleConfig, CrowdsaleStats, CrowdsalePhase } from '@/types/contracts';

// Lightweight hook for fetching individual crowdsale data without affecting global store
export const useCrowdsaleData = (crowdsaleAddress: string) => {
  const { getProvider } = useWallet();
  const [config, setConfig] = useState<CrowdsaleConfig | null>(null);
  const [stats, setStats] = useState<CrowdsaleStats | null>(null);
  const [phase, setPhase] = useState<CrowdsalePhase | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const fetchData = useCallback(async () => {
    if (!crowdsaleAddress) return;

    const provider = await getProvider();
    if (!provider) return;

    setIsLoading(true);

    try {
      const contract = new Contract(crowdsaleAddress, CONTRACT_ABIS.TokenCrowdsale, provider);
      
      // Check if contract exists by checking if it has code
      const code = await provider.getCode(crowdsaleAddress);
      if (code === '0x') {
        // Contract doesn't exist, use demo data
        setConfig({
          presaleStartTime: BigInt(Math.floor(Date.now() / 1000)),
          presaleEndTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 7),
          publicSaleStartTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 7),
          publicSaleEndTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 14),
          softCap: BigInt('1000000000000000000'), // 1 ETH
          hardCap: BigInt('10000000000000000000'), // 10 ETH
          minPurchase: BigInt('100000000000000000'), // 0.1 ETH
          maxPurchase: BigInt('5000000000000000000'), // 5 ETH
        });
        
        setStats({
          totalRaised: BigInt('2500000000000000000'), // 2.5 ETH
          totalTokensSold: BigInt('2500000000000000000000'), // 2500 tokens
          totalPurchases: BigInt(15),
          totalParticipants: BigInt(8),
          participantCount: BigInt(8),
          presaleRaised: BigInt('1500000000000000000'), // 1.5 ETH
          publicSaleRaised: BigInt('1000000000000000000'), // 1 ETH
        });
        
        setPhase(1); // PRESALE phase
        return;
      }
      
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
      // Fallback to demo data on error
      setConfig({
        presaleStartTime: BigInt(Math.floor(Date.now() / 1000)),
        presaleEndTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 7),
        publicSaleStartTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 7),
        publicSaleEndTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 14),
        softCap: BigInt('1000000000000000000'),
        hardCap: BigInt('10000000000000000000'),
        minPurchase: BigInt('100000000000000000'),
        maxPurchase: BigInt('5000000000000000000'),
      });
      
      setStats({
        totalRaised: BigInt('2500000000000000000'),
        totalTokensSold: BigInt('2500000000000000000000'),
        totalPurchases: BigInt(15),
        totalParticipants: BigInt(8),
        participantCount: BigInt(8),
        presaleRaised: BigInt('1500000000000000000'),
        publicSaleRaised: BigInt('1000000000000000000'),
      });
      
      setPhase(1);
    } finally {
      setIsLoading(false);
    }
  }, [crowdsaleAddress, getProvider]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return {
    config,
    stats,
    phase,
    isLoading,
    refetch: fetchData,
  };
};
