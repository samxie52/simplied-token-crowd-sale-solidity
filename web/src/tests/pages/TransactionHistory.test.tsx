import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { TransactionHistory } from '@/pages/TransactionHistory';

// Mock the useWallet hook
const mockUseWallet = vi.fn();
vi.mock('@/hooks/useWallet', () => ({
  useWallet: () => mockUseWallet()
}));

// Mock formatters
vi.mock('@/utils/formatters', () => ({
  formatEther: vi.fn((value: string) => value),
  formatTokenAmount: vi.fn((value: string) => value)
}));

describe('TransactionHistory', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('shows connect wallet message when not connected', () => {
    mockUseWallet.mockReturnValue({
      isConnected: false,
      address: null
    });

    render(<TransactionHistory />);

    expect(screen.getByText('连接钱包查看交易历史')).toBeInTheDocument();
    expect(screen.getByText('连接您的钱包以查看所有交易记录')).toBeInTheDocument();
  });

  it('renders transaction history when wallet is connected', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      expect(screen.getByText('交易历史')).toBeInTheDocument();
      expect(screen.getByText('查看您的所有交易记录和状态')).toBeInTheDocument();
    });
  });

  it('displays search and filter controls', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('搜索交易哈希、项目名称或地址...')).toBeInTheDocument();
      expect(screen.getByDisplayValue('所有类型')).toBeInTheDocument();
      expect(screen.getByDisplayValue('所有状态')).toBeInTheDocument();
    });
  });

  it('filters transactions by type', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      const typeFilter = screen.getByDisplayValue('所有类型');
      fireEvent.change(typeFilter, { target: { value: 'purchase' } });
      expect(typeFilter).toHaveValue('purchase');
    });
  });

  it('filters transactions by status', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      const statusFilter = screen.getByDisplayValue('所有状态');
      fireEvent.change(statusFilter, { target: { value: 'confirmed' } });
      expect(statusFilter).toHaveValue('confirmed');
    });
  });

  it('searches transactions by term', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      const searchInput = screen.getByPlaceholderText('搜索交易哈希、项目名称或地址...');
      fireEvent.change(searchInput, { target: { value: 'DeFi' } });
      expect(searchInput).toHaveValue('DeFi');
    });
  });

  it('displays transaction records correctly', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    // Check that the transaction history structure is rendered
    expect(screen.getByText('交易历史')).toBeInTheDocument();
    expect(screen.getByText('查看您的所有交易记录和状态')).toBeInTheDocument();
    expect(screen.getByText('交易记录 (0)')).toBeInTheDocument();
    expect(screen.getByText('加载中...')).toBeInTheDocument();
  });

  it('shows loading state initially', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    expect(screen.getByText('加载中...')).toBeInTheDocument();
  });

  it('displays transaction status badges correctly', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      expect(screen.getByText('已确认')).toBeInTheDocument();
      expect(screen.getByText('待确认')).toBeInTheDocument();
    });
  });

  it('shows export CSV button', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      expect(screen.getByText('导出CSV')).toBeInTheDocument();
    });
  });

  it('displays no results message when filtered results are empty', async () => {
    mockUseWallet.mockReturnValue({
      isConnected: true,
      address: '0x1234567890123456789012345678901234567890'
    });

    render(<TransactionHistory />);

    await waitFor(() => {
      const searchInput = screen.getByPlaceholderText('搜索交易哈希、项目名称或地址...');
      fireEvent.change(searchInput, { target: { value: 'nonexistent' } });
    });

    await waitFor(() => {
      expect(screen.getByText('没有找到匹配的交易记录')).toBeInTheDocument();
    });
  });
});
