import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PriceDisplay } from '@/components/crowdsale/PriceDisplay';

// Mock the formatEther function
vi.mock('@/utils/formatters', () => ({
  formatEther: vi.fn((value: string) => (parseFloat(value) / 1e18).toString())
}));

describe('PriceDisplay', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders basic token price correctly', () => {
    render(
      <PriceDisplay
        tokenPrice="1000000000000000000" // 1 ETH in wei
        userTier="NONE"
      />
    );

    expect(screen.getByText('代币价格')).toBeInTheDocument();
    const priceElements = screen.getAllByText(/1\.000000\s+ETH/);
    expect(priceElements.length).toBeGreaterThan(0);
  });

  it('shows no discount for non-whitelisted users', () => {
    render(
      <PriceDisplay
        tokenPrice="1000000000000000000" // 1 ETH in wei
        userTier="NONE"
      />
    );

    expect(screen.getByText('代币价格')).toBeInTheDocument();
    expect(screen.queryByText('折扣')).not.toBeInTheDocument();
  });

  it('applies VIP discount correctly', () => {
    render(
      <PriceDisplay
        tokenPrice="1000000000000000000" // 1 ETH in wei
        whitelistDiscount={20}
        userTier="VIP"
      />
    );

    expect(screen.getByText('基础价格')).toBeInTheDocument();
    expect(screen.getByText('VIP折扣')).toBeInTheDocument();
    expect(screen.getByText('-20%')).toBeInTheDocument();
    const discountedPriceElements = screen.getAllByText(/0\.800000\s+ETH/);
    expect(discountedPriceElements.length).toBeGreaterThan(0);
  });

  it('applies whitelist discount correctly', () => {
    render(
      <PriceDisplay
        tokenPrice="2000000000000000000" // 2 ETH in wei
        whitelistDiscount={10}
        userTier="WHITELISTED"
      />
    );

    expect(screen.getByText('白名单折扣')).toBeInTheDocument();
    expect(screen.getByText('-10%')).toBeInTheDocument();
    const priceElements = screen.getAllByText(/1\.800000\s+ETH/);
    expect(priceElements.length).toBeGreaterThan(0);
  });

  it('shows savings calculation for discounted users', () => {
    render(
      <PriceDisplay
        tokenPrice="1000000000000000000" // 1 ETH in wei
        whitelistDiscount={20}
        userTier="VIP"
      />
    );

    expect(screen.getByText('💰 您节省了 0.200000 ETH')).toBeInTheDocument();
  });

  it('displays price trend when history is provided', () => {
    const priceHistory = [
      {
        current: '1000000000000000000',
        previous: '900000000000000000',
        change: 0.1,
        changePercent: 11.11,
        lastUpdated: Date.now()
      }
    ];

    render(
      <PriceDisplay
        tokenPrice="1000000000000000000"
        priceHistory={priceHistory}
        userTier="NONE"
      />
    );

    expect(screen.getByText('价格趋势')).toBeInTheDocument();
  });

  it('shows loading state correctly', () => {
    render(
      <PriceDisplay
        tokenPrice="1000000000000000000"
        isLoading={true}
        userTier="NONE"
      />
    );

    const loadingIcon = screen.getByTestId('loading-spinner');
    expect(loadingIcon).toHaveClass('animate-spin');
  });

  it('displays price change indicators', () => {
    const priceHistory = [
      {
        current: '1100000000000000000',
        previous: '1000000000000000000',
        change: 0.1,
        changePercent: 10,
        lastUpdated: Date.now()
      }
    ];

    render(
      <PriceDisplay
        tokenPrice="1100000000000000000"
        priceHistory={priceHistory}
        userTier="NONE"
      />
    );

    expect(screen.getByText('+0.100000 ETH (+10.00%)')).toBeInTheDocument();
  });

  it('shows price explanation note', () => {
    render(
      <PriceDisplay
        tokenPrice="1000000000000000000"
        userTier="NONE"
      />
    );

    expect(screen.getByText('💡 价格可能根据众筹进度和市场条件进行调整')).toBeInTheDocument();
  });
});
