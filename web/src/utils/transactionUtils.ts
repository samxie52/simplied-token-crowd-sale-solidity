import { ethers } from 'ethers';
import { 
  TransactionType, 
  TransactionStatus, 
  Transaction, 
  TransactionFilter 
} from '../types/transactionTypes';

export const getTransactionTypeLabel = (type: TransactionType): string => {
  const labels = {
    [TransactionType.TOKEN_PURCHASE]: '代币购买',
    [TransactionType.REFUND]: '退款',
    [TransactionType.TOKEN_RELEASE]: '代币释放',
    [TransactionType.WHITELIST_ADD]: '添加白名单',
    [TransactionType.WHITELIST_REMOVE]: '移除白名单',
    [TransactionType.PHASE_CHANGE]: '阶段变更',
    [TransactionType.CONFIG_UPDATE]: '配置更新',
    [TransactionType.EMERGENCY_ACTION]: '紧急操作',
    [TransactionType.VESTING_CREATE]: '创建释放计划',
    [TransactionType.DEPOSIT]: '资金存入'
  };
  return labels[type] || type;
};

export const getTransactionStatusLabel = (status: TransactionStatus): string => {
  const labels = {
    [TransactionStatus.PENDING]: '待确认',
    [TransactionStatus.SUCCESS]: '成功',
    [TransactionStatus.FAILED]: '失败',
    [TransactionStatus.CANCELLED]: '已取消'
  };
  return labels[status] || status;
};

export const getTransactionStatusColor = (status: TransactionStatus): string => {
  const colors = {
    [TransactionStatus.PENDING]: 'text-yellow-600 bg-yellow-50',
    [TransactionStatus.SUCCESS]: 'text-green-600 bg-green-50',
    [TransactionStatus.FAILED]: 'text-red-600 bg-red-50',
    [TransactionStatus.CANCELLED]: 'text-gray-600 bg-gray-50'
  };
  return colors[status] || 'text-gray-600 bg-gray-50';
};

export const formatTransactionValue = (value: string, decimals: number = 18): string => {
  try {
    return ethers.formatUnits(value, decimals);
  } catch (error) {
    return '0';
  }
};

export const formatTransactionAmount = (value: string, symbol: string = 'ETH', decimals: number = 18): string => {
  const formatted = formatTransactionValue(value, decimals);
  return `${parseFloat(formatted).toFixed(4)} ${symbol}`;
};

export const getTransactionIcon = (type: TransactionType): string => {
  const icons = {
    [TransactionType.TOKEN_PURCHASE]: 'shopping-cart',
    [TransactionType.REFUND]: 'arrow-left',
    [TransactionType.TOKEN_RELEASE]: 'unlock',
    [TransactionType.WHITELIST_ADD]: 'user-plus',
    [TransactionType.WHITELIST_REMOVE]: 'user-minus',
    [TransactionType.PHASE_CHANGE]: 'arrow-right',
    [TransactionType.CONFIG_UPDATE]: 'cog',
    [TransactionType.EMERGENCY_ACTION]: 'exclamation-triangle',
    [TransactionType.VESTING_CREATE]: 'clock',
    [TransactionType.DEPOSIT]: 'arrow-down'
  };
  return icons[type] || 'document';
};

export const getTransactionTypeColor = (type: TransactionType): string => {
  const colors = {
    [TransactionType.TOKEN_PURCHASE]: 'text-blue-600 bg-blue-50',
    [TransactionType.REFUND]: 'text-orange-600 bg-orange-50',
    [TransactionType.TOKEN_RELEASE]: 'text-green-600 bg-green-50',
    [TransactionType.WHITELIST_ADD]: 'text-purple-600 bg-purple-50',
    [TransactionType.WHITELIST_REMOVE]: 'text-red-600 bg-red-50',
    [TransactionType.PHASE_CHANGE]: 'text-indigo-600 bg-indigo-50',
    [TransactionType.CONFIG_UPDATE]: 'text-gray-600 bg-gray-50',
    [TransactionType.EMERGENCY_ACTION]: 'text-red-600 bg-red-50',
    [TransactionType.VESTING_CREATE]: 'text-teal-600 bg-teal-50',
    [TransactionType.DEPOSIT]: 'text-cyan-600 bg-cyan-50'
  };
  return colors[type] || 'text-gray-600 bg-gray-50';
};

export const sortTransactionsByTimestamp = (transactions: Transaction[]): Transaction[] => {
  return [...transactions].sort((a, b) => b.timestamp - a.timestamp);
};

