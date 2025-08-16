import { useMemo, useEffect, useState } from 'react';
import { getTokenPrice, getETHPrice, type TokenPrice } from '../utils/priceApi';

export interface UserInvestment {
  crowdsaleAddress: string;
  crowdsaleName: string;
  tokenSymbol: string;
  tokenAddress: string;
  ethAmount: string;
  tokenAmount: string;
  investmentDate: number;
  status: 'active' | 'completed' | 'refunded';
  currentValue: string;
  profitLoss: string;
  profitLossPercentage: number;
  transactionHash: string;
  investedAmount: string;
}

export interface VestingSchedule {
  id: string;
  beneficiary: string;
  tokenAddress: string;
  tokenSymbol: string;
  tokenName: string;
  totalAmount: string;
  releasedAmount: string;
  remainingAmount: string;
  releasableAmount: string;
  startTime: number;
  endTime: number;
  cliffTime: number;
  vestingType: 'LINEAR' | 'CLIFF' | 'STEPPED' | 'MILESTONE';
  isRevocable: boolean;
  isRevoked: boolean;
  releaseProgress: number;
  nextReleaseDate: number;
  status: 'active' | 'completed' | 'revoked';
}

export interface PortfolioItem {
  tokenSymbol: string;
  tokenAddress: string;
  amount: string;
  value: string;
  percentage: number;
}

export interface InvestmentStats {
  totalInvested: string; // Total ETH invested
  totalTokens: string; // Total tokens received
  currentValue: string; // Current portfolio value in USD
  totalProfit: string; // Total profit/loss in USD
  profitPercentage: number; // Profit percentage
  activeInvestments: number; // Number of active investments
  completedInvestments: number; // Number of completed investments
  refundedInvestments: number; // Number of refunded investments
  averageROI: number; // Average return on investment
  bestPerforming: UserInvestment | null; // Best performing investment
  worstPerforming: UserInvestment | null; // Worst performing investment
  portfolioDistribution: PortfolioItem[]; // Token distribution
  totalVestingValue: string; // Total value in vesting contracts
  releasableValue: string; // Total releasable value
}

export const useInvestmentStats = (
  investments: UserInvestment[],
  vestingSchedules: VestingSchedule[]
): {
  stats: InvestmentStats;
  loading: boolean;
} => {
  const stats = useMemo(() => {
    if (!investments.length && !vestingSchedules.length) {
      return {
        totalInvested: '0',
        totalTokens: '0',
        currentValue: '0',
        totalProfit: '0',
        profitPercentage: 0,
        activeInvestments: 0,
        completedInvestments: 0,
        refundedInvestments: 0,
        averageROI: 0,
        bestPerforming: null,
        worstPerforming: null,
        portfolioDistribution: [],
        totalVestingValue: '0',
        releasableValue: '0',
      };
    }

    // Calculate basic investment statistics
    const totalInvested = investments.reduce((sum, inv) => 
      sum + parseFloat(inv.ethAmount), 0
    );
    
    const totalTokens = investments.reduce((sum, inv) => 
      sum + parseFloat(inv.tokenAmount), 0
    );
    
    const currentValue = investments.reduce((sum, inv) => 
      sum + parseFloat(inv.currentValue), 0
    );
    
    const totalProfit = currentValue - totalInvested;
    const profitPercentage = totalInvested > 0 ? (totalProfit / totalInvested) * 100 : 0;

    // Count investments by status
    const activeInvestments = investments.filter(inv => inv.status === 'active').length;
    const completedInvestments = investments.filter(inv => inv.status === 'completed').length;
    const refundedInvestments = investments.filter(inv => inv.status === 'refunded').length;

    // Calculate average ROI
    const roiValues = investments
      .filter(inv => parseFloat(inv.ethAmount) > 0)
      .map(inv => inv.profitLossPercentage);
    const averageROI = roiValues.length > 0 
      ? roiValues.reduce((sum, roi) => sum + roi, 0) / roiValues.length 
      : 0;

    // Find best and worst performing investments
    const sortedByPerformance = [...investments].sort((a, b) => 
      b.profitLossPercentage - a.profitLossPercentage
    );
    const bestPerforming = sortedByPerformance[0] || null;
    const worstPerforming = sortedByPerformance[sortedByPerformance.length - 1] || null;

    // Calculate portfolio distribution
    const tokenMap = new Map<string, { amount: number; value: number; address: string }>();
    
    investments.forEach(inv => {
      const existing = tokenMap.get(inv.tokenSymbol) || { amount: 0, value: 0, address: inv.tokenAddress };
      tokenMap.set(inv.tokenSymbol, {
        amount: existing.amount + parseFloat(inv.tokenAmount),
        value: existing.value + parseFloat(inv.currentValue),
        address: inv.tokenAddress,
      });
    });

    const portfolioDistribution: PortfolioItem[] = Array.from(tokenMap.entries()).map(([symbol, data]) => ({
      tokenSymbol: symbol,
      tokenAddress: data.address,
      amount: data.amount.toFixed(4),
      value: data.value.toFixed(2),
      percentage: currentValue > 0 ? (data.value / currentValue) * 100 : 0,
    }));

    // Calculate vesting statistics
    const totalVestingValue = vestingSchedules.reduce((sum, schedule) => {
      // Estimate vesting value using a mock price (in production, use real token prices)
      const mockTokenPrice = 0.1; // $0.1 per token
      const remainingTokens = parseFloat(schedule.remainingAmount);
      return sum + (remainingTokens * mockTokenPrice);
    }, 0);

    const releasableValue = vestingSchedules.reduce((sum, schedule) => {
      const mockTokenPrice = 0.1; // $0.1 per token
      const releasableTokens = parseFloat(schedule.releasableAmount);
      return sum + (releasableTokens * mockTokenPrice);
    }, 0);

    return {
      totalInvested: totalInvested.toFixed(4),
      totalTokens: totalTokens.toFixed(4),
      currentValue: currentValue.toFixed(2),
      totalProfit: totalProfit.toFixed(2),
      profitPercentage,
      activeInvestments,
      completedInvestments,
      refundedInvestments,
      averageROI,
      bestPerforming,
      worstPerforming,
      portfolioDistribution,
      totalVestingValue: totalVestingValue.toFixed(2),
      releasableValue: releasableValue.toFixed(2),
    };
  }, [investments, vestingSchedules]);

  return {
    stats,
    loading: false, // Stats are computed synchronously
  };
};
