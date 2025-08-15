import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { formatEther } from '@/utils/formatters';
import { 
  CurrencyDollarIcon, 
  ArrowTrendingUpIcon, 
  ArrowTrendingDownIcon,
  ArrowPathIcon 
} from '@heroicons/react/24/outline';

interface PriceData {
  current: string;
  previous?: string;
  change?: number;
  changePercent?: number;
  lastUpdated: number;
}

interface PriceDisplayProps {
  tokenPrice: string;
  whitelistDiscount?: number;
  userTier?: 'VIP' | 'WHITELISTED' | 'NONE';
  priceHistory?: PriceData[];
  isLoading?: boolean;
  className?: string;
}

export const PriceDisplay: React.FC<PriceDisplayProps> = ({
  tokenPrice,
  whitelistDiscount = 0,
  userTier = 'NONE',
  priceHistory = [],
  isLoading = false,
  className = ''
}) => {
  const [currentTime, setCurrentTime] = useState(Date.now());
  
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(Date.now());
    }, 1000);
    
    return () => clearInterval(timer);
  }, []);

  const basePrice = parseFloat(formatEther(tokenPrice));
  const discountedPrice = userTier !== 'NONE' 
    ? basePrice * (1 - whitelistDiscount / 100)
    : basePrice;

  const latestPrice = priceHistory[priceHistory.length - 1];
  const priceChange = latestPrice?.change || 0;
  const priceChangePercent = latestPrice?.changePercent || 0;

  const getTierDiscount = () => {
    switch (userTier) {
      case 'VIP':
        return { discount: 20, label: 'VIP折扣' };
      case 'WHITELISTED':
        return { discount: 10, label: '白名单折扣' };
      default:
        return { discount: 0, label: '' };
    }
  };

  const tierInfo = getTierDiscount();

  return (
    <Card className={className}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white flex items-center">
            <CurrencyDollarIcon className="h-5 w-5 mr-2" />
            代币价格
          </h3>
          {isLoading && (
            <ArrowPathIcon className="h-4 w-4 text-gray-400 animate-spin" data-testid="loading-spinner" />
          )}
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        {/* 主要价格显示 */}
        <div className="text-center">
          <div className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
            {discountedPrice.toFixed(6)} ETH
          </div>
          
          {/* 价格变化指示器 */}
          {priceChange !== 0 && (
            <div className={`flex items-center justify-center text-sm ${
              priceChange > 0 ? 'text-green-600' : 'text-red-600'
            }`}>
              {priceChange > 0 ? (
                <ArrowTrendingUpIcon className="h-4 w-4 mr-1" />
              ) : (
                <ArrowTrendingDownIcon className="h-4 w-4 mr-1" />
              )}
              <span>
                {priceChange > 0 ? '+' : ''}{priceChange.toFixed(6)} ETH 
                ({priceChangePercent > 0 ? '+' : ''}{priceChangePercent.toFixed(2)}%)
              </span>
            </div>
          )}
        </div>

        {/* 价格详情 */}
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <span className="text-sm text-gray-600 dark:text-gray-400">基础价格</span>
            <span className="font-medium">{basePrice.toFixed(6)} ETH</span>
          </div>
          
          {userTier !== 'NONE' && (
            <>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600 dark:text-gray-400">{tierInfo.label}</span>
                <span className="text-green-600 font-medium">-{tierInfo.discount}%</span>
              </div>
              
              <div className="flex justify-between items-center pt-2 border-t border-gray-200 dark:border-gray-700">
                <span className="text-sm font-medium text-gray-900 dark:text-white">您的价格</span>
                <span className="font-bold text-blue-600">{discountedPrice.toFixed(6)} ETH</span>
              </div>
              
              <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-3">
                <p className="text-sm text-green-700 dark:text-green-300 text-center">
                  💰 您节省了 {(basePrice - discountedPrice).toFixed(6)} ETH
                </p>
              </div>
            </>
          )}
        </div>

        {/* 价格历史图表（简化版） */}
        {priceHistory.length > 0 && (
          <div className="pt-4 border-t border-gray-200 dark:border-gray-700">
            <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
              价格趋势
            </h4>
            <div className="flex items-end justify-between h-16 space-x-1">
              {priceHistory.slice(-10).map((price, index) => {
                const height = Math.max(
                  (parseFloat(formatEther(price.current)) / basePrice) * 100,
                  10
                );
                return (
                  <div
                    key={index}
                    className="flex-1 bg-blue-200 dark:bg-blue-700 rounded-t"
                    style={{ height: `${height}%` }}
                    title={`${formatEther(price.current)} ETH`}
                  />
                );
              })}
            </div>
            <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-2">
              <span>历史</span>
              <span>现在</span>
            </div>
          </div>
        )}

        {/* 更新时间 */}
        <div className="text-center text-xs text-gray-500 dark:text-gray-400">
          最后更新: {new Date(latestPrice?.lastUpdated || currentTime).toLocaleTimeString()}
        </div>

        {/* 价格说明 */}
        <div className="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-3">
          <p className="text-xs text-blue-700 dark:text-blue-300">
            💡 价格可能根据众筹进度和市场条件进行调整
          </p>
        </div>
      </CardContent>
    </Card>
  );
};
