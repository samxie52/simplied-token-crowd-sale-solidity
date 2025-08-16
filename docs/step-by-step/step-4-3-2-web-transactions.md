# Step 4.3.2: Web交易历史页面实现

## 目标概述

实现完整的交易历史页面，替换模拟数据为真实的区块链交易数据，提供用户友好的交易查询、过滤和展示功能。

## 功能需求

### 核心功能
1. **交易数据获取**: 从区块链事件日志获取真实交易数据
2. **交易类型支持**: 支持多种交易类型的展示和过滤
3. **实时数据同步**: 监听新交易并实时更新界面
4. **高级过滤**: 按交易类型、状态、时间范围过滤
5. **搜索功能**: 支持交易哈希、地址搜索
6. **分页展示**: 处理大量交易数据的分页显示
7. **交易详情**: 提供详细的交易信息展示

### 支持的交易类型
- **代币购买** (Token Purchase)
- **退款** (Refund)
- **代币释放** (Token Release)
- **白名单管理** (Whitelist Management)
- **众筹管理** (Crowdsale Management)
- **紧急操作** (Emergency Actions)

## 技术架构

### 数据流程
```
区块链事件 → 事件监听器 → 数据处理 → 状态管理 → UI展示
```

### 核心组件
1. **TransactionHistory.tsx** - 主组件
2. **useTransactionHistory.ts** - 交易数据管理Hook
3. **transactionTypes.ts** - 交易类型定义
4. **eventListeners.ts** - 区块链事件监听
5. **transactionUtils.ts** - 交易数据处理工具

## 合约事件映射

### 1. TokenCrowdsale合约事件
```solidity
// 代币购买事件
event TokensPurchased(
    address indexed buyer,
    uint256 weiAmount,
    uint256 tokenAmount,
    uint256 timestamp
);

// 阶段变更事件
event PhaseChanged(
    CrowdsalePhase indexed previousPhase,
    CrowdsalePhase indexed newPhase,
    uint256 timestamp,
    address indexed changedBy
);

// 紧急操作事件
event EmergencyAction(
    string action,
    address indexed executor,
    uint256 timestamp,
    string reason
);
```

### 2. RefundVault合约事件
```solidity
// 退款事件
event Refunded(
    address indexed depositor,
    uint256 amount,
    uint256 timestamp
);
```

### 3. TokenVesting合约事件
```solidity
// 代币释放事件
event TokensReleased(
    address indexed beneficiary,
    uint256 indexed scheduleId,
    uint256 amount,
    uint256 timestamp
);
```

### 4. WhitelistManager合约事件
```solidity
// 白名单添加事件
event WhitelistAdded(
    address indexed user,
    WhitelistLevel indexed level,
    uint256 expirationTime,
    address indexed addedBy
);

// 白名单移除事件
event WhitelistRemoved(
    address indexed user,
    WhitelistLevel previousLevel,
    address indexed removedBy
);
```

## 实现步骤

### 第一步: 定义交易类型和数据结构

创建 `web/src/types/transactionTypes.ts`:

```typescript
export enum TransactionType {
  TOKEN_PURCHASE = 'token_purchase',
  REFUND = 'refund',
  TOKEN_RELEASE = 'token_release',
  WHITELIST_ADD = 'whitelist_add',
  WHITELIST_REMOVE = 'whitelist_remove',
  PHASE_CHANGE = 'phase_change',
  EMERGENCY_ACTION = 'emergency_action'
}

export enum TransactionStatus {
  PENDING = 'pending',
  SUCCESS = 'success',
  FAILED = 'failed'
}

export interface BaseTransaction {
  id: string;
  hash: string;
  type: TransactionType;
  status: TransactionStatus;
  timestamp: number;
  blockNumber: number;
  from: string;
  to: string;
  gasUsed?: string;
  gasPrice?: string;
}

export interface TokenPurchaseTransaction extends BaseTransaction {
  type: TransactionType.TOKEN_PURCHASE;
  buyer: string;
  weiAmount: string;
  tokenAmount: string;
}

export interface RefundTransaction extends BaseTransaction {
  type: TransactionType.REFUND;
  depositor: string;
  amount: string;
}

export interface TokenReleaseTransaction extends BaseTransaction {
  type: TransactionType.TOKEN_RELEASE;
  beneficiary: string;
  scheduleId: string;
  amount: string;
}

export interface WhitelistTransaction extends BaseTransaction {
  type: TransactionType.WHITELIST_ADD | TransactionType.WHITELIST_REMOVE;
  user: string;
  level: string;
  addedBy: string;
}

export type Transaction = 
  | TokenPurchaseTransaction
  | RefundTransaction
  | TokenReleaseTransaction
  | WhitelistTransaction;

export interface TransactionFilter {
  types: TransactionType[];
  status: TransactionStatus[];
  dateRange: {
    start?: Date;
    end?: Date;
  };
  addresses: string[];
}
```

### 第二步: 创建工具函数

创建 `web/src/utils/transactionUtils.ts`:

