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
        console.warn(`No contract found at address: ${crowdsaleAddress}`);
        setConfig(null);
        setStats(null);
        setPhase(null);
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
      // Set to null on error instead of using demo data
      setConfig(null);
      setStats(null);
      setPhase(null);
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
