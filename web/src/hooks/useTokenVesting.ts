import { useState, useEffect, useCallback } from 'react';
import { ethers, formatEther } from 'ethers';
import { useWallet } from '@/hooks/useWallet';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';
import { TransactionType, TransactionStatus } from '@/types/wallet';
import { useWalletStore } from '@/stores/walletStore';
import toast from 'react-hot-toast';

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

export const useTokenVesting = (userAddress?: string) => {
  const { getProvider } = useWallet();
  const { addTransaction } = useWalletStore();
  const [vestingSchedules, setVestingSchedules] = useState<VestingSchedule[]>([]);
  const [loading, setLoading] = useState(false);
  const [releasing, setReleasing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getVestingContract = useCallback(async () => {
    const contractAddress = getContractAddress('TOKENVESTING');
    if (!contractAddress) {
      console.warn('TokenVesting contract address not configured. Vesting features will be disabled.');
      return null;
    }
    const abi = getContractABI('TokenVesting');
    const provider = await getProvider();
    return new ethers.Contract(contractAddress, abi, provider);
  }, [getProvider]);

  const getTokenContract = useCallback(async (tokenAddress: string) => {
    const abi = getContractABI('CrowdsaleToken');
    const provider = await getProvider();
    return new ethers.Contract(tokenAddress, abi, provider);
  }, [getProvider]);

  const calculateProgress = useCallback((schedule: any): number => {
    const now = Math.floor(Date.now() / 1000);
    const { startTime, endTime, cliffEnd } = schedule;
    
    if (now < cliffEnd) return 0;
    if (now >= endTime) return 100;
    
    const totalDuration = endTime - startTime;
    const elapsed = now - startTime;
    return Math.min((elapsed / totalDuration) * 100, 100);
  }, []);

  const calculateNextReleaseDate = useCallback((schedule: any): number => {
    const now = Math.floor(Date.now() / 1000);
    const { vestingType, startTime, endTime, cliffEnd } = schedule;
    
    if (now < cliffEnd) return cliffEnd;
    if (now >= endTime) return 0; // No more releases
    
    switch (vestingType) {
      case 'LINEAR':
        return 0; // Continuous release
      case 'CLIFF':
        return now < cliffEnd ? cliffEnd : 0;
      case 'STEPPED':
        // Assume monthly releases for stepped vesting
        const monthlyInterval = 30 * 24 * 60 * 60; // 30 days in seconds
        const nextMonth = Math.ceil((now - startTime) / monthlyInterval) * monthlyInterval + startTime;
        return Math.min(nextMonth, endTime);
      case 'MILESTONE':
        return 0; // Milestone-based, no predictable next date
      default:
        return 0;
    }
  }, []);

  const fetchVestingSchedules = useCallback(async () => {
    if (!userAddress) {
      setVestingSchedules([]);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const vestingContract = await getVestingContract();
      if (!vestingContract) {
        console.warn('TokenVesting contract not available');
        setVestingSchedules([]);
        setLoading(false);
        return;
      }

      // Get beneficiary schedules
      const scheduleIds = await vestingContract.getBeneficiarySchedules(userAddress);
      
      if (scheduleIds.length === 0) {
        setVestingSchedules([]);
        setLoading(false);
        return;
      }

      const schedules: VestingSchedule[] = [];
      
      for (const scheduleId of scheduleIds) {
        try {
          const schedule = await vestingContract.getVestingSchedule(scheduleId);
          const releasableAmount = await vestingContract.getReleasableAmount(scheduleId);
          
          // Get token info
          const tokenContract = await getTokenContract(schedule.tokenAddress);
          const tokenSymbol = await tokenContract.symbol();
          const tokenName = await tokenContract.name();
          
          const progress = calculateProgress(schedule);
          const nextRelease = calculateNextReleaseDate(schedule);
          
          const vestingSchedule: VestingSchedule = {
            id: scheduleId.toString(),
            beneficiary: schedule.beneficiary,
            tokenAddress: schedule.tokenAddress,
            tokenSymbol,
            tokenName,
            totalAmount: formatEther(schedule.totalAmount),
            releasedAmount: formatEther(schedule.releasedAmount),
            remainingAmount: formatEther(schedule.totalAmount - schedule.releasedAmount),
            releasableAmount: formatEther(releasableAmount),
            startTime: Number(schedule.startTime),
            endTime: Number(schedule.endTime),
            cliffTime: Number(schedule.cliffEnd),
            vestingType: ['LINEAR', 'CLIFF', 'STEPPED', 'MILESTONE'][Number(schedule.vestingType)] as VestingSchedule['vestingType'],
            isRevocable: schedule.isRevocable,
            isRevoked: schedule.isRevoked,
            releaseProgress: progress,
            nextReleaseDate: nextRelease,
            status: schedule.isRevoked ? 'revoked' : (progress >= 100 ? 'completed' : 'active')
          };
          
          schedules.push(vestingSchedule);
        } catch (scheduleError) {
          console.warn(`Failed to fetch schedule ${scheduleId}:`, scheduleError);
        }
      }

      setVestingSchedules(schedules);
      
    } catch (error) {
      console.error('Failed to fetch vesting schedules:', error);
      setError(handleContractError(error));
    } finally {
      setLoading(false);
    }
  }, [userAddress, getVestingContract, getTokenContract, calculateProgress, calculateNextReleaseDate]);

  const releaseTokens = useCallback(async (scheduleId: string) => {
    try {
      setReleasing(true);
      const vestingContract = await getVestingContract();
      if (!vestingContract) {
        toast.error('TokenVesting contract not available');
        return;
      }

      const { getSigner } = useWallet();
      const signer = await getSigner();
      const contractWithSigner = vestingContract.connect(signer);
      
      const tx = await contractWithSigner.releaseTokens(scheduleId);
      
      addTransaction({
        hash: tx.hash,
        type: TransactionType.RELEASE_TOKENS,
        status: TransactionStatus.PENDING,
      });
      
      toast.success('代币释放交易已提交');
      await tx.wait();
      
      toast.success('代币释放成功！');
      await fetchVestingSchedules();
      
    } catch (error) {
      console.error('Token release failed:', error);
      toast.error('代币释放失败：' + handleContractError(error));
    } finally {
      setReleasing(false);
    }
  }, [getVestingContract, addTransaction, fetchVestingSchedules]);

  const batchReleaseTokens = useCallback(async (scheduleIds: string[]) => {
    try {
      setReleasing(true);
      const vestingContract = await getVestingContract();
      if (!vestingContract) {
        toast.error('TokenVesting contract not available');
        return;
      }

      const { getSigner } = useWallet();
      const signer = await getSigner();
      const contractWithSigner = vestingContract.connect(signer);
      
      const tx = await contractWithSigner.batchRelease(scheduleIds);
      
      addTransaction({
        hash: tx.hash,
        type: TransactionType.RELEASE_TOKENS,
        status: TransactionStatus.PENDING,
      });
      
      toast.success(`批量代币释放交易已提交 (${scheduleIds.length} 个计划)`);
      await tx.wait();
      
      toast.success(`成功释放 ${scheduleIds.length} 个释放计划的代币！`);
      await fetchVestingSchedules();
      
    } catch (error) {
      console.error('Batch release failed:', error);
      toast.error('批量释放失败：' + handleContractError(error));
    } finally {
      setReleasing(false);
    }
  }, [getVestingContract, addTransaction, fetchVestingSchedules]);

  // Auto-fetch on mount and when userAddress changes
  useEffect(() => {
    fetchVestingSchedules();
  }, [userAddress, fetchVestingSchedules]);

  const refresh = useCallback(() => {
    fetchVestingSchedules();
  }, [fetchVestingSchedules]);

  return {
    vestingSchedules,
    loading,
    releasing,
    error,
    releaseTokens,
    batchReleaseTokens,
    refresh,
  };
};

export default useTokenVesting;
