import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { useWallet } from './useWallet';
import { getContractAddress, getContractABI } from '@/utils/contracts';
import { handleContractError } from '@/utils/errorHandler';

interface AdminPermissions {
  isAdmin: boolean;
  isOperator: boolean;
  hasEmergencyRole: boolean;
  loading: boolean;
  error: string | null;
}

export const useAdminAuth = () => {
  const { address, isConnected, getSigner, getProvider } = useWallet();
  const [permissions, setPermissions] = useState<AdminPermissions>({
    isAdmin: false,
    isOperator: false,
    hasEmergencyRole: false,
    loading: false,
    error: null
  });

  const getCrowdsaleContract = useCallback(async () => {
    const contractAddress = getContractAddress('TOKENCROWDSALE');
    if (!contractAddress) {
      throw new Error('TokenCrowdsale contract address not configured. Please set VITE_TOKENCROWDSALE_ADDRESS in .env.local');
    }
    
    const abi = getContractABI('TokenCrowdsale');
    
    // Try to get signer first, fallback to provider
    let runner;
    try {
      runner = await getSigner();
    } catch {
      runner = await getProvider();
    }
    
    if (!runner) throw new Error('No wallet connection found');
    
    return new ethers.Contract(contractAddress, abi, runner);
  }, [getSigner, getProvider]);

  const checkPermissions = useCallback(async () => {
    if (!isConnected || !address) {
      setPermissions(prev => ({ 
        ...prev, 
        isAdmin: false, 
        isOperator: false, 
        hasEmergencyRole: false,
        error: null
      }));
      return;
    }

    setPermissions(prev => ({ ...prev, loading: true, error: null }));

    try {
      const contract = await getCrowdsaleContract();
      
      // 获取角色常量 - 直接使用keccak256计算，因为合约中角色常量是通过CrowdsaleConstants库定义的
      const adminRole = ethers.keccak256(ethers.toUtf8Bytes("CROWDSALE_ADMIN_ROLE"));
      const operatorRole = ethers.keccak256(ethers.toUtf8Bytes("CROWDSALE_OPERATOR_ROLE"));
      const emergencyRole = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));

      // 验证地址格式
      if (!address || !ethers.isAddress(address)) {
        throw new Error('Invalid wallet address');
      }
      
      console.log('Checking permissions for address:', address);
      
      // 检查用户权限
      const [isAdmin, isOperator, hasEmergencyRole] = await Promise.all([
        contract.hasRole(adminRole, address).catch(() => false),
        contract.hasRole(operatorRole, address).catch(() => false),
        contract.hasRole(emergencyRole, address).catch(() => false)
      ]);

      setPermissions({
        isAdmin,
        isOperator,
        hasEmergencyRole,
        loading: false,
        error: null
      });
    } catch (error) {
      console.error('Permission check failed:', error);
      setPermissions(prev => ({
        ...prev,
        loading: false,
        error: handleContractError(error)
      }));
    }
  }, [isConnected, address, getCrowdsaleContract]);

  useEffect(() => {
    checkPermissions();
  }, [checkPermissions]);

  return {
    ...permissions,
    refreshPermissions: checkPermissions
  };
};