```typescript
import { ethers } from 'ethers';
import { TransactionType, TransactionStatus } from '../types/transactionTypes';

export const getTransactionTypeLabel = (type: TransactionType): string => {
  const labels = {
    [TransactionType.TOKEN_PURCHASE]: '代币购买',
    [TransactionType.REFUND]: '退款',
    [TransactionType.TOKEN_RELEASE]: '代币释放',
    [TransactionType.WHITELIST_ADD]: '添加白名单',
    [TransactionType.WHITELIST_REMOVE]: '移除白名单',
    [TransactionType.PHASE_CHANGE]: '阶段变更',
    [TransactionType.EMERGENCY_ACTION]: '紧急操作'
  };
  return labels[type] || type;
};

export const getTransactionStatusLabel = (status: TransactionStatus): string => {
  const labels = {
    [TransactionStatus.PENDING]: '待确认',
    [TransactionStatus.SUCCESS]: '成功',
    [TransactionStatus.FAILED]: '失败'
  };
  return labels[status] || status;
};

export const formatTransactionValue = (value: string, decimals: number = 18): string => {
  return ethers.formatUnits(value, decimals);
};

export const getTransactionIcon = (type: TransactionType): string => {
  const icons = {
    [TransactionType.TOKEN_PURCHASE]: 'shopping-cart',
    [TransactionType.REFUND]: 'arrow-left',
    [TransactionType.TOKEN_RELEASE]: 'unlock',
    [TransactionType.WHITELIST_ADD]: 'user-plus',
    [TransactionType.WHITELIST_REMOVE]: 'user-minus',
    [TransactionType.PHASE_CHANGE]: 'arrow-right',
    [TransactionType.EMERGENCY_ACTION]: 'exclamation-triangle'
  };
  return icons[type] || 'document';
};
```

### 第三步: 实现事件监听器

创建 `web/src/utils/eventListeners.ts`:

```typescript
import { ethers } from 'ethers';
import { getProvider, getContractAddress, getContractABI } from './contracts';
import { Transaction, TransactionType, TransactionStatus } from '../types/transactionTypes';

export class TransactionEventListener {
  private provider: ethers.Provider | null = null;
  private contracts: Map<string, ethers.Contract> = new Map();

  async initialize() {
    this.provider = await getProvider();
    if (!this.provider) {
      throw new Error('Provider not available');
    }
    await this.initializeContracts();
  }

  private async initializeContracts() {
    const contractConfigs = [
      { name: 'TokenCrowdsale', key: 'TOKENCROWDSALE' },
      { name: 'RefundVault', key: 'REFUNDVAULT' },
      { name: 'TokenVesting', key: 'TOKENVESTING' },
      { name: 'WhitelistManager', key: 'WHITELISTMANAGER' }
    ];

    for (const config of contractConfigs) {
      const address = getContractAddress(config.key);
      if (address) {
        const abi = getContractABI(config.name);
        const contract = new ethers.Contract(address, abi, this.provider!);
        this.contracts.set(config.name, contract);
      }
    }
  }

  async getHistoricalTransactions(
    userAddress?: string,
    fromBlock: number = 0,
    toBlock: number | string = 'latest'
  ): Promise<Transaction[]> {
    const transactions: Transaction[] = [];

    // 获取各合约事件
    await this.getTokenCrowdsaleEvents(transactions, userAddress, fromBlock, toBlock);
    await this.getRefundVaultEvents(transactions, userAddress, fromBlock, toBlock);
    await this.getTokenVestingEvents(transactions, userAddress, fromBlock, toBlock);
    await this.getWhitelistEvents(transactions, userAddress, fromBlock, toBlock);

    return transactions.sort((a, b) => b.timestamp - a.timestamp);
  }

  private async getTokenCrowdsaleEvents(
    transactions: Transaction[],
    userAddress?: string,
    fromBlock: number,
    toBlock: number | string
  ) {
    const contract = this.contracts.get('TokenCrowdsale');
    if (!contract) return;

    try {
      // TokensPurchased事件
      const purchaseFilter = contract.filters.TokensPurchased(
        userAddress ? userAddress : null
      );
      const purchaseEvents = await contract.queryFilter(purchaseFilter, fromBlock, toBlock);

      for (const event of purchaseEvents) {
        const receipt = await event.getTransactionReceipt();
        const tx = {
          id: `${event.transactionHash}-${event.logIndex}`,
          hash: event.transactionHash,
          type: TransactionType.TOKEN_PURCHASE,
          status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
          timestamp: Number(event.args![3]),
          blockNumber: event.blockNumber,
          from: event.args![0],
          to: contract.target as string,
          buyer: event.args![0],
          weiAmount: event.args![1].toString(),
          tokenAmount: event.args![2].toString(),
          gasUsed: receipt?.gasUsed.toString(),
          gasPrice: receipt?.gasPrice?.toString()
        };
        transactions.push(tx);
      }
    } catch (error) {
      console.error('Error fetching TokenCrowdsale events:', error);
    }
  }

  startRealTimeListening(callback: (transaction: Transaction) => void) {
    this.contracts.forEach((contract) => {
      contract.on('*', async (event) => {
        try {
          const transaction = await this.parseEventToTransaction(event);
          if (transaction) {
            callback(transaction);
          }
        } catch (error) {
          console.error('Error parsing event:', error);
        }
      });
    });
  }

  private async parseEventToTransaction(event: ethers.EventLog): Promise<Transaction | null> {
    // 实现事件解析逻辑
    return null;
  }

  destroy() {
    this.contracts.forEach(contract => {
      contract.removeAllListeners();
    });
    this.contracts.clear();
    this.provider = null;
  }
}
```

