import '@testing-library/jest-dom';
import { vi } from 'vitest';

// Mock window.ethereum for wallet tests
Object.defineProperty((global as any).window, 'ethereum', {
  writable: true,
  value: {
    isMetaMask: true,
    isConnected: () => true,
    request: vi.fn(),
    on: vi.fn(),
    removeListener: vi.fn(),
  },
});

// Mock environment variables
Object.defineProperty(import.meta, 'env', {
  value: {
    VITE_NETWORK_ID: '31337',
    VITE_FACTORY_ADDRESS: '0x1234567890123456789012345678901234567890',
    VITE_REFRESH_INTERVAL: '10000',
  },
});
