import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { useWallet } from './useWallet';
import { CONTRACTS } from '../utils/contracts';

// Types based on the interface definitions
export interface CrowdsaleInstance {
  crowdsaleAddress: string;
  tokenAddress: string;
  vestingAddress: string;
  creator: string;
  createdAt: bigint;
  isActive: boolean;
}

export interface FactoryStats {
  totalCrowdsales: bigint;
  activeCrowdsales: bigint;
  totalFeesCollected: bigint;
}

export interface CrowdsaleParams {
  tokenName: string;
  tokenSymbol: string;
  totalSupply: bigint;
  softCap: bigint;
  hardCap: bigint;
  startTime: bigint;
  endTime: bigint;
  fundingWallet: string;
  tokenPrice: bigint;
  vestingParams: {
    enabled: boolean;
    cliffDuration: bigint;
    vestingDuration: bigint;
    vestingType: number;
    immediateReleasePercentage: bigint;
  };
}

export interface UseCrowdsaleFactoryReturn {
  // State
  activeCrowdsales: CrowdsaleInstance[];
  factoryStats: FactoryStats | null;
  creatorCrowdsales: CrowdsaleInstance[];
  isLoading: boolean;
  error: string | null;
  
  // Actions
  fetchActiveCrowdsales: () => Promise<void>;
  fetchFactoryStats: () => Promise<void>;
  fetchCreatorCrowdsales: (creator: string) => Promise<void>;
  createCrowdsale: (params: CrowdsaleParams) => Promise<{ crowdsaleAddress: string; tokenAddress: string; vestingAddress: string } | null>;
  validateCrowdsaleParams: (params: CrowdsaleParams) => Promise<{ isValid: boolean; errorMessage: string } | null>;
  refreshAll: () => Promise<void>;
}

