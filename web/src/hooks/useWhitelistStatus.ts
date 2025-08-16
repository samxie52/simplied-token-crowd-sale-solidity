import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { useWallet } from './useWallet';
import { CONTRACT_ABIS, getContractAddress } from '../utils/contracts';

export interface WhitelistStatusData {
  isWhitelisted: boolean;
  tier: 'VIP' | 'WHITELISTED' | 'NONE';
  level: number;
  discount: number;
  maxAllocation: string;
  currentAllocation: string;
  expirationTime: number;
  addedTime: number;
  addedBy: string;
}

export const useWhitelistStatus = () => {
  const { address, getSigner, getProvider } = useWallet();
  const [status, setStatus] = useState<WhitelistStatusData>({
    isWhitelisted: false,
    tier: 'NONE',
    level: 1,
    discount: 0,
    maxAllocation: '0',
    currentAllocation: '0',
    expirationTime: 0,
    addedTime: 0,
    addedBy: ethers.ZeroAddress
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getWhitelistContract = useCallback(async () => {
    const contractAddress = getContractAddress('WhitelistManager');
    if (!contractAddress) {
      throw new Error('WhitelistManager contract address not found');
    }

    const abi = CONTRACT_ABIS.WhitelistManager;
    const signer = await getSigner();
    const provider = await getProvider();
    const runner = signer || provider;
    
    if (!runner) {
      throw new Error('No wallet connection available');
    }

    return new ethers.Contract(contractAddress, abi, runner);
  }, [getSigner, getProvider]);

  const fetchWhitelistStatus = useCallback(async () => {
    if (!address) {
      setStatus({
        isWhitelisted: false,
        tier: 'NONE',
        level: 1,
        discount: 0,
        maxAllocation: '0',
        currentAllocation: '0',
        expirationTime: 0,
        addedTime: 0,
        addedBy: ethers.ZeroAddress
      });
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const contract = await getWhitelistContract();
      
      // 获取用户白名单级别
      const level = await contract.getWhitelistStatus(address);
      const levelNum = Number(level);
      
      // 如果用户不在白名单中
      if (levelNum === 1) { // NONE
        setStatus({
          isWhitelisted: false,
          tier: 'NONE',
          level: levelNum,
          discount: 0,
          maxAllocation: '0',
          currentAllocation: '0',
          expirationTime: 0,
          addedTime: 0,
          addedBy: ethers.ZeroAddress
        });
        return;
      }

      // 获取用户详细信息
      const info = await contract.getWhitelistInfo(address);
      
      console.log('Whitelist info for', address, ':', {
        level: levelNum,
        info: {
          level: Number(info.level),
          expirationTime: Number(info.expirationTime),
          addedTime: Number(info.addedTime),
          addedBy: info.addedBy
        }
      });
      
      // 确定层级和折扣
      const tier = levelNum === 3 ? 'VIP' : levelNum === 2 ? 'WHITELISTED' : 'NONE';
      const discount = tier === 'VIP' ? 20 : tier === 'WHITELISTED' ? 10 : 0;
      const maxAllocation = tier === 'VIP' ? '5.0' : tier === 'WHITELISTED' ? '1.0' : '0';
      
      // TODO: 从众筹合约获取已使用的配额
      const currentAllocation = '0';

      setStatus({
        isWhitelisted: levelNum !== 1,
        tier: tier as 'VIP' | 'WHITELISTED' | 'NONE',
        level: levelNum,
        discount,
        maxAllocation,
        currentAllocation,
        expirationTime: Number(info.expirationTime),
        addedTime: Number(info.addedTime),
        addedBy: info.addedBy
      });

    } catch (error) {
      console.error('Failed to fetch whitelist status:', error);
      setError(error instanceof Error ? error.message : 'Failed to fetch whitelist status');
      
      // 设置默认状态
      setStatus({
        isWhitelisted: false,
        tier: 'NONE',
        level: 1,
        discount: 0,
        maxAllocation: '0',
        currentAllocation: '0',
        expirationTime: 0,
        addedTime: 0,
        addedBy: ethers.ZeroAddress
      });
    } finally {
      setLoading(false);
    }
  }, [address, getWhitelistContract]);

  // 当地址变化时重新获取状态
  useEffect(() => {
    fetchWhitelistStatus();
  }, [fetchWhitelistStatus]);

  return {
    status,
    loading,
    error,
    refetch: fetchWhitelistStatus
  };
};
