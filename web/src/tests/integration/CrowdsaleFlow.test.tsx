import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { CrowdsaleDetail } from '@/pages/CrowdsaleDetail';

// Mock all the hooks and components
const mockUseWallet = vi.fn();
const mockUseCrowdsale = vi.fn();

vi.mock('@/hooks/useWallet', () => ({
  useWallet: () => mockUseWallet()
}));

vi.mock('@/hooks/useCrowdsale', () => ({
  useCrowdsale: () => mockUseCrowdsale()
}));

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useParams: () => ({ address: '0x1234567890123456789012345678901234567890' })
  };
});

// Mock components
vi.mock('@/components/crowdsale/CrowdsaleStats', () => ({
  CrowdsaleStats: ({ stats, config }: any) => (
    <div data-testid="crowdsale-stats">
      <div>Raised: {stats?.raised || '0'} ETH</div>
      <div>Target: {config?.hardCap || '0'} ETH</div>
    </div>
  )
}));

vi.mock('@/components/crowdsale/CountdownTimer', () => ({
  CountdownTimer: ({ endTime, onComplete }: any) => (
    <div data-testid="countdown-timer">
      <div>End Time: {endTime}</div>
    </div>
  )
}));

vi.mock('@/components/crowdsale/PurchaseForm', () => ({
  PurchaseForm: ({ crowdsaleAddress, tokenPrice, userWhitelistStatus }: any) => (
    <div data-testid="purchase-form">
      <div>Address: {crowdsaleAddress}</div>
      <div>Price: {tokenPrice}</div>
      <div>Whitelist: {userWhitelistStatus.isWhitelisted ? 'Yes' : 'No'}</div>
      <button>Purchase Tokens</button>
    </div>
  )
}));

vi.mock('@/components/crowdsale/WhitelistStatus', () => ({
  WhitelistStatus: ({ isWhitelisted, tier, discount }: any) => (
    <div data-testid="whitelist-status">
      <div>Whitelisted: {isWhitelisted ? 'Yes' : 'No'}</div>
      <div>Tier: {tier}</div>
      <div>Discount: {discount}%</div>
    </div>
  )
}));

vi.mock('@/components/crowdsale/PriceDisplay', () => ({
  PriceDisplay: ({ tokenPrice, whitelistDiscount, userTier }: any) => (
    <div data-testid="price-display">
      <div>Token Price: {tokenPrice}</div>
      <div>Discount: {whitelistDiscount}%</div>
      <div>Tier: {userTier}</div>
    </div>
  )
}));

describe('CrowdsaleFlow Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders complete crowdsale detail page for active crowdsale', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    mockUseCrowdsale.mockReturnValue({
      crowdsaleData: {
        name: 'Test Token Sale',
        endTime: (Math.floor(Date.now() / 1000) + 86400).toString(), // 1 day from now
        address: '0x1234567890123456789012345678901234567890'
      },
      stats: {
        raised: '150.5',
        participants: 234
      },
      config: {
        tokenPrice: '1000000000000000000', // 1 ETH in wei
        hardCap: '500.0'
      },
      isLoading: false,
      error: null,
      refreshData: vi.fn()
    });

    render(
      <BrowserRouter>
        <CrowdsaleDetail />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(screen.getByText('Test Token Sale')).toBeInTheDocument();
      expect(screen.getByTestId('crowdsale-stats')).toBeInTheDocument();
      expect(screen.getByTestId('countdown-timer')).toBeInTheDocument();
      expect(screen.getByTestId('purchase-form')).toBeInTheDocument();
      expect(screen.getByTestId('whitelist-status')).toBeInTheDocument();
      expect(screen.getByTestId('price-display')).toBeInTheDocument();
    });
  });

  it('shows loading state correctly', () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    mockUseCrowdsale.mockReturnValue({
      crowdsaleData: null,
      stats: null,
      config: null,
      isLoading: true,
      error: null,
      refreshData: vi.fn()
    });

    render(
      <BrowserRouter>
        <CrowdsaleDetail />
      </BrowserRouter>
    );

    expect(document.querySelector('.animate-spin')).toBeInTheDocument();
  });

  it('handles error state correctly', () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    mockUseCrowdsale.mockReturnValue({
      crowdsaleData: null,
      stats: null,
      config: null,
      isLoading: false,
      error: 'Failed to load crowdsale data',
      refreshData: vi.fn()
    });

    render(
      <BrowserRouter>
        <CrowdsaleDetail />
      </BrowserRouter>
    );

    expect(screen.getByText('加载失败')).toBeInTheDocument();
    expect(screen.getByText('Failed to load crowdsale data')).toBeInTheDocument();
    expect(screen.getByText('重试')).toBeInTheDocument();
  });

  it('shows ended crowdsale state correctly', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    mockUseCrowdsale.mockReturnValue({
      crowdsaleData: {
        name: 'Ended Token Sale',
        endTime: (Math.floor(Date.now() / 1000) - 86400).toString(), // 1 day ago
        address: '0x1234567890123456789012345678901234567890'
      },
      stats: {
        raised: '500.0',
        participants: 1000
      },
      config: {
        tokenPrice: '1000000000000000000',
        hardCap: '500.0'
      },
      isLoading: false,
      error: null,
      refreshData: vi.fn()
    });

    render(
      <BrowserRouter>
        <CrowdsaleDetail />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(screen.getByText('众筹已结束')).toBeInTheDocument();
      expect(screen.queryByTestId('purchase-form')).not.toBeInTheDocument();
    });
  });

  it('integrates whitelist status with purchase form', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    mockUseCrowdsale.mockReturnValue({
      crowdsaleData: {
        name: 'VIP Token Sale',
        endTime: (Math.floor(Date.now() / 1000) + 86400).toString(),
        address: '0x1234567890123456789012345678901234567890'
      },
      stats: {
        raised: '100.0',
        participants: 50
      },
      config: {
        tokenPrice: '1000000000000000000',
        hardCap: '500.0'
      },
      isLoading: false,
      error: null,
      refreshData: vi.fn()
    });

    render(
      <BrowserRouter>
        <CrowdsaleDetail />
      </BrowserRouter>
    );

    await waitFor(() => {
      const whitelistStatus = screen.getByTestId('whitelist-status');
      const purchaseForm = screen.getByTestId('purchase-form');
      
      expect(whitelistStatus).toBeInTheDocument();
      expect(purchaseForm).toBeInTheDocument();
    });
  });
});
