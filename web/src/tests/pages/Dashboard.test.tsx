import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { Dashboard } from '@/pages/Dashboard';

// Mock the useWallet hook
const mockUseWallet = vi.fn();
vi.mock('@/hooks/useWallet', () => ({
  useWallet: () => mockUseWallet()
}));

// Mock the BalanceCard component
vi.mock('@/components/wallet/BalanceCard', () => ({
  BalanceCard: ({ ethBalance, tokenBalances, totalUsdValue }: any) => (
    <div data-testid="balance-card">
      <div>ETH: {ethBalance}</div>
      <div>Tokens: {tokenBalances.length}</div>
      <div>USD: ${totalUsdValue}</div>
    </div>
  )
}));

describe('Dashboard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('shows connect wallet message when not connected', () => {
    mockUseWallet.mockReturnValue({
      isConnected: false,
      address: null,
      balance: '0'
    });

    render(<Dashboard />);

    expect(screen.getByText('连接钱包查看仪表板')).toBeInTheDocument();
    expect(screen.getByText('连接您的钱包以查看投资组合和交易历史')).toBeInTheDocument();
  });

  it('renders dashboard content when wallet is connected', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText('投资仪表板')).toBeInTheDocument();
      expect(screen.getByText('管理您的投资组合和代币持仓')).toBeInTheDocument();
    });
  });

  it('displays investment statistics correctly', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText('总投资')).toBeInTheDocument();
      expect(screen.getByText('代币总量')).toBeInTheDocument();
      expect(screen.getByText('预估收益')).toBeInTheDocument();
      expect(screen.getByText('活跃投资')).toBeInTheDocument();
    });
  });

  it('shows investment history with correct data', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText('我的投资')).toBeInTheDocument();
      expect(screen.getByText('DeFi Token Sale')).toBeInTheDocument();
      expect(screen.getByText('GameFi Project')).toBeInTheDocument();
    });
  });

  it('displays vesting schedules correctly', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText('代币释放进度')).toBeInTheDocument();
      expect(screen.getByText('释放计划 #1')).toBeInTheDocument();
    });
  });

  it('renders balance card with correct props', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      const balanceCard = screen.getByTestId('balance-card');
      expect(balanceCard).toBeInTheDocument();
      expect(screen.getByText('ETH: 5.5')).toBeInTheDocument();
      expect(screen.getByText('USD: $230')).toBeInTheDocument();
    });
  });

  it('shows quick actions section', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText('快速操作')).toBeInTheDocument();
      expect(screen.getByText('浏览众筹项目')).toBeInTheDocument();
      expect(screen.getByText('查看交易历史')).toBeInTheDocument();
      expect(screen.getByText('导出投资报告')).toBeInTheDocument();
    });
  });

  it('displays recommended projects', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890',
      balance: '5.5'
    });

    render(<Dashboard />);

    await waitFor(() => {
      expect(screen.getByText('推荐项目')).toBeInTheDocument();
      expect(screen.getByText('AI Token Launch')).toBeInTheDocument();
      expect(screen.getByText('Green Energy DAO')).toBeInTheDocument();
    });
  });
});
