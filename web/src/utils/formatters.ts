import { formatEther as ethersFormatEther, formatUnits, parseEther, parseUnits } from 'ethers';
import { FORMAT_CONFIG } from './constants';

// Re-export formatEther for compatibility
export const formatEther = (wei: string | bigint): string => {
  return ethersFormatEther(wei);
};

// Format Wei to Ether with specified decimals
export const formatWeiToEther = (wei: bigint, decimals: number = 4): string => {
  return Number(formatEther(wei)).toFixed(decimals);
};

// Format token amount with decimals
export const formatTokenAmount = (amount: string | bigint, tokenDecimals: number = FORMAT_CONFIG.TOKEN_DECIMALS, displayDecimals: number = 2): string => {
  if (typeof amount === 'string') {
    // If it's already a formatted string, just return it with proper decimals
    const num = parseFloat(amount);
    return isNaN(num) ? '0.00' : num.toFixed(displayDecimals);
  }
  return Number(formatUnits(amount, tokenDecimals)).toFixed(displayDecimals);
};

// Format percentage from basis points
export const formatPercentage = (basisPoints: bigint, decimals: number = FORMAT_CONFIG.PERCENTAGE_DECIMALS): string => {
  const percentage = Number(basisPoints) / FORMAT_CONFIG.BASIS_POINTS * 100;
  return `${percentage.toFixed(decimals)}%`;
};

// Format large numbers with K, M, B suffixes
export const formatLargeNumber = (num: number): string => {
  if (num >= 1e9) {
    return `${(num / 1e9).toFixed(1)}B`;
  }
  if (num >= 1e6) {
    return `${(num / 1e6).toFixed(1)}M`;
  }
  if (num >= 1e3) {
    return `${(num / 1e3).toFixed(1)}K`;
  }
  return num.toString();
};

// Format timestamp to readable date
export const formatTimestamp = (timestamp: bigint | number): string => {
  const date = new Date(Number(timestamp) * 1000);
  return date.toLocaleString();
};

// Format duration in seconds to human readable
export const formatDuration = (seconds: bigint | number): string => {
  const totalSeconds = Number(seconds);
  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  
  if (days > 0) {
    return `${days}d ${hours}h`;
  }
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
};

// Format address for display (truncate middle)
export const formatAddress = (address: string, startChars: number = 6, endChars: number = 4): string => {
  if (!address || address.length < startChars + endChars) {
    return address;
  }
  return `${address.slice(0, startChars)}...${address.slice(-endChars)}`;
};

// Parse user input to Wei
export const parseEtherInput = (input: string): bigint => {
  try {
    return parseEther(input);
  } catch {
    return 0n;
  }
};

// Parse token input with decimals
export const parseTokenInput = (input: string, decimals: number = FORMAT_CONFIG.TOKEN_DECIMALS): bigint => {
  try {
    return parseUnits(input, decimals);
  } catch {
    return 0n;
  }
};

// Validate Ethereum address
export const isValidAddress = (address: string): boolean => {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
};

// Validate amount input
export const isValidAmount = (amount: string): boolean => {
  const num = parseFloat(amount);
  return !isNaN(num) && num > 0 && isFinite(num);
};

// Calculate progress percentage
export const calculateProgress = (current: bigint, target: bigint): number => {
  if (target === 0n) return 0;
  return Math.min(Number(current * 100n / target), 100);
};

// Format transaction hash for display
export const formatTxHash = (hash: string): string => {
  return formatAddress(hash, 10, 8);
};

// Format gas price in Gwei
export const formatGasPrice = (gasPrice: bigint): string => {
  const gwei = Number(formatUnits(gasPrice, 9));
  return `${gwei.toFixed(2)} Gwei`;
};

// Format time remaining
export const formatTimeRemaining = (endTime: bigint): string => {
  const now = Math.floor(Date.now() / 1000);
  const remaining = Number(endTime) - now;
  
  if (remaining <= 0) {
    return 'Ended';
  }
  
  return formatDuration(remaining);
};

// Format crowdsale phase
export const formatCrowdsalePhase = (phase: number): string => {
  const phases = ['Pending', 'Presale', 'Public Sale', 'Finalized'];
  return phases[phase] || 'Unknown';
};

// Format vesting type
export const formatVestingType = (type: number): string => {
  const types = ['Linear', 'Cliff', 'Stepped', 'Milestone', 'Custom'];
  return types[type] || 'Unknown';
};
