import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { useWallet } from './useWallet';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';

interface WhitelistUser {
  address: string;
  tier: 'VIP' | 'WHITELISTED';
  level: number;
  allocation: string;
  used: string;
  addedDate: number;
}

export const useWhitelistManagement = () => {
  const { getSigner, getProvider } = useWallet();
  const [users, setUsers] = useState<WhitelistUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getWhitelistContract = useCallback(async () => {
    const contractAddress = getContractAddress('WHITELISTMANAGER');
    console.log('WhitelistManager contract address:', contractAddress);
    
    if (!contractAddress) {
      throw new Error('WhitelistManager contract address not configured. Please set VITE_WHITELISTMANAGER_ADDRESS in .env.local');
    }
    
    const abi = getContractABI('WhitelistManager');
    
    // Try to get signer first, fallback to provider
    let runner;
    try {
      runner = await getSigner();
    } catch {
      runner = await getProvider();
    }
    
    if (!runner) throw new Error('No wallet connection found');
    
    console.log('Creating WhitelistManager contract with:', { contractAddress, runner: !!runner });
    return new ethers.Contract(contractAddress, abi, runner);
  }, [getSigner, getProvider]);

  // 获取白名单用户列表
  const fetchWhitelistUsers = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const contract = await getWhitelistContract();
      
      // 首先检查总用户数，避免调用空数组
      let result;
      try {
        result = await contract.getAllWhitelistUsers(0, 100); // 获取前100个用户
      } catch (contractError: any) {
        // 如果返回空数据或解码失败，说明没有用户
        if (contractError.code === 'BAD_DATA' || contractError.message?.includes('could not decode result data')) {
          console.log('No whitelist users found (empty contract state)');
          setUsers([]);
          return;
        }
        throw contractError; // 重新抛出其他错误
      }
      
      const userAddresses = result[0];
      const total = result[1];
      
      console.log('All whitelist users:', { userAddresses, total: total.toString() });
      
      if (!userAddresses || userAddresses.length === 0) {
        setUsers([]);
        return;
      }
      
      // 逐个获取用户详细信息以避免复杂的tuple ABI问题
      const users: WhitelistUser[] = [];
      
      for (let i = 0; i < userAddresses.length; i++) {
        const address = userAddresses[i];
        
        try {
          // 获取用户级别
          const level = await contract.getWhitelistStatus(address);
          const levelNum = Number(level);
          
          // 只显示有效的白名单用户（非NONE级别）
          if (levelNum !== 1) { // 1 = NONE
            // 获取用户详细信息
            const info = await contract.getWhitelistInfo(address);
            
            const tier = levelNum === 3 ? 'VIP' : levelNum === 2 ? 'WHITELISTED' : 'BLACKLISTED';
            const allocation = tier === 'VIP' ? '5000.00' : tier === 'WHITELISTED' ? '1000.00' : '0.00';
            
            users.push({
              address,
              tier: tier as 'VIP' | 'WHITELISTED',
              level: levelNum,
              allocation,
              used: '0.00', // TODO: 从众筹合约获取已使用额度
              addedDate: Number(info.addedTime) * 1000 // 转换为毫秒
            });
          }
        } catch (userError) {
          console.warn(`Failed to get info for user ${address}:`, userError);
          // 继续处理其他用户
        }
      }
      
      setUsers(users);
    } catch (error) {
      console.error('Failed to fetch whitelist stats:', error);
      setError(handleContractError(error));
      // 如果合约调用失败，显示空列表
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }, [getWhitelistContract]);

  // 添加用户到白名单
  const addWhitelistUser = useCallback(async (user: { address: string; tier: 'VIP' | 'WHITELISTED' }) => {
    try {
      // Validate user address
      if (!user.address || user.address.trim() === '') {
        throw new Error('User address is required');
      }
      
      // Validate address format
      if (!ethers.isAddress(user.address)) {
        throw new Error('Invalid Ethereum address format');
      }
      
      console.log('Adding user to whitelist:', { address: user.address, tier: user.tier });
      
      const contract = await getWhitelistContract();
      // 修正枚举值映射：VIP=3, WHITELISTED=2 (根据合约中的WhitelistLevel枚举)
      const level = user.tier === 'VIP' ? 3 : 2;
      
      // 检查当前用户是否有WHITELIST_OPERATOR_ROLE权限
      const signer = await getSigner();
      if (!signer) {
        throw new Error('No wallet connected');
      }
      
      const currentAddress = await signer.getAddress();
      const operatorRole = ethers.keccak256(ethers.toUtf8Bytes("WHITELIST_OPERATOR_ROLE"));
      
      try {
        const hasOperatorRole = await contract.hasRole(operatorRole, currentAddress);
        if (!hasOperatorRole) {
          throw new Error(`Current wallet (${currentAddress}) does not have WHITELIST_OPERATOR_ROLE. Please connect with the deployer wallet: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`);
        }
      } catch (roleError) {
        console.error('Role check failed:', roleError);
        throw new Error(`Permission check failed: ${roleError instanceof Error ? roleError.message : String(roleError)}`);
      }
      
      console.log('Contract call details:', {
        contractAddress: contract.target,
        userAddress: user.address,
        level,
        tier: user.tier
      });
      
      // 检查合约是否暂停
      try {
        const isPaused = await contract.paused();
        if (isPaused) {
          throw new Error('WhitelistManager contract is currently paused');
        }
      } catch (pauseError) {
        console.warn('Could not check pause status:', pauseError);
      }
      
      // 尝试估算gas费用
      try {
        const gasEstimate = await contract.addToWhitelist.estimateGas(user.address, level);
        console.log('Estimated gas:', gasEstimate.toString());
      } catch (gasError) {
        console.error('Gas estimation failed:', gasError);
        const errorMessage = gasError instanceof Error ? gasError.message : String(gasError);
        throw new Error(`Transaction will likely fail: ${errorMessage}`);
      }
      
      const tx = await contract.addToWhitelist(user.address, level);
      console.log('Transaction sent:', tx.hash);
      await tx.wait();
      
      // 刷新列表
      await fetchWhitelistUsers();
      
      return { success: true, txHash: tx.hash };
    } catch (error) {
      throw new Error(handleContractError(error));
    }
  }, [getWhitelistContract, fetchWhitelistUsers]);

  // 从白名单移除用户
  const removeUser = useCallback(async (address: string) => {
    setLoading(true);
    setError(null);

    try {
      const contract = await getWhitelistContract();
      const tx = await contract.removeFromWhitelist(address);
      await tx.wait();
      
      // 更新本地状态
      setUsers(prev => prev.filter(user => user.address !== address));
      
      return { success: true, txHash: tx.hash };
    } catch (error) {
      throw new Error(handleContractError(error));
    }
  }, [getWhitelistContract, fetchWhitelistUsers]);

  // 批量添加用户
  const batchAddUsers = useCallback(async (
    addresses: string[], 
    levels: number[]
  ) => {
    try {
      const contract = await getWhitelistContract();
      const tx = await contract.batchAddToWhitelist(addresses, levels);
      await tx.wait();
      
      // 刷新列表
      await fetchWhitelistUsers();
      
      return { success: true, txHash: tx.hash };
    } catch (error) {
      throw new Error(handleContractError(error));
    }
  }, [getWhitelistContract, fetchWhitelistUsers]);

  // 检查用户白名单状态
  const checkUserStatus = useCallback(async (address: string) => {
    try {
      const contract = await getWhitelistContract();
      const isWhitelisted = await contract.isWhitelisted(address);
      if (isWhitelisted) {
        const level = await contract.getWhitelistLevel(address);
        return {
          isWhitelisted: true,
          level: Number(level),
          tier: Number(level) === 2 ? 'VIP' : 'WHITELISTED'
        };
      }
      
      return { isWhitelisted: false, level: 0, tier: null };
    } catch (error) {
      console.error('Failed to check whitelist status:', error);
      return { isWhitelisted: false, level: 0, tier: null };
    }
  }, [getWhitelistContract]);

  useEffect(() => {
    fetchWhitelistUsers();
  }, [fetchWhitelistUsers]);

  return {
    users,
    loading,
    error,
    refreshUsers: fetchWhitelistUsers,
    addWhitelistUser,
    removeWhitelistUser: removeUser,
    batchAddUsers,
    checkWhitelistStatus: checkUserStatus
  };
};
