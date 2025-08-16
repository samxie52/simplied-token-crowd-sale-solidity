import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import { AdminPanel } from '@/pages/AdminPanel';

// Mock the hooks
vi.mock('@/hooks/useWallet', () => ({
  useWallet: vi.fn(() => ({
    isConnected: true,
    address: '0x1234567890123456789012345678901234567890',
    signer: {},
    provider: {}
  }))
}));

vi.mock('@/hooks/useAdminAuth', () => ({
  useAdminAuth: vi.fn(() => ({
    isAdmin: true,
    isOperator: false,
    loading: false,
    error: null,
    refreshPermissions: vi.fn()
  }))
}));

vi.mock('@/hooks/useCrowdsaleManagement', () => ({
  useCrowdsaleManagement: vi.fn(() => ({
    crowdsales: [
      {
        address: '0x1234567890123456789012345678901234567890',
        name: 'Test Crowdsale',
        status: 'active',
        phase: 1,
        raised: '100.5',
        target: '1000.0',
        participants: 50,
        startTime: Date.now() - 86400000,
        endTime: Date.now() + 86400000 * 7,
        isPaused: false
      }
    ],
    loading: false,
    error: null,
    pauseCrowdsale: vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' }),
    resumeCrowdsale: vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' }),
    finalizeCrowdsale: vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' })
  }))
}));

vi.mock('@/hooks/useWhitelistManagement', () => ({
  useWhitelistManagement: vi.fn(() => ({
    users: [
      {
        address: '0x1111222233334444555566667777888899990000',
        tier: 'VIP',
        level: 2,
        allocation: '10.0',
        used: '2.5',
        addedDate: Date.now() - 86400000 * 3
      }
    ],
    loading: false,
    error: null,
    addWhitelistUser: vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' }),
    removeWhitelistUser: vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' }),
    checkWhitelistStatus: vi.fn()
  }))
}));

describe('AdminPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders admin panel for authorized users', () => {
    render(<AdminPanel />);
    
    expect(screen.getByText('管理员控制面板')).toBeInTheDocument();
    expect(screen.getByText('众筹项目管理')).toBeInTheDocument();
    expect(screen.getByText('白名单管理')).toBeInTheDocument();
  });

  it('displays crowdsale information', () => {
    render(<AdminPanel />);
    
    expect(screen.getByText('Test Crowdsale')).toBeInTheDocument();
    expect(screen.getByText('100.5 ETH')).toBeInTheDocument();
    expect(screen.getByText('1000.0 ETH')).toBeInTheDocument();
    expect(screen.getByText('50')).toBeInTheDocument();
  });

  it('displays whitelist users', () => {
    render(<AdminPanel />);
    
    expect(screen.getByText('VIP')).toBeInTheDocument();
    expect(screen.getByText('0x111122...990000')).toBeInTheDocument();
  });

  it('allows adding whitelist users', async () => {
    const { useWhitelistManagement } = await import('@/hooks/useWhitelistManagement');
    const mockAddUser = vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' });
    
    vi.mocked(useWhitelistManagement).mockReturnValue({
      users: [],
      loading: false,
      error: null,
      addWhitelistUser: mockAddUser,
      removeWhitelistUser: vi.fn(),
      checkWhitelistStatus: vi.fn()
    });

    render(<AdminPanel />);
    
    const addressInput = screen.getByPlaceholderText('用户地址 (0x...)');
    const addButton = screen.getByText('添加用户');
    
    fireEvent.change(addressInput, { target: { value: '0x1234567890123456789012345678901234567890' } });
    fireEvent.click(addButton);
    
    await waitFor(() => {
      expect(mockAddUser).toHaveBeenCalledWith('0x1234567890123456789012345678901234567890', 'WHITELISTED');
    });
  });

  it('handles crowdsale pause/resume', async () => {
    const { useCrowdsaleManagement } = await import('@/hooks/useCrowdsaleManagement');
    const mockPause = vi.fn().mockResolvedValue({ success: true, txHash: '0xtest' });
    
    vi.mocked(useCrowdsaleManagement).mockReturnValue({
      crowdsales: [
        {
          address: '0x1234567890123456789012345678901234567890',
          name: 'Test Crowdsale',
          status: 'active',
          phase: 1,
          raised: '100.5',
          target: '1000.0',
          participants: 50,
          startTime: Date.now() - 86400000,
          endTime: Date.now() + 86400000 * 7,
          isPaused: false
        }
      ],
      loading: false,
      error: null,
      pauseCrowdsale: mockPause,
      resumeCrowdsale: vi.fn(),
      finalizeCrowdsale: vi.fn()
    });

    render(<AdminPanel />);
    
    const pauseButton = screen.getByText('暂停');
    fireEvent.click(pauseButton);
    
    await waitFor(() => {
      expect(mockPause).toHaveBeenCalledWith('0x1234567890123456789012345678901234567890');
    });
  });

  it('shows access denied for non-admin users', () => {
    const { useAdminAuth } = require('@/hooks/useAdminAuth');
    
    vi.mocked(useAdminAuth).mockReturnValue({
      isAdmin: false,
      isOperator: false,
      loading: false,
      error: null,
      refreshPermissions: vi.fn()
    });

    render(<AdminPanel />);
    
    expect(screen.getByText('访问被拒绝')).toBeInTheDocument();
    expect(screen.getByText('您没有管理员权限访问此页面')).toBeInTheDocument();
  });

  it('shows loading state during auth check', () => {
    const { useAdminAuth } = require('@/hooks/useAdminAuth');
    
    vi.mocked(useAdminAuth).mockReturnValue({
      isAdmin: false,
      isOperator: false,
      loading: true,
      error: null,
      refreshPermissions: vi.fn()
    });

    render(<AdminPanel />);
    
    expect(screen.getByText('验证权限中...')).toBeInTheDocument();
  });
});
