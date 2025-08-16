import { useState, useEffect, useCallback } from 'react';
import { ethers, formatEther } from 'ethers';
import { useWallet } from '@/hooks/useWallet';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';

export interface UserInvestment {
  crowdsaleAddress: string;
  crowdsaleName: string;
  tokenSymbol: string;
  tokenAddress: string;
  ethAmount: string; // ETH amount
  investedAmount: string; // Same as ethAmount for compatibility
  tokenAmount: string; // Token amount received
  investmentDate: number; // Unix timestamp
  status: 'active' | 'completed' | 'refunded';
  currentValue: string; // Current USD value
  profitLoss: string; // Profit/Loss amount
  profitLossPercentage: number; // Profit/Loss percentage
  transactionHash: string;
}

export const useUserInvestments = (userAddress?: string) => {
  const { getProvider } = useWallet();
  const [investments, setInvestments] = useState<UserInvestment[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getCrowdsaleFactoryContract = useCallback(async () => {
    const contractAddress = getContractAddress('CROWDSALEFACTORY');
    if (!contractAddress) {
      throw new Error('CrowdsaleFactory contract address not configured');
    }
    const abi = getContractABI('CrowdsaleFactory');
    const provider = await getProvider();
    return new ethers.Contract(contractAddress, abi, provider);
  }, [getProvider]);

  const getCrowdsaleContract = useCallback(async (address: string) => {
    const abi = getContractABI('TokenCrowdsale');
    const provider = await getProvider();
    return new ethers.Contract(address, abi, provider);
  }, [getProvider]);

  const getTokenContract = useCallback(async (address: string) => {
    const abi = getContractABI('CrowdsaleToken');
    const provider = await getProvider();
    return new ethers.Contract(address, abi, provider);
  }, [getProvider]);

  const fetchTokenPrice = useCallback(async (tokenAddress: string): Promise<number> => {
    // For demo purposes, return a mock price
    // In production, integrate with price APIs like CoinGecko or DEX prices
    try {
      // Mock price calculation based on token address
      const mockPrices: { [key: string]: number } = {
        'default': 0.1, // Default price in USD
      };
      return mockPrices[tokenAddress.toLowerCase()] || mockPrices.default;
    } catch (error) {
      console.warn('Failed to fetch token price:', error);
      return 0.1; // Fallback price
    }
  }, []);

  const fetchUserInvestments = useCallback(async () => {
    if (!userAddress) {
      setInvestments([]);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Since CrowdsaleFactory is not deployed, work directly with TokenCrowdsale
      const crowdsaleAddress = getContractAddress('TOKENCROWDSALE');
      if (!crowdsaleAddress) {
        console.warn('TokenCrowdsale contract address not configured');
        setInvestments([]);
        setLoading(false);
        return;
      }

      // Work with single crowdsale instead of factory
      const crowdsales = [crowdsaleAddress];
      
      const userInvestments: UserInvestment[] = [];

      // Query each crowdsale for user's investment history
      for (const crowdsaleAddress of crowdsales) {
        try {
          const crowdsaleContract = await getCrowdsaleContract(crowdsaleAddress);
          
          // Get user's purchase history for this crowdsale
          const purchaseHistory = await crowdsaleContract.getUserPurchaseHistory(userAddress);
          
          if (purchaseHistory.length > 0) {
            // Get crowdsale basic info
            const config = await crowdsaleContract.config();
            const tokenContract = await getTokenContract(config.tokenAddress);
            const tokenSymbol = await tokenContract.symbol();
            const tokenName = await tokenContract.name();
            
            // Get current crowdsale phase to determine status
            const currentPhase = await crowdsaleContract.currentPhase();
            const status = currentPhase === 3 ? 'completed' : 'active'; // 3 = FINALIZED
            
            // Calculate total investment for this crowdsale
            let totalInvested = 0n;
            let totalTokens = 0n;
            let latestInvestmentDate = 0;
            let firstTransactionHash = '';

            for (const purchase of purchaseHistory) {
              totalInvested += purchase.ethAmount;
              totalTokens += purchase.tokenAmount;
              if (purchase.timestamp > latestInvestmentDate) {
                latestInvestmentDate = purchase.timestamp;
              }
              if (!firstTransactionHash) {
                firstTransactionHash = purchase.transactionHash || '';
              }
            }

            // Get current token price and calculate values
            const tokenPrice = await fetchTokenPrice(config.tokenAddress);
            const tokenAmountFormatted = parseFloat(formatEther(totalTokens));
            const ethAmountFormatted = parseFloat(formatEther(totalInvested));
            const currentValue = tokenAmountFormatted * tokenPrice;
            const profitLoss = currentValue - ethAmountFormatted;
            const profitLossPercentage = ethAmountFormatted > 0 ? (profitLoss / ethAmountFormatted) * 100 : 0;

            userInvestments.push({
              crowdsaleAddress,
              crowdsaleName: tokenName,
              tokenSymbol,
              tokenAddress: config.tokenAddress,
              ethAmount: ethAmountFormatted.toFixed(4),
              investedAmount: ethAmountFormatted.toFixed(4), // Same as ethAmount for compatibility
              tokenAmount: tokenAmountFormatted.toFixed(4),
              investmentDate: latestInvestmentDate,
              status: currentPhase === 3 ? 'completed' : 'active',
              currentValue: currentValue.toFixed(2),
              profitLoss: profitLoss.toFixed(2),
              profitLossPercentage,
              transactionHash: firstTransactionHash
            });
          }
        } catch (crowdsaleError) {
          console.warn(`Failed to fetch data for crowdsale ${crowdsaleAddress}:`, crowdsaleError);
          // Continue with other crowdsales
        }
      }

      setInvestments(userInvestments);
    } catch (error) {
      console.error('Failed to fetch user investments:', error);
      setError(handleContractError(error));
    } finally {
      setLoading(false);
    }
  }, [userAddress, getCrowdsaleFactoryContract, getCrowdsaleContract, getTokenContract, fetchTokenPrice]);

  const refreshInvestments = useCallback(() => {
    fetchUserInvestments();
  }, [fetchUserInvestments]);

  useEffect(() => {
    fetchUserInvestments();
  }, [fetchUserInvestments]);

  return {
    investments,
    loading,
    error,
    refreshInvestments,
  };
};
