import { ethers } from 'ethers';
import { getContractAddress, getContractABI } from './contracts';
import { 
  Transaction, 
  TransactionType, 
  TransactionStatus,
  TokenPurchaseTransaction,
  WhitelistTransaction
} from '../types/transactionTypes';

interface EventCallback {
  (transactions: Transaction[]): void;
}

export class TransactionEventListener {
  private provider: ethers.JsonRpcProvider | null = null;
  private contracts: { [key: string]: ethers.Contract } = {};
  private isInitialized = false;

  async initialize() {
    try {
      // Use a default provider for localhost
      this.provider = new ethers.JsonRpcProvider('http://localhost:8545');
      
      await this.initializeContracts();
      this.isInitialized = true;
    } catch (error) {
      console.error('Failed to initialize TransactionEventListener:', error);
      throw error;
    }
  }

  private async initializeContracts() {
    const contractConfigs = [
      { name: 'TokenCrowdsale', key: 'TokenCrowdsale' as const },
      { name: 'WhitelistManager', key: 'WhitelistManager' as const }
    ];
    
    for (const config of contractConfigs) {
      try {
        const address = getContractAddress(config.name);
        if (address && this.provider) {
          const abi = getContractABI(config.key);
          this.contracts[config.name] = new ethers.Contract(address, abi, this.provider);
        }
      } catch (error) {
        console.warn(`Failed to initialize ${config.name} contract:`, error);
      }
    }
  }

  async getHistoricalTransactions(fromBlock?: number, toBlock?: number): Promise<Transaction[]> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const transactions: Transaction[] = [];
    
    if (!this.provider) {
      console.error('Provider not initialized');
      return transactions;
    }

    try {
      const currentBlock = await this.provider.getBlockNumber();
      const startBlock = fromBlock || Math.max(0, currentBlock - 100); // Last 100 blocks for testing
      const endBlock = toBlock || currentBlock;

      // Get events from contracts
      const allEvents = await Promise.all([
        this.getTokenPurchaseEvents(startBlock, endBlock),
        this.getWhitelistEvents(startBlock, endBlock)
      ]);

      // Flatten and sort by block number
      const flatEvents = allEvents.flat();
      flatEvents.sort((a, b) => {
        if (a.blockNumber !== b.blockNumber) {
          return b.blockNumber - a.blockNumber; // Most recent first
        }
        return (b.index || 0) - (a.index || 0);
      });

      // Parse events into transactions
      for (const event of flatEvents) {
        try {
          const transaction = await this.parseEventToTransaction(event);
          if (transaction) {
            transactions.push(transaction);
          }
        } catch (error) {
          console.warn('Failed to parse event:', error);
        }
      }

    } catch (error) {
      console.error('Failed to fetch historical transactions:', error);
    }

    return transactions;
  }

  private async getTokenPurchaseEvents(fromBlock: number, toBlock: number) {
    const contract = this.contracts['TokenCrowdsale'];
    if (!contract) return [];

    try {
      // Try to get TokensPurchased events
      const events = await contract.queryFilter('TokensPurchased', fromBlock, toBlock);
      return events.map(event => ({
        ...event,
        contractName: 'TokenCrowdsale',
        eventName: 'TokensPurchased'
      }));
    } catch (error) {
      console.warn('Failed to fetch TokensPurchased events:', error);
      return [];
    }
  }

  private async getWhitelistEvents(fromBlock: number, toBlock: number) {
    const contract = this.contracts['WhitelistManager'];
    if (!contract) return [];

    try {
      const events = [];
      
      // Try to get WhitelistAdded events
      try {
        const addedEvents = await contract.queryFilter('WhitelistAdded', fromBlock, toBlock);
        events.push(...addedEvents.map(event => ({ 
          ...event, 
          contractName: 'WhitelistManager', 
          eventName: 'WhitelistAdded' 
        })));
      } catch (e) {
        console.warn('WhitelistAdded events not available:', e);
      }

      // Try to get WhitelistRemoved events
      try {
        const removedEvents = await contract.queryFilter('WhitelistRemoved', fromBlock, toBlock);
        events.push(...removedEvents.map(event => ({ 
          ...event, 
          contractName: 'WhitelistManager', 
          eventName: 'WhitelistRemoved' 
        })));
      } catch (e) {
        console.warn('WhitelistRemoved events not available:', e);
      }
      
      return events;
    } catch (error) {
      console.warn('Failed to fetch whitelist events:', error);
      return [];
    }
  }

  private async parseEventToTransaction(event: any): Promise<Transaction | null> {
    try {
      if (event.eventName === 'TokensPurchased') {
        return await this.parseTokenPurchaseEvent(event);
      } else if (event.eventName === 'WhitelistAdded' || event.eventName === 'WhitelistRemoved') {
        return await this.parseWhitelistEvent(event);
      }
    } catch (error) {
      console.warn('Failed to parse event:', error);
    }
    return null;
  }

  private async parseTokenPurchaseEvent(event: any): Promise<TokenPurchaseTransaction> {
    if (!this.provider) throw new Error('Provider not initialized');
    
    const block = await this.provider.getBlock(event.blockNumber);
    const tx = await this.provider.getTransaction(event.transactionHash);
    
    return {
      id: `${event.transactionHash}-${event.index || 0}`,
      type: TransactionType.TOKEN_PURCHASE,
      status: TransactionStatus.SUCCESS,
      hash: event.transactionHash,
      blockNumber: event.blockNumber,
      timestamp: block?.timestamp || Math.floor(Date.now() / 1000),
      from: event.args?.[0] || '', // buyer
      to: event.args?.[1] || '', // crowdsale
      buyer: event.args?.[0] || '',
      weiAmount: event.args?.[2]?.toString() || '0',
      tokenAmount: event.args?.[3]?.toString() || '0',
      gasUsed: tx?.gasLimit?.toString() || '0',
      gasPrice: tx?.gasPrice?.toString() || '0'
    };
  }

  private async parseWhitelistEvent(event: any): Promise<WhitelistTransaction> {
    if (!this.provider) throw new Error('Provider not initialized');
    
    const block = await this.provider.getBlock(event.blockNumber);
    const tx = await this.provider.getTransaction(event.transactionHash);
    const isAddition = event.eventName === 'WhitelistAdded';
    
    return {
      id: `${event.transactionHash}-${event.index || 0}`,
      type: isAddition ? TransactionType.WHITELIST_ADD : TransactionType.WHITELIST_REMOVE,
      status: TransactionStatus.SUCCESS,
      hash: event.transactionHash,
      blockNumber: event.blockNumber,
      timestamp: block?.timestamp || Math.floor(Date.now() / 1000),
      from: event.args?.[3] || event.args?.[2] || '', // addedBy or removedBy
      to: event.args?.[0] || '', // user
      user: event.args?.[0] || '',
      level: event.args?.[1]?.toString() || '0',
      addedBy: event.args?.[3] || event.args?.[2] || '',
      gasUsed: tx?.gasLimit?.toString() || '0',
      gasPrice: tx?.gasPrice?.toString() || '0'
    };
  }

  // Simplified real-time listening
  startListening(callback: EventCallback) {
    console.log('Real-time event listening started (simplified implementation)');
    // For now, just return empty - real implementation would set up event listeners
    callback([]);
  }

  stopListening() {
    console.log('Event listening stopped');
  }
}
