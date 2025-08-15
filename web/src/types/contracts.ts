// Contract types based on analyzed Solidity interfaces

export interface CrowdsaleConfig {
  presaleStartTime: bigint;
  presaleEndTime: bigint;
  publicSaleStartTime: bigint;
  publicSaleEndTime: bigint;
  softCap: bigint;
  hardCap: bigint;
  minPurchase: bigint;
  maxPurchase: bigint;
}

export interface CrowdsaleStats {
  totalRaised: bigint;
  totalTokensSold: bigint;
  totalPurchases: bigint;
  totalParticipants: bigint;
  participantCount: bigint;
  presaleRaised: bigint;
  publicSaleRaised: bigint;
}

export enum CrowdsalePhase {
  PENDING = 0,
  PRESALE = 1,
  PUBLIC_SALE = 2,
  FINALIZED = 3
}

export enum VestingType {
  LINEAR = 0,
  CLIFF = 1,
  STEPPED = 2,
  MILESTONE = 3,
  CUSTOM = 4
}

export interface VestingSchedule {
  beneficiary: string;
  totalAmount: bigint;
  startTime: bigint;
  cliffDuration: bigint;
  vestingDuration: bigint;
  releasedAmount: bigint;
  vestingType: VestingType;
  revocable: boolean;
  revoked: boolean;
}

export interface CrowdsaleParams {
  tokenName: string;
  tokenSymbol: string;
  totalSupply: bigint;
  softCap: bigint;
  hardCap: bigint;
  startTime: bigint;
  endTime: bigint;
  fundingWallet: string;
  tokenPrice: bigint;
  vestingParams: VestingParams;
}

export interface VestingParams {
  enabled: boolean;
  cliffDuration: bigint;
  vestingDuration: bigint;
  vestingType: VestingType;
  immediateReleasePercentage: bigint;
}

export interface CrowdsaleInstance {
  crowdsaleAddress: string;
  tokenAddress: string;
  vestingAddress: string;
  creator: string;
  createdAt: bigint;
  isActive: boolean;
}

export interface TokenInfo {
  name: string;
  symbol: string;
  decimals: number;
  totalSupply: bigint;
  maxSupply: bigint;
}

export interface PurchaseHistory {
  buyer: string;
  amount: bigint;
  tokenAmount: bigint;
  timestamp: bigint;
  phase: CrowdsalePhase;
}

export interface RefundInfo {
  depositor: string;
  amount: bigint;
  refunded: boolean;
  timestamp: bigint;
}
