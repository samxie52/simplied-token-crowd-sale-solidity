import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { WhitelistStatus } from '@/components/crowdsale/WhitelistStatus';

describe('WhitelistStatus', () => {
  it('renders non-whitelisted user correctly', () => {
    render(
      <WhitelistStatus
        isWhitelisted={false}
        tier="NONE"
        discount={0}
      />
    );

    expect(screen.getByText('普通用户')).toBeInTheDocument();
    expect(screen.getByText('按标准价格购买代币')).toBeInTheDocument();
  });

  it('renders VIP user with correct discount', () => {
    render(
      <WhitelistStatus
        isWhitelisted={true}
        tier="VIP"
        discount={20}
        maxAllocation="10.0"
        currentAllocation="2.5"
      />
    );

    expect(screen.getByText('VIP用户')).toBeInTheDocument();
    expect(screen.getByText('享受 20% 折扣优惠')).toBeInTheDocument();
    expect(screen.getByText('-20%')).toBeInTheDocument();
    expect(screen.getByText('2.5 / 10.0 ETH')).toBeInTheDocument();
  });

  it('renders whitelisted user with correct privileges', () => {
    render(
      <WhitelistStatus
        isWhitelisted={true}
        tier="WHITELISTED"
        discount={10}
        maxAllocation="5.0"
        currentAllocation="1.0"
      />
    );

    expect(screen.getByText('白名单用户')).toBeInTheDocument();
    expect(screen.getByText('享受 10% 折扣优惠')).toBeInTheDocument();
    expect(screen.getByText('• 早期参与机会')).toBeInTheDocument();
    expect(screen.getByText('• 保证分配额度')).toBeInTheDocument();
  });

  it('calculates remaining allocation correctly', () => {
    render(
      <WhitelistStatus
        isWhitelisted={true}
        tier="VIP"
        discount={20}
        maxAllocation="10.0"
        currentAllocation="3.5"
      />
    );

    expect(screen.getByText('剩余配额: 6.50 ETH')).toBeInTheDocument();
  });

  it('shows VIP privileges for VIP users', () => {
    render(
      <WhitelistStatus
        isWhitelisted={true}
        tier="VIP"
        discount={20}
      />
    );

    expect(screen.getByText('VIP特权:')).toBeInTheDocument();
    expect(screen.getByText('• 优先购买权限')).toBeInTheDocument();
    expect(screen.getByText('• 更高购买限额')).toBeInTheDocument();
    expect(screen.getByText('• 专属客服支持')).toBeInTheDocument();
  });
});