### 第四步: 实现交易历史Hook

创建 `web/src/hooks/useTransactionHistory.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';
import { useAccount } from 'wagmi';
import { Transaction, TransactionFilter } from '../types/transactionTypes';
import { TransactionEventListener } from '../utils/eventListeners';

export const useTransactionHistory = () => {
  const { address, isConnected } = useAccount();
  
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Partial<TransactionFilter>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const [eventListener, setEventListener] = useState<TransactionEventListener | null>(null);

  // 初始化事件监听器
  useEffect(() => {
    if (isConnected) {
      const listener = new TransactionEventListener();
      listener.initialize().then(() => {
        setEventListener(listener);
        
        // 开始实时监听
        listener.startRealTimeListening((newTransaction) => {
          setTransactions(prev => [newTransaction, ...prev]);
        });
      }).catch(err => {
        setError('Failed to initialize transaction listener');
      });

      return () => {
        listener.destroy();
      };
    }
  }, [isConnected]);

  // 获取历史交易数据
  const fetchTransactions = useCallback(async () => {
    if (!eventListener || !isConnected) return;

    setIsLoading(true);
    setError(null);

    try {
      const historicalTransactions = await eventListener.getHistoricalTransactions(
        address,
        0,
        'latest'
      );
      setTransactions(historicalTransactions);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch transactions');
    } finally {
      setIsLoading(false);
    }
  }, [eventListener, isConnected, address]);

  // 初始加载
  useEffect(() => {
    if (eventListener && isConnected) {
      fetchTransactions();
    }
  }, [eventListener, isConnected, fetchTransactions]);

  // 应用过滤和搜索
  useEffect(() => {
    let result = [...transactions];

    // 应用搜索
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase().trim();
      result = result.filter(tx => 
        tx.hash.toLowerCase().includes(query) ||
        tx.from.toLowerCase().includes(query) ||
        tx.to.toLowerCase().includes(query)
      );
    }

    setFilteredTransactions(result);
  }, [transactions, filter, searchQuery]);

  return {
    transactions,
    filteredTransactions,
    isLoading,
    error,
    filter,
    searchQuery,
    setFilter,
    setSearchQuery,
    refreshTransactions: fetchTransactions
  };
};
```

### 第五步: 更新TransactionHistory组件

修改 `web/src/pages/TransactionHistory.tsx`:

```typescript
// 替换模拟数据逻辑为真实数据
import { useTransactionHistory } from '../hooks/useTransactionHistory';
import { getTransactionTypeLabel, getTransactionIcon } from '../utils/transactionUtils';

const TransactionHistory: React.FC = () => {
  const {
    filteredTransactions,
    isLoading,
    error,
    searchQuery,
    setSearchQuery,
    refreshTransactions
  } = useTransactionHistory();

  // 移除模拟数据相关代码
  // 使用真实的filteredTransactions数据
  
  return (
    <div className="container mx-auto px-4 py-8">
      {/* 现有UI保持不变，只需要替换数据源 */}
    </div>
  );
};
```

## 测试策略

### 单元测试
1. **transactionUtils.ts** - 工具函数测试
2. **eventListeners.ts** - 事件监听器测试
3. **useTransactionHistory.ts** - Hook测试

### 集成测试
1. **完整交易流程测试** - 从购买到显示
2. **过滤和搜索功能测试**
3. **实时更新测试**

### 端到端测试
1. **用户交易历史查看**
2. **交易详情展示**
3. **错误处理和重试**

## 部署和监控

### 性能优化
1. **事件查询优化** - 分批查询历史事件
2. **缓存策略** - 本地缓存交易数据
3. **分页加载** - 大量数据分页处理

### 错误处理
1. **网络错误重试**
2. **合约调用失败处理**
3. **用户友好的错误提示**

### 监控指标
1. **交易数据加载时间**
2. **事件监听成功率**
3. **用户操作响应时间**

## 总结

本文档详细描述了交易历史页面的完整实现方案，包括：

1. **数据结构设计** - 完整的交易类型定义
2. **事件监听** - 实时和历史数据获取
3. **状态管理** - 高效的数据管理Hook
4. **UI集成** - 与现有组件的无缝集成
5. **测试策略** - 全面的测试覆盖

实现后将提供完整的区块链交易历史查询功能，支持实时更新、高级过滤和用户友好的界面展示。
