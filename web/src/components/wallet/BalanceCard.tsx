import React from 'react';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { formatEther, formatTokenAmount } from '@/utils/formatters';
import { 
  CurrencyDollarIcon, 
  ArrowUpIcon, 
  ArrowDownIcon,
  WalletIcon 
} from '@heroicons/react/24/outline';

interface TokenBalance {
  symbol: string;
  balance: string;
  decimals: number;
  address: string;
  usdValue?: number;
}

interface BalanceCardProps {
  ethBalance: string;
  tokenBalances: TokenBalance[];
  totalUsdValue?: number;
  className?: string;
}

export const BalanceCard: React.FC<BalanceCardProps> = ({
  ethBalance,
  tokenBalances,
  totalUsdValue,
  className = ''
}) => {
  const ethValue = parseFloat(formatEther(ethBalance));
  
  return (
    <Card className={className}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white flex items-center">
            <WalletIcon className="h-5 w-5 mr-2" />
            钱包余额
          </h3>
          {totalUsdValue && (
            <span className="text-sm text-gray-500 dark:text-gray-400">
              ≈ ${totalUsdValue.toLocaleString()}
            </span>
          )}
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        {/* ETH余额 */}
        <div className="flex items-center justify-between p-4 bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg">
          <div className="flex items-center">
            <div className="w-10 h-10 bg-blue-100 dark:bg-blue-800 rounded-full flex items-center justify-center mr-3">
              <CurrencyDollarIcon className="h-6 w-6 text-blue-600 dark:text-blue-400" />
            </div>
            <div>
              <p className="font-medium text-gray-900 dark:text-white">ETH</p>
              <p className="text-sm text-gray-500 dark:text-gray-400">以太坊</p>
            </div>
          </div>
          <div className="text-right">
            <p className="font-semibold text-gray-900 dark:text-white">
              {ethValue.toFixed(6)}
            </p>
            <p className="text-sm text-gray-500 dark:text-gray-400">ETH</p>
          </div>
        </div>

        {/* 代币余额列表 */}
        {tokenBalances.length > 0 && (
          <div className="space-y-3">
            <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">
              代币持仓
            </h4>
            {tokenBalances.map((token, index) => (
              <div
                key={token.address}
                className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-800 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
              >
                <div className="flex items-center">
                  <div className="w-8 h-8 bg-gradient-to-br from-purple-400 to-pink-400 rounded-full flex items-center justify-center mr-3">
                    <span className="text-white text-xs font-bold">
                      {token.symbol.slice(0, 2)}
                    </span>
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-white">
                      {token.symbol}
                    </p>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      {token.address.slice(0, 6)}...{token.address.slice(-4)}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-semibold text-gray-900 dark:text-white">
                    {formatTokenAmount(token.balance)}
                  </p>
                  {token.usdValue && (
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      ${token.usdValue.toFixed(2)}
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* 空状态 */}
        {tokenBalances.length === 0 && (
          <div className="text-center py-8">
            <WalletIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-500 dark:text-gray-400">
              暂无代币持仓
            </p>
            <p className="text-sm text-gray-400 dark:text-gray-500 mt-2">
              参与众筹后，您的代币将显示在这里
            </p>
          </div>
        )}

        {/* 余额变化趋势（可选） */}
        <div className="pt-4 border-t border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-500 dark:text-gray-400">24小时变化</span>
            <div className="flex items-center text-green-600">
              <ArrowUpIcon className="h-4 w-4 mr-1" />
              <span>+2.34%</span>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};
