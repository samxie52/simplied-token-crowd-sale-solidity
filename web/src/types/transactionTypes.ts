export enum TransactionType {
  TOKEN_PURCHASE = 'token_purchase',
  REFUND = 'refund',
  TOKEN_RELEASE = 'token_release',
  WHITELIST_ADD = 'whitelist_add',
  WHITELIST_REMOVE = 'whitelist_remove',
  PHASE_CHANGE = 'phase_change',
  CONFIG_UPDATE = 'config_update',
  EMERGENCY_ACTION = 'emergency_action',
  VESTING_CREATE = 'vesting_create',
  DEPOSIT = 'deposit'
}

export enum TransactionStatus {
  PENDING = 'pending',
  SUCCESS = 'success',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
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
  value?: string;
}

export interface TokenPurchaseTransaction extends BaseTransaction {
  type: TransactionType.TOKEN_PURCHASE;
  buyer: string;
  weiAmount: string;
  tokenAmount: string;
  tier?: string;
}

export interface RefundTransaction extends BaseTransaction {
  type: TransactionType.REFUND;
  depositor: string;
  amount: string;
  reason?: string;
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

export interface PhaseChangeTransaction extends BaseTransaction {
  type: TransactionType.PHASE_CHANGE;
  previousPhase: string;
  newPhase: string;
  changedBy: string;
}

export interface ConfigUpdateTransaction extends BaseTransaction {
  type: TransactionType.CONFIG_UPDATE;
  updatedBy: string;
  configType: string;
}

export interface EmergencyActionTransaction extends BaseTransaction {
  type: TransactionType.EMERGENCY_ACTION;
  action: string;
  executor: string;
  reason: string;
}

export interface VestingCreateTransaction extends BaseTransaction {
  type: TransactionType.VESTING_CREATE;
  beneficiary: string;
  scheduleId: string;
  totalAmount: string;
  vestingType: string;
}

export interface DepositTransaction extends BaseTransaction {
  type: TransactionType.DEPOSIT;
  depositor: string;
  amount: string;
}

export type Transaction = 
  | TokenPurchaseTransaction
  | RefundTransaction
  | TokenReleaseTransaction
  | WhitelistTransaction
  | PhaseChangeTransaction
  | ConfigUpdateTransaction
  | EmergencyActionTransaction
  | VestingCreateTransaction
  | DepositTransaction;

export interface TransactionFilter {
  types: TransactionType[];
  status: TransactionStatus[];
  dateRange: {
    start?: Date;
    end?: Date;
  };
  addresses: string[];
}

export interface PaginationInfo {
  currentPage: number;
  totalPages: number;
  pageSize: number;
  totalItems: number;
}
