import { describe, it, expect } from 'vitest';
import {
  formatWeiToEther,
  formatTokenAmount,
  formatPercentage,
  formatLargeNumber,
  formatAddress,
  formatTimeRemaining,
  formatCrowdsalePhase,
  isValidAddress,
  isValidAmount,
  calculateProgress,
} from '@/utils/formatters';

describe('formatters', () => {
  describe('formatWeiToEther', () => {
    it('formats wei to ether correctly', () => {
      expect(formatWeiToEther(1000000000000000000n)).toBe('1.0000');
      expect(formatWeiToEther(500000000000000000n)).toBe('0.5000');
      expect(formatWeiToEther(1n)).toBe('0.0000');
    });

    it('formats with custom decimals', () => {
      expect(formatWeiToEther(1000000000000000000n, 2)).toBe('1.00');
      expect(formatWeiToEther(1500000000000000000n, 1)).toBe('1.5');
    });
  });

  describe('formatTokenAmount', () => {
    it('formats token amounts correctly', () => {
      expect(formatTokenAmount(1000000000000000000n)).toBe('1.00');
      expect(formatTokenAmount(500000000000000000n)).toBe('0.50');
    });
  });

  describe('formatPercentage', () => {
    it('formats basis points to percentage', () => {
      expect(formatPercentage(5000n)).toBe('50.00%');
      expect(formatPercentage(10000n)).toBe('100.00%');
      expect(formatPercentage(2500n)).toBe('25.00%');
    });
  });

  describe('formatLargeNumber', () => {
    it('formats large numbers with suffixes', () => {
      expect(formatLargeNumber(1000)).toBe('1.0K');
      expect(formatLargeNumber(1000000)).toBe('1.0M');
      expect(formatLargeNumber(1000000000)).toBe('1.0B');
      expect(formatLargeNumber(500)).toBe('500');
    });
  });

  describe('formatAddress', () => {
    it('truncates addresses correctly', () => {
      const address = '0x1234567890123456789012345678901234567890';
      expect(formatAddress(address)).toBe('0x1234...7890');
      expect(formatAddress(address, 4, 4)).toBe('0x12...7890');
    });

    it('returns original address if too short', () => {
      const shortAddress = '0x1234';
      expect(formatAddress(shortAddress)).toBe(shortAddress);
    });
  });

  describe('formatTimeRemaining', () => {
    it('returns "Ended" for past timestamps', () => {
      const pastTime = BigInt(Math.floor(Date.now() / 1000) - 3600);
      expect(formatTimeRemaining(pastTime)).toBe('Ended');
    });
  });

  describe('formatCrowdsalePhase', () => {
    it('formats phase numbers to strings', () => {
      expect(formatCrowdsalePhase(0)).toBe('Pending');
      expect(formatCrowdsalePhase(1)).toBe('Presale');
      expect(formatCrowdsalePhase(2)).toBe('Public Sale');
      expect(formatCrowdsalePhase(3)).toBe('Finalized');
      expect(formatCrowdsalePhase(99)).toBe('Unknown');
    });
  });

  describe('isValidAddress', () => {
    it('validates Ethereum addresses', () => {
      expect(isValidAddress('0x1234567890123456789012345678901234567890')).toBe(true);
      expect(isValidAddress('0x1234567890123456789012345678901234567890'.toLowerCase())).toBe(true);
      expect(isValidAddress('1234567890123456789012345678901234567890')).toBe(false);
      expect(isValidAddress('0x123')).toBe(false);
      expect(isValidAddress('')).toBe(false);
    });
  });

  describe('isValidAmount', () => {
    it('validates amount strings', () => {
      expect(isValidAmount('1.5')).toBe(true);
      expect(isValidAmount('0.001')).toBe(true);
      expect(isValidAmount('1000')).toBe(true);
      expect(isValidAmount('0')).toBe(false);
      expect(isValidAmount('-1')).toBe(false);
      expect(isValidAmount('abc')).toBe(false);
      expect(isValidAmount('')).toBe(false);
    });
  });

  describe('calculateProgress', () => {
    it('calculates progress percentage', () => {
      expect(calculateProgress(50n, 100n)).toBe(50);
      expect(calculateProgress(100n, 100n)).toBe(100);
      expect(calculateProgress(150n, 100n)).toBe(100); // Capped at 100
      expect(calculateProgress(0n, 100n)).toBe(0);
      expect(calculateProgress(50n, 0n)).toBe(0); // Avoid division by zero
    });
  });
});