export const filterTransactions = (
  transactions: Transaction[],
  filter: Partial<TransactionFilter>
): Transaction[] => {
  return transactions.filter(tx => {
    // 类型过滤
    if (filter.types && filter.types.length > 0 && !filter.types.includes(tx.type)) {
      return false;
    }

    // 状态过滤
    if (filter.status && filter.status.length > 0 && !filter.status.includes(tx.status)) {
      return false;
    }

    // 时间范围过滤
    if (filter.dateRange) {
      const txDate = new Date(tx.timestamp * 1000);
      if (filter.dateRange.start && txDate < filter.dateRange.start) {
        return false;
      }
      if (filter.dateRange.end && txDate > filter.dateRange.end) {
        return false;
      }
    }

    // 地址过滤
    if (filter.addresses && filter.addresses.length > 0) {
      const addresses = filter.addresses.map(addr => addr.toLowerCase());
      if (!addresses.includes(tx.from.toLowerCase()) && 
          !addresses.includes(tx.to.toLowerCase())) {
        return false;
      }
    }

    return true;
  });
};

export const searchTransactions = (
  transactions: Transaction[],
  query: string
): Transaction[] => {
  if (!query.trim()) return transactions;

  const searchTerm = query.toLowerCase().trim();
  
  return transactions.filter(tx => {
    // 搜索交易哈希
    if (tx.hash.toLowerCase().includes(searchTerm)) return true;
    
    // 搜索地址
    if (tx.from.toLowerCase().includes(searchTerm)) return true;
    if (tx.to.toLowerCase().includes(searchTerm)) return true;
    
    // 搜索交易ID
    if (tx.id.toLowerCase().includes(searchTerm)) return true;
    
    // 根据交易类型搜索特定字段
    switch (tx.type) {
      case TransactionType.TOKEN_PURCHASE:
        const purchaseTx = tx as any;
        return purchaseTx.buyer?.toLowerCase().includes(searchTerm);
        
      case TransactionType.REFUND:
        const refundTx = tx as any;
        return refundTx.depositor?.toLowerCase().includes(searchTerm);
        
      case TransactionType.TOKEN_RELEASE:
        const releaseTx = tx as any;
        return releaseTx.beneficiary?.toLowerCase().includes(searchTerm) ||
               releaseTx.scheduleId?.toLowerCase().includes(searchTerm);
        
      case TransactionType.WHITELIST_ADD:
      case TransactionType.WHITELIST_REMOVE:
        const whitelistTx = tx as any;
        return whitelistTx.user?.toLowerCase().includes(searchTerm) ||
               whitelistTx.addedBy?.toLowerCase().includes(searchTerm);
        
      default:
        return false;
    }
  });
};

export const paginateTransactions = (
  transactions: Transaction[],
  page: number,
  pageSize: number
): Transaction[] => {
  const startIndex = (page - 1) * pageSize;
  const endIndex = startIndex + pageSize;
  return transactions.slice(startIndex, endIndex);
};

export const formatTimestamp = (timestamp: number): string => {
  const date = new Date(timestamp * 1000);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
};

export const formatAddress = (address: string, length: number = 8): string => {
  if (!address || address.length < length) return address;
  return `${address.slice(0, length)}...${address.slice(-4)}`;
};

export const formatTransactionHash = (hash: string): string => {
  return formatAddress(hash, 10);
};

export const getTransactionExplorerUrl = (hash: string, networkId?: number): string => {
  // 根据网络ID返回相应的区块链浏览器URL
  const explorers = {
    1: 'https://etherscan.io/tx/',
    11155111: 'https://sepolia.etherscan.io/tx/', // Sepolia
    31337: '#', // Local network
  };
  
  const baseUrl = explorers[networkId as keyof typeof explorers] || explorers[1];
  return `${baseUrl}${hash}`;
};

export const calculateGasFee = (gasUsed?: string, gasPrice?: string): string => {
  if (!gasUsed || !gasPrice) return '0';
  
  try {
    const fee = BigInt(gasUsed) * BigInt(gasPrice);
    return ethers.formatEther(fee.toString());
  } catch (error) {
    return '0';
  }
};

export const getTransactionSummary = (transaction: Transaction): string => {
  const typeLabel = getTransactionTypeLabel(transaction.type);
  const time = formatTimestamp(transaction.timestamp);
  
  switch (transaction.type) {
    case TransactionType.TOKEN_PURCHASE:
      const purchaseTx = transaction as any;
      const tokenAmount = formatTransactionValue(purchaseTx.tokenAmount);
      return `${typeLabel}: 购买了 ${parseFloat(tokenAmount).toFixed(2)} 代币 - ${time}`;
      
    case TransactionType.REFUND:
      const refundTx = transaction as any;
      const refundAmount = formatTransactionAmount(refundTx.amount);
      return `${typeLabel}: 退款 ${refundAmount} - ${time}`;
      
    case TransactionType.TOKEN_RELEASE:
      const releaseTx = transaction as any;
      const releaseAmount = formatTransactionValue(releaseTx.amount);
      return `${typeLabel}: 释放 ${parseFloat(releaseAmount).toFixed(2)} 代币 - ${time}`;
      
    default:
      return `${typeLabel} - ${time}`;
  }
};
