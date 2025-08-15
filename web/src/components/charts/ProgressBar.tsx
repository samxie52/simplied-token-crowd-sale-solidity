import React from 'react';

interface ProgressBarProps {
  current: number;
  total?: number;
  target?: number; // Keep for backward compatibility
  label?: string;
  className?: string;
  showPercentage?: boolean;
  showValues?: boolean;
  color?: 'primary' | 'success' | 'warning' | 'danger';
  height?: string;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({
  current,
  total,
  target,
  label,
  className = '',
  showPercentage = true,
  showValues = false,
  color = 'primary',
  height
}) => {
  const totalValue = total !== undefined ? total : (target || 100);
  const percentage = totalValue > 0 ? Math.min((current / totalValue) * 100, 100) : 0;
  
  const colorClasses = {
    primary: 'bg-blue-500',
    success: 'bg-green-500',
    warning: 'bg-yellow-500',
    danger: 'bg-red-500'
  };

  const progressBarHeight = height || 'h-2.5';

  return (
    <div className={`w-full ${className} ${height || ''}`} role="progressbar" aria-valuenow={current} aria-valuemax={totalValue}>
      {label && (
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
            {label}
          </span>
          {showPercentage && (
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
              {percentage.toFixed(0)}%
            </span>
          )}
        </div>
      )}
      
      {!label && showPercentage && (
        <div className="text-center">
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
            {percentage.toFixed(0)}%
          </span>
        </div>
      )}
      
      <div className={`w-full bg-gray-200 rounded-full ${progressBarHeight} dark:bg-gray-700 ${label ? 'mt-2' : 'mt-1'}`}>
        <div
          className={`${progressBarHeight} rounded-full transition-all duration-500 ease-out ${colorClasses[color]}`}
          style={{ width: `${percentage}%` }}
        />
      </div>
      
      {showValues && (
        <div className="flex justify-between items-center mt-1">
          <span className="text-xs text-gray-500">
            {current} / {totalValue}
          </span>
        </div>
      )}
    </div>
  );
};
