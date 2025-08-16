import { ethers } from 'ethers';

export interface TokenPrice {
  address: string;
  symbol: string;
  priceUSD: number;
  priceETH: number;
  lastUpdated: number;
}

// Mock price data for development
const MOCK_PRICES: { [key: string]: TokenPrice } = {
  'default': {
    address: '0x0000000000000000000000000000000000000000',
    symbol: 'DEFAULT',
    priceUSD: 0.1,
    priceETH: 0.00005,
    lastUpdated: Date.now()
  }
};

/**
 * Get token price from CoinGecko API
 * Falls back to mock data if API fails
 */
export async function getTokenPrice(tokenAddress: string): Promise<TokenPrice> {
  try {
    // Normalize address
    const normalizedAddress = ethers.getAddress(tokenAddress.toLowerCase());
    
    // Try CoinGecko API first
    const response = await fetch(
      `https://api.coingecko.com/api/v3/simple/token_price/ethereum?contract_addresses=${normalizedAddress}&vs_currencies=usd,eth`,
      {
        headers: {
          'Accept': 'application/json',
        },
        // Add timeout
        signal: AbortSignal.timeout(5000)
      }
    );

    if (response.ok) {
      const data = await response.json();
      const tokenData = data[normalizedAddress.toLowerCase()];
      
      if (tokenData) {
        return {
          address: normalizedAddress,
          symbol: 'TOKEN', // Would need to fetch symbol separately
          priceUSD: tokenData.usd || 0.1,
          priceETH: tokenData.eth || 0.00005,
          lastUpdated: Date.now()
        };
      }
    }
  } catch (error) {
    console.warn('Failed to fetch price from CoinGecko:', error);
  }

  // Fallback to mock price
  return {
    address: tokenAddress,
    symbol: 'TOKEN',
    priceUSD: MOCK_PRICES.default.priceUSD,
    priceETH: MOCK_PRICES.default.priceETH,
    lastUpdated: Date.now()
  };
}

/**
 * Get multiple token prices in batch
 */
export async function getBatchTokenPrices(tokenAddresses: string[]): Promise<TokenPrice[]> {
  try {
    // Normalize addresses
    const normalizedAddresses = tokenAddresses.map(addr => 
      ethers.getAddress(addr.toLowerCase())
    );
    
    const addressesParam = normalizedAddresses.join(',');
    
    const response = await fetch(
      `https://api.coingecko.com/api/v3/simple/token_price/ethereum?contract_addresses=${addressesParam}&vs_currencies=usd,eth`,
      {
        headers: {
          'Accept': 'application/json',
        },
        signal: AbortSignal.timeout(10000)
      }
    );

    if (response.ok) {
      const data = await response.json();
      
      return normalizedAddresses.map((address, index) => {
        const tokenData = data[address.toLowerCase()];
        
        if (tokenData) {
          return {
            address,
            symbol: 'TOKEN',
            priceUSD: tokenData.usd || 0.1,
            priceETH: tokenData.eth || 0.00005,
            lastUpdated: Date.now()
          };
        }
        
        // Fallback for missing data
        return {
          address,
          symbol: 'TOKEN',
          priceUSD: MOCK_PRICES.default.priceUSD,
          priceETH: MOCK_PRICES.default.priceETH,
          lastUpdated: Date.now()
        };
      });
    }
  } catch (error) {
    console.warn('Failed to fetch batch prices from CoinGecko:', error);
  }

  // Fallback to mock prices for all tokens
  return tokenAddresses.map(address => ({
    address,
    symbol: 'TOKEN',
    priceUSD: MOCK_PRICES.default.priceUSD,
    priceETH: MOCK_PRICES.default.priceETH,
    lastUpdated: Date.now()
  }));
}

/**
 * Get ETH price in USD
 */
export async function getETHPrice(): Promise<number> {
  try {
    const response = await fetch(
      'https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd',
      {
        headers: {
          'Accept': 'application/json',
        },
        signal: AbortSignal.timeout(5000)
      }
    );

    if (response.ok) {
      const data = await response.json();
      return data.ethereum?.usd || 2000; // Fallback to $2000
    }
  } catch (error) {
    console.warn('Failed to fetch ETH price:', error);
  }

  return 2000; // Fallback ETH price
}
