export interface WalletState {
  address: string | null;
  chainId: number | null;
  isConnected: boolean;
  isConnecting: boolean;
  balance: string;
  ensName?: string;
}

export interface NetworkConfig {
  id: number;
  name: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  rpcUrls: string[];
  blockExplorerUrls: string[];
}

export interface Transaction {
  hash: string;
  type: TransactionType;
  status: TransactionStatus;
  timestamp: number;
  data?: any;
  error?: string;
  gasUsed?: bigint;
  gasPrice?: bigint;
}

export enum TransactionType {
  PURCHASE = 'purchase',
  CREATE_CROWDSALE = 'create_crowdsale',
  RELEASE_TOKENS = 'release_tokens',
  REFUND = 'refund',
  APPROVE = 'approve',
  TRANSFER = 'transfer'
}

export enum TransactionStatus {
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  FAILED = 'failed'
}

export interface WalletError {
  code: number;
  message: string;
  data?: any;
}
