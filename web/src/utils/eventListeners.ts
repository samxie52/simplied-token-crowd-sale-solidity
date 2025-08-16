import { ethers } from 'ethers';
import { getContractAddress, getContractABI } from './contracts';
import { 
  Transaction, 
  TransactionType, 
  TransactionStatus,
  TokenPurchaseTransaction,
  RefundTransaction,
  TokenReleaseTransaction,
  WhitelistTransaction,
  PhaseChangeTransaction,
  EmergencyActionTransaction,
  VestingCreateTransaction,
  DepositTransaction
} from '../types/transactionTypes';

export class TransactionEventListener {
  private provider: ethers.Provider | null = null;
  private contracts: Map<string, ethers.Contract> = new Map();
  private listeners: Map<string, (...args: any[]) => void> = new Map();

  async initialize() {
    this.provider = await getProvider();
    if (!this.provider) {
      throw new Error('Provider not available');
    }

    // 初始化合约实例
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
        try {
          const abi = getContractABI(config.name);
          const contract = new ethers.Contract(address, abi, this.provider!);
          this.contracts.set(config.name, contract);
        } catch (error) {
          console.warn(`Failed to initialize ${config.name} contract:`, error);
        }
      }
    }
  }

  async getHistoricalTransactions(
    userAddress?: string,
    fromBlock: number = 0,
    toBlock: number | string = 'latest'
  ): Promise<Transaction[]> {
    const transactions: Transaction[] = [];

    // 获取TokenCrowdsale事件
    await this.getTokenCrowdsaleEvents(transactions, userAddress, fromBlock, toBlock);
    
    // 获取RefundVault事件
    await this.getRefundVaultEvents(transactions, userAddress, fromBlock, toBlock);
    
    // 获取TokenVesting事件
    await this.getTokenVestingEvents(transactions, userAddress, fromBlock, toBlock);
    
    // 获取WhitelistManager事件
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
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: TokenPurchaseTransaction = {
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
        } catch (error) {
          console.warn('Error processing TokensPurchased event:', error);
        }
      }

      // PhaseChanged事件
      const phaseFilter = contract.filters.PhaseChanged();
      const phaseEvents = await contract.queryFilter(phaseFilter, fromBlock, toBlock);

      for (const event of phaseEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: PhaseChangeTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.PHASE_CHANGE,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![2]),
            blockNumber: event.blockNumber,
            from: event.args![3],
            to: contract.target as string,
            previousPhase: event.args![0].toString(),
            newPhase: event.args![1].toString(),
            changedBy: event.args![3],
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing PhaseChanged event:', error);
        }
      }

      // EmergencyAction事件
      const emergencyFilter = contract.filters.EmergencyAction();
      const emergencyEvents = await contract.queryFilter(emergencyFilter, fromBlock, toBlock);

      for (const event of emergencyEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: EmergencyActionTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.EMERGENCY_ACTION,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![2]),
            blockNumber: event.blockNumber,
            from: event.args![1],
            to: contract.target as string,
            action: event.args![0],
            executor: event.args![1],
            reason: event.args![3],
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing EmergencyAction event:', error);
        }
      }

    } catch (error) {
      console.error('Error fetching TokenCrowdsale events:', error);
    }
  }

  private async getRefundVaultEvents(
    transactions: Transaction[],
    userAddress?: string,
    fromBlock: number,
    toBlock: number | string
  ) {
    const contract = this.contracts.get('RefundVault');
    if (!contract) return;

    try {
      // Deposited事件
      const depositFilter = contract.filters.Deposited(
        userAddress ? userAddress : null
      );
      const depositEvents = await contract.queryFilter(depositFilter, fromBlock, toBlock);

      for (const event of depositEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: DepositTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.DEPOSIT,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![2]),
            blockNumber: event.blockNumber,
            from: event.args![0],
            to: contract.target as string,
            depositor: event.args![0],
            amount: event.args![1].toString(),
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing Deposited event:', error);
        }
      }

      // Refunded事件
      const refundFilter = contract.filters.Refunded(
        userAddress ? userAddress : null
      );
      const refundEvents = await contract.queryFilter(refundFilter, fromBlock, toBlock);

      for (const event of refundEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: RefundTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.REFUND,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![2]),
            blockNumber: event.blockNumber,
            from: contract.target as string,
            to: event.args![0],
            depositor: event.args![0],
            amount: event.args![1].toString(),
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing Refunded event:', error);
        }
      }

    } catch (error) {
      console.error('Error fetching RefundVault events:', error);
    }
  }

  private async getTokenVestingEvents(
    transactions: Transaction[],
    userAddress?: string,
    fromBlock: number,
    toBlock: number | string
  ) {
    const contract = this.contracts.get('TokenVesting');
    if (!contract) return;

    try {
      // VestingScheduleCreated事件
      const createFilter = contract.filters.VestingScheduleCreated(
        userAddress ? userAddress : null
      );
      const createEvents = await contract.queryFilter(createFilter, fromBlock, toBlock);

      for (const event of createEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: VestingCreateTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.VESTING_CREATE,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![4]),
            blockNumber: event.blockNumber,
            from: receipt?.from || '',
            to: contract.target as string,
            beneficiary: event.args![0],
            scheduleId: event.args![1].toString(),
            totalAmount: event.args![2].toString(),
            vestingType: event.args![3].toString(),
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing VestingScheduleCreated event:', error);
        }
      }

      // TokensReleased事件
      const releaseFilter = contract.filters.TokensReleased(
        userAddress ? userAddress : null
      );
      const releaseEvents = await contract.queryFilter(releaseFilter, fromBlock, toBlock);

      for (const event of releaseEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: TokenReleaseTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.TOKEN_RELEASE,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![3]),
            blockNumber: event.blockNumber,
            from: contract.target as string,
            to: event.args![0],
            beneficiary: event.args![0],
            scheduleId: event.args![1].toString(),
            amount: event.args![2].toString(),
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing TokensReleased event:', error);
        }
      }

    } catch (error) {
      console.error('Error fetching TokenVesting events:', error);
    }
  }

  private async getWhitelistEvents(
    transactions: Transaction[],
    userAddress?: string,
    fromBlock: number,
    toBlock: number | string
  ) {
    const contract = this.contracts.get('WhitelistManager');
    if (!contract) return;

    try {
      // WhitelistAdded事件
      const addFilter = contract.filters.WhitelistAdded(
        userAddress ? userAddress : null
      );
      const addEvents = await contract.queryFilter(addFilter, fromBlock, toBlock);

      for (const event of addEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: WhitelistTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.WHITELIST_ADD,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Number(event.args![2]) || Date.now() / 1000,
            blockNumber: event.blockNumber,
            from: event.args![3],
            to: contract.target as string,
            user: event.args![0],
            level: event.args![1].toString(),
            addedBy: event.args![3],
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing WhitelistAdded event:', error);
        }
      }

      // WhitelistRemoved事件
      const removeFilter = contract.filters.WhitelistRemoved(
        userAddress ? userAddress : null
      );
      const removeEvents = await contract.queryFilter(removeFilter, fromBlock, toBlock);

      for (const event of removeEvents) {
        try {
          const receipt = await event.getTransactionReceipt();
          const tx: WhitelistTransaction = {
            id: `${event.transactionHash}-${event.logIndex}`,
            hash: event.transactionHash,
            type: TransactionType.WHITELIST_REMOVE,
            status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
            timestamp: Date.now() / 1000, // 使用当前时间，因为事件中没有timestamp
            blockNumber: event.blockNumber,
            from: event.args![2],
            to: contract.target as string,
            user: event.args![0],
            level: event.args![1].toString(),
            addedBy: event.args![2],
            gasUsed: receipt?.gasUsed.toString(),
            gasPrice: receipt?.gasPrice?.toString()
          };
          transactions.push(tx);
        } catch (error) {
          console.warn('Error processing WhitelistRemoved event:', error);
        }
      }

    } catch (error) {
      console.error('Error fetching WhitelistManager events:', error);
    }
  }

  startRealTimeListening(callback: (transaction: Transaction) => void) {
    // 实现实时事件监听
    this.contracts.forEach((contract, name) => {
      const eventNames = this.getContractEventNames(name);
      
      eventNames.forEach(eventName => {
        try {
          const listener = async (...args: any[]) => {
            try {
              const event = args[args.length - 1]; // 最后一个参数是事件对象
              const transaction = await this.parseEventToTransaction(event, name, eventName);
              if (transaction) {
                callback(transaction);
              }
            } catch (error) {
              console.error(`Error parsing real-time event ${eventName} from ${name}:`, error);
            }
          };

          contract.on(eventName, listener);
          this.listeners.set(`${name}-${eventName}`, listener);
        } catch (error) {
          console.warn(`Failed to set up listener for ${eventName} on ${name}:`, error);
        }
      });
    });
  }

  private getContractEventNames(contractName: string): string[] {
    const eventMap = {
      'TokenCrowdsale': ['TokensPurchased', 'PhaseChanged', 'EmergencyAction', 'ConfigUpdated'],
      'RefundVault': ['Deposited', 'Refunded', 'RefundFailed'],
      'TokenVesting': ['VestingScheduleCreated', 'TokensReleased', 'VestingRevoked'],
      'WhitelistManager': ['WhitelistAdded', 'WhitelistRemoved', 'BatchWhitelistAdded']
    };
    
    return eventMap[contractName as keyof typeof eventMap] || [];
  }

  private async parseEventToTransaction(
    event: ethers.EventLog,
    contractName: string,
    eventName: string
  ): Promise<Transaction | null> {
    try {
      const receipt = await event.getTransactionReceipt();
      const baseTransaction = {
        id: `${event.transactionHash}-${event.logIndex}`,
        hash: event.transactionHash,
        status: receipt?.status === 1 ? TransactionStatus.SUCCESS : TransactionStatus.FAILED,
        blockNumber: event.blockNumber,
        gasUsed: receipt?.gasUsed.toString(),
        gasPrice: receipt?.gasPrice?.toString()
      };

      // 根据合约和事件名称解析具体的交易类型
      switch (contractName) {
        case 'TokenCrowdsale':
          return this.parseTokenCrowdsaleEvent(event, eventName, baseTransaction);
        case 'RefundVault':
          return this.parseRefundVaultEvent(event, eventName, baseTransaction);
        case 'TokenVesting':
          return this.parseTokenVestingEvent(event, eventName, baseTransaction);
        case 'WhitelistManager':
          return this.parseWhitelistEvent(event, eventName, baseTransaction);
        default:
          return null;
      }
    } catch (error) {
      console.error('Error parsing event to transaction:', error);
      return null;
    }
  }

  private parseTokenCrowdsaleEvent(event: ethers.EventLog, eventName: string, base: any): Transaction | null {
    const contract = this.contracts.get('TokenCrowdsale');
    if (!contract) return null;

    switch (eventName) {
      case 'TokensPurchased':
        return {
          ...base,
          type: TransactionType.TOKEN_PURCHASE,
          timestamp: Number(event.args![3]),
          from: event.args![0],
          to: contract.target as string,
          buyer: event.args![0],
          weiAmount: event.args![1].toString(),
          tokenAmount: event.args![2].toString()
        } as TokenPurchaseTransaction;

      case 'PhaseChanged':
        return {
          ...base,
          type: TransactionType.PHASE_CHANGE,
          timestamp: Number(event.args![2]),
          from: event.args![3],
          to: contract.target as string,
          previousPhase: event.args![0].toString(),
          newPhase: event.args![1].toString(),
          changedBy: event.args![3]
        } as PhaseChangeTransaction;

      case 'EmergencyAction':
        return {
          ...base,
          type: TransactionType.EMERGENCY_ACTION,
          timestamp: Number(event.args![2]),
          from: event.args![1],
          to: contract.target as string,
          action: event.args![0],
          executor: event.args![1],
          reason: event.args![3]
        } as EmergencyActionTransaction;

      default:
        return null;
    }
  }

  private parseRefundVaultEvent(event: ethers.EventLog, eventName: string, base: any): Transaction | null {
    const contract = this.contracts.get('RefundVault');
    if (!contract) return null;

    switch (eventName) {
      case 'Deposited':
        return {
          ...base,
          type: TransactionType.DEPOSIT,
          timestamp: Number(event.args![2]),
          from: event.args![0],
          to: contract.target as string,
          depositor: event.args![0],
          amount: event.args![1].toString()
        } as DepositTransaction;

      case 'Refunded':
        return {
          ...base,
          type: TransactionType.REFUND,
          timestamp: Number(event.args![2]),
          from: contract.target as string,
          to: event.args![0],
          depositor: event.args![0],
          amount: event.args![1].toString()
        } as RefundTransaction;

      default:
        return null;
    }
  }

  private parseTokenVestingEvent(event: ethers.EventLog, eventName: string, base: any): Transaction | null {
    const contract = this.contracts.get('TokenVesting');
    if (!contract) return null;

    switch (eventName) {
      case 'VestingScheduleCreated':
        return {
          ...base,
          type: TransactionType.VESTING_CREATE,
          timestamp: Number(event.args![4]),
          from: base.from || '',
          to: contract.target as string,
          beneficiary: event.args![0],
          scheduleId: event.args![1].toString(),
          totalAmount: event.args![2].toString(),
          vestingType: event.args![3].toString()
        } as VestingCreateTransaction;

      case 'TokensReleased':
        return {
          ...base,
          type: TransactionType.TOKEN_RELEASE,
          timestamp: Number(event.args![3]),
          from: contract.target as string,
          to: event.args![0],
          beneficiary: event.args![0],
          scheduleId: event.args![1].toString(),
          amount: event.args![2].toString()
        } as TokenReleaseTransaction;

      default:
        return null;
    }
  }

  private parseWhitelistEvent(event: ethers.EventLog, eventName: string, base: any): Transaction | null {
    const contract = this.contracts.get('WhitelistManager');
    if (!contract) return null;

    switch (eventName) {
      case 'WhitelistAdded':
        return {
          ...base,
          type: TransactionType.WHITELIST_ADD,
          timestamp: Number(event.args![2]) || Date.now() / 1000,
          from: event.args![3],
          to: contract.target as string,
          user: event.args![0],
          level: event.args![1].toString(),
          addedBy: event.args![3]
        } as WhitelistTransaction;

      case 'WhitelistRemoved':
        return {
          ...base,
          type: TransactionType.WHITELIST_REMOVE,
          timestamp: Date.now() / 1000,
          from: event.args![2],
          to: contract.target as string,
          user: event.args![0],
          level: event.args![1].toString(),
          addedBy: event.args![2]
        } as WhitelistTransaction;

      default:
        return null;
    }
  }

  stopListening() {
    this.contracts.forEach((contract, name) => {
      contract.removeAllListeners();
    });
    this.listeners.clear();
  }

  destroy() {
    this.stopListening();
    this.contracts.clear();
    this.provider = null;
  }
}
