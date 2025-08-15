import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ProgressBar } from '@/components/charts/ProgressBar';

describe('ProgressBar', () => {
  it('renders with correct percentage', () => {
    render(
      <ProgressBar
        current={75}
        total={100}
        label="Progress"
      />
    );

    expect(screen.getByText('Progress')).toBeInTheDocument();
    expect(screen.getByText('75%')).toBeInTheDocument();
  });

  it('calculates percentage correctly', () => {
    render(
      <ProgressBar
        current={250}
        total={1000}
        label="Funding Progress"
      />
    );

    expect(screen.getByText('25%')).toBeInTheDocument();
  });

  it('handles zero total gracefully', () => {
    render(
      <ProgressBar
        current={50}
        total={0}
        label="Test Progress"
      />
    );

    expect(screen.getByText('0%')).toBeInTheDocument();
  });

  it('caps percentage at 100%', () => {
    render(
      <ProgressBar
        current={150}
        total={100}
        label="Over Target"
      />
    );

    expect(screen.getByText('100%')).toBeInTheDocument();
  });

  it('applies custom color correctly', () => {
    render(
      <ProgressBar
        current={60}
        total={100}
        label="Custom Color"
        color="success"
      />
    );

    const progressFill = screen.getByRole('progressbar').querySelector('.bg-green-500');
    expect(progressFill).toBeInTheDocument();
  });

  it('shows current and total values when showValues is true', () => {
    render(
      <ProgressBar
        current={750}
        total={1000}
        label="Token Sale"
        showValues={true}
      />
    );

    expect(screen.getByText('750 / 1000')).toBeInTheDocument();
  });

  it('applies custom height', () => {
    render(
      <ProgressBar
        current={40}
        total={100}
        label="Custom Height"
        height="h-6"
      />
    );

    const progressBar = screen.getByRole('progressbar');
    expect(progressBar).toHaveClass('h-6');
  });

  it('renders without label when not provided', () => {
    const { container } = render(
      <ProgressBar
        current={30}
        total={100}
      />
    );

    expect(screen.getByText('30%')).toBeInTheDocument();
    expect(container.querySelector('.mb-2')).not.toBeInTheDocument();
  });
});
