// Network configurations
export const SUPPORTED_NETWORKS = {
  1: {
    id: 1,
    name: 'Ethereum Mainnet',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: ['https://mainnet.infura.io/v3/'],
    blockExplorerUrls: ['https://etherscan.io'],
  },
  11155111: {
    id: 11155111,
    name: 'Sepolia',
    nativeCurrency: {
      name: 'Sepolia Ether',
      symbol: 'SEP',
      decimals: 18,
    },
    rpcUrls: ['https://sepolia.infura.io/v3/'],
    blockExplorerUrls: ['https://sepolia.etherscan.io'],
  },
  31337: {
    id: 31337,
    name: 'Localhost',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: ['http://127.0.0.1:8545'],
    blockExplorerUrls: [''],
  },
} as const;

// Contract addresses (will be set via environment variables)
export const CONTRACT_ADDRESSES = {
  CROWDSALE_FACTORY: import.meta.env.VITE_FACTORY_ADDRESS || '',
  // Other addresses will be fetched dynamically from factory
} as const;

// Application constants
export const APP_CONFIG = {
  DEFAULT_NETWORK_ID: 31337, // Localhost for development
  REFRESH_INTERVAL: 10000, // 10 seconds
  TRANSACTION_TIMEOUT: 300000, // 5 minutes
  MAX_RETRIES: 3,
  ITEMS_PER_PAGE: 10,
} as const;

// UI constants
export const UI_CONFIG = {
  TOAST_DURATION: 5000,
  ANIMATION_DURATION: 300,
  DEBOUNCE_DELAY: 500,
} as const;

// Format constants
export const FORMAT_CONFIG = {
  TOKEN_DECIMALS: 18,
  PERCENTAGE_DECIMALS: 2,
  CURRENCY_DECIMALS: 4,
  BASIS_POINTS: 10000, // 100% = 10000 basis points
} as const;

// Error messages
export const ERROR_MESSAGES = {
  WALLET_NOT_CONNECTED: 'Please connect your wallet',
  WRONG_NETWORK: 'Please switch to the correct network',
  INSUFFICIENT_BALANCE: 'Insufficient balance',
  TRANSACTION_FAILED: 'Transaction failed',
  CONTRACT_NOT_FOUND: 'Contract not found',
  INVALID_ADDRESS: 'Invalid address',
  INVALID_AMOUNT: 'Invalid amount',
  CROWDSALE_NOT_ACTIVE: 'Crowdsale is not active',
  PURCHASE_LIMIT_EXCEEDED: 'Purchase limit exceeded',
  HARD_CAP_REACHED: 'Hard cap reached',
  NOT_WHITELISTED: 'Address not whitelisted',
} as const;

// Success messages
export const SUCCESS_MESSAGES = {
  WALLET_CONNECTED: 'Wallet connected successfully',
  TRANSACTION_SENT: 'Transaction sent successfully',
  PURCHASE_SUCCESSFUL: 'Token purchase successful',
  CROWDSALE_CREATED: 'Crowdsale created successfully',
  TOKENS_RELEASED: 'Tokens released successfully',
  REFUND_SUCCESSFUL: 'Refund processed successfully',
} as const;