export function useCrowdsaleFactory(): UseCrowdsaleFactoryReturn {
  const { provider, signer, account } = useWallet();
  
  // State
  const [activeCrowdsales, setActiveCrowdsales] = useState<CrowdsaleInstance[]>([]);
  const [factoryStats, setFactoryStats] = useState<FactoryStats | null>(null);
  const [creatorCrowdsales, setCreatorCrowdsales] = useState<CrowdsaleInstance[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Get factory contract instance
  const getFactoryContract = useCallback(() => {
    const factoryAddress = import.meta.env.VITE_CROWDSALE_FACTORY_ADDRESS;
    if (!factoryAddress || !provider) {
      throw new Error('CrowdsaleFactory address not configured or provider not available');
    }
    
    return new ethers.Contract(
      factoryAddress,
      CONTRACTS.CrowdsaleFactory,
      signer || provider
    );
  }, [provider, signer]);

  // Helper function to safely convert BigInt to string for logging
  const safeStringify = (obj: any): string => {
    return JSON.stringify(obj, (key, value) =>
      typeof value === 'bigint' ? value.toString() : value
    );
  };

  // Fetch active crowdsales
  const fetchActiveCrowdsales = useCallback(async () => {
    try {
      setError(null);
      const contract = getFactoryContract();
      
      console.log('Fetching active crowdsales...');
      const result = await contract.getActiveCrowdsales();
      
      const crowdsales: CrowdsaleInstance[] = result.map((item: any) => ({
        crowdsaleAddress: item.crowdsaleAddress || item[0],
        tokenAddress: item.tokenAddress || item[1],
        vestingAddress: item.vestingAddress || item[2],
        creator: item.creator || item[3],
        createdAt: BigInt(item.createdAt?.toString() || item[4]?.toString() || '0'),
        isActive: item.isActive !== undefined ? item.isActive : item[5]
      }));
      
      console.log('Active crowdsales fetched:', safeStringify(crowdsales));
      setActiveCrowdsales(crowdsales);
    } catch (err) {
      console.error('Error fetching active crowdsales:', err);
      setError(err instanceof Error ? err.message : '获取活跃众筹列表失败');
    }
  }, [getFactoryContract]);

  // Fetch factory statistics
  const fetchFactoryStats = useCallback(async () => {
    try {
      setError(null);
      const contract = getFactoryContract();
      
      console.log('Fetching factory stats...');
      const result = await contract.getFactoryStats();
      
      const stats: FactoryStats = {
        totalCrowdsales: BigInt(result.totalCrowdsales?.toString() || result[0]?.toString() || '0'),
        activeCrowdsales: BigInt(result.activeCrowdsales?.toString() || result[1]?.toString() || '0'),
        totalFeesCollected: BigInt(result.totalFeesCollected?.toString() || result[2]?.toString() || '0')
      };
      
      console.log('Factory stats fetched:', safeStringify(stats));
      setFactoryStats(stats);
    } catch (err) {
      console.error('Error fetching factory stats:', err);
      setError(err instanceof Error ? err.message : '获取平台统计失败');
    }
  }, [getFactoryContract]);

  // Fetch crowdsales by creator
  const fetchCreatorCrowdsales = useCallback(async (creator: string) => {
    try {
      setError(null);
      const contract = getFactoryContract();
      
      console.log('Fetching creator crowdsales for:', creator);
      const result = await contract.getCreatorCrowdsales(creator);
      
      const crowdsales: CrowdsaleInstance[] = result.map((item: any) => ({
        crowdsaleAddress: item.crowdsaleAddress || item[0],
        tokenAddress: item.tokenAddress || item[1],
        vestingAddress: item.vestingAddress || item[2],
        creator: item.creator || item[3],
        createdAt: BigInt(item.createdAt?.toString() || item[4]?.toString() || '0'),
        isActive: item.isActive !== undefined ? item.isActive : item[5]
      }));
      
      console.log('Creator crowdsales fetched:', safeStringify(crowdsales));
      setCreatorCrowdsales(crowdsales);
    } catch (err) {
      console.error('Error fetching creator crowdsales:', err);
      setError(err instanceof Error ? err.message : '获取创建者众筹列表失败');
    }
  }, [getFactoryContract]);

  // Create new crowdsale
  const createCrowdsale = useCallback(async (params: CrowdsaleParams) => {
    if (!signer) {
      setError('请先连接钱包');
      return null;
    }

    try {
      setError(null);
      setIsLoading(true);
      
      const contract = getFactoryContract();
      
      // Get creation fee
      const creationFee = await contract.getCreationFee();
      
      console.log('Creating crowdsale with params:', safeStringify(params));
      console.log('Creation fee:', creationFee.toString());
      
      // Prepare the struct for the contract call
      const crowdsaleParams = {
        tokenName: params.tokenName,
        tokenSymbol: params.tokenSymbol,
        totalSupply: params.totalSupply,
        softCap: params.softCap,
        hardCap: params.hardCap,
        startTime: params.startTime,
        endTime: params.endTime,
        fundingWallet: params.fundingWallet,
        tokenPrice: params.tokenPrice,
        vestingParams: {
          enabled: params.vestingParams.enabled,
          cliffDuration: params.vestingParams.cliffDuration,
          vestingDuration: params.vestingParams.vestingDuration,
          vestingType: params.vestingParams.vestingType,
          immediateReleasePercentage: params.vestingParams.immediateReleasePercentage
        }
      };
      
      const tx = await contract.createCrowdsale(crowdsaleParams, {
        value: creationFee,
        gasLimit: 3000000 // Set a reasonable gas limit
      });
      
      console.log('Transaction sent:', tx.hash);
      const receipt = await tx.wait();
      console.log('Transaction confirmed:', receipt);
      
      // Parse the return values from the transaction receipt
      const event = receipt.logs.find((log: any) => {
        try {
          const parsed = contract.interface.parseLog(log);
          return parsed?.name === 'CrowdsaleCreated';
        } catch {
          return false;
        }
      });
      
      if (event) {
        const parsed = contract.interface.parseLog(event);
        return {
          crowdsaleAddress: parsed.args.crowdsaleAddress,
          tokenAddress: parsed.args.tokenAddress,
          vestingAddress: parsed.args.vestingAddress
        };
      }
      
      // Fallback: try to get addresses from transaction result
      return {
        crowdsaleAddress: receipt.logs[0]?.address || '',
        tokenAddress: receipt.logs[1]?.address || '',
        vestingAddress: receipt.logs[2]?.address || ''
      };
      
    } catch (err) {
      console.error('Error creating crowdsale:', err);
      setError(err instanceof Error ? err.message : '创建众筹失败');
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [signer, getFactoryContract]);

  // Validate crowdsale parameters
  const validateCrowdsaleParams = useCallback(async (params: CrowdsaleParams) => {
    try {
      setError(null);
      const contract = getFactoryContract();
      
      const crowdsaleParams = {
        tokenName: params.tokenName,
        tokenSymbol: params.tokenSymbol,
        totalSupply: params.totalSupply,
        softCap: params.softCap,
        hardCap: params.hardCap,
        startTime: params.startTime,
        endTime: params.endTime,
        fundingWallet: params.fundingWallet,
        tokenPrice: params.tokenPrice,
        vestingParams: {
          enabled: params.vestingParams.enabled,
          cliffDuration: params.vestingParams.cliffDuration,
          vestingDuration: params.vestingParams.vestingDuration,
          vestingType: params.vestingParams.vestingType,
          immediateReleasePercentage: params.vestingParams.immediateReleasePercentage
        }
      };
      
      const result = await contract.validateCrowdsaleParams(crowdsaleParams);
      
      return {
        isValid: result.isValid || result[0],
        errorMessage: result.errorMessage || result[1] || ''
      };
    } catch (err) {
      console.error('Error validating crowdsale params:', err);
      setError(err instanceof Error ? err.message : '参数验证失败');
      return null;
    }
  }, [getFactoryContract]);

  // Refresh all data
  const refreshAll = useCallback(async () => {
    setIsLoading(true);
    try {
      await Promise.all([
        fetchActiveCrowdsales(),
        fetchFactoryStats()
      ]);
    } finally {
      setIsLoading(false);
    }
  }, [fetchActiveCrowdsales, fetchFactoryStats]);

  // Auto-fetch data on mount and when provider changes
  useEffect(() => {
    if (provider) {
      refreshAll();
    }
  }, [provider, refreshAll]);

  return {
    // State
    activeCrowdsales,
    factoryStats,
    creatorCrowdsales,
    isLoading,
    error,
    
    // Actions
    fetchActiveCrowdsales,
    fetchFactoryStats,
    fetchCreatorCrowdsales,
    createCrowdsale,
    validateCrowdsaleParams,
    refreshAll
  };
}
