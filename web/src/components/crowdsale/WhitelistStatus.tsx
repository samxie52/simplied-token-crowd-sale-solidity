import React from 'react';
import { Card, CardContent } from '@/components/ui/Card';
import { 
  CheckCircleIcon, 
  XCircleIcon, 
  StarIcon,
  UserGroupIcon 
} from '@heroicons/react/24/outline';
import { useWhitelistStatus } from '../../hooks/useWhitelistStatus';

interface WhitelistStatusProps {
  className?: string;
}

export const WhitelistStatus: React.FC<WhitelistStatusProps> = ({
  className = ''
}) => {
  const { status, loading, error } = useWhitelistStatus();
  
  if (loading) {
    return (
      <Card className={`bg-gray-50 dark:bg-gray-800 border-gray-200 dark:border-gray-700 border ${className}`}>
        <CardContent className="p-4">
          <div className="flex items-center">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-gray-900 mr-3"></div>
            <div>
              <p className="font-medium text-gray-700 dark:text-gray-300">
                加载中...
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                正在获取白名单状态
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className={`bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 border ${className}`}>
        <CardContent className="p-4">
          <div className="flex items-center">
            <XCircleIcon className="h-6 w-6 text-red-400 mr-3" />
            <div>
              <p className="font-medium text-red-700 dark:text-red-300">
                加载失败
              </p>
              <p className="text-sm text-red-500 dark:text-red-400">
                {error}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  const { isWhitelisted, tier, discount, maxAllocation, currentAllocation } = status;
  const getTierInfo = () => {
    switch (tier) {
      case 'VIP':
        return {
          icon: StarIcon,
          title: 'VIP用户',
          color: 'text-purple-600',
          bgColor: 'bg-purple-50 dark:bg-purple-900/20',
          borderColor: 'border-purple-200 dark:border-purple-800'
        };
      case 'WHITELISTED':
        return {
          icon: UserGroupIcon,
          title: '白名单用户',
          color: 'text-blue-600',
          bgColor: 'bg-blue-50 dark:bg-blue-900/20',
          borderColor: 'border-blue-200 dark:border-blue-800'
        };
      default:
        return {
          icon: XCircleIcon,
          title: '普通用户',
          color: 'text-gray-600',
          bgColor: 'bg-gray-50 dark:bg-gray-800',
          borderColor: 'border-gray-200 dark:border-gray-700'
        };
    }
  };

  const tierInfo = getTierInfo();
  const Icon = tierInfo.icon;

  if (!isWhitelisted) {
    return (
      <Card className={`${tierInfo.bgColor} ${tierInfo.borderColor} border ${className}`}>
        <CardContent className="p-4">
          <div className="flex items-center">
            <XCircleIcon className="h-6 w-6 text-gray-400 mr-3" />
            <div>
              <p className="font-medium text-gray-700 dark:text-gray-300">
                普通用户
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                按标准价格购买代币
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={`${tierInfo.bgColor} ${tierInfo.borderColor} border ${className}`}>
      <CardContent className="p-4">
        <div className="flex items-start justify-between">
          <div className="flex items-center">
            <Icon className={`h-6 w-6 ${tierInfo.color} mr-3`} />
            <div>
              <div className="flex items-center">
                <p className={`font-medium ${tierInfo.color}`}>
                  {tierInfo.title}
                </p>
                <CheckCircleIcon className="h-4 w-4 text-green-500 ml-2" />
              </div>
              <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                享受 {discount}% 折扣优惠
              </p>
            </div>
          </div>
          
          {/* 折扣标签 */}
          <div className={`px-2 py-1 rounded-full text-xs font-medium ${tierInfo.color} ${tierInfo.bgColor} border ${tierInfo.borderColor}`}>
            -{discount}%
          </div>
        </div>

        {/* 配额信息 */}
        {maxAllocation && (
          <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-600">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600 dark:text-gray-400">
                专属配额
              </span>
              <span className="text-sm font-medium">
                {currentAllocation || '0'} / {maxAllocation} ETH
              </span>
            </div>
            
            {/* 配额进度条 */}
            <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
              <div
                className={`h-2 rounded-full ${tier === 'VIP' ? 'bg-purple-500' : 'bg-blue-500'}`}
                style={{
                  width: `${Math.min(
                    ((parseFloat(currentAllocation || '0') / parseFloat(maxAllocation)) * 100),
                    100
                  )}%`
                }}
              />
            </div>
            
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
              剩余配额: {(parseFloat(maxAllocation) - parseFloat(currentAllocation || '0')).toFixed(2)} ETH
            </p>
          </div>
        )}

        {/* 特权说明 */}
        <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-600">
          <p className="text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
            {tier === 'VIP' ? 'VIP特权' : '白名单特权'}:
          </p>
          <ul className="text-xs text-gray-600 dark:text-gray-400 space-y-1">
            <li>• {discount}% 价格折扣</li>
            {tier === 'VIP' && (
              <>
                <li>• 优先购买权限</li>
                <li>• 更高购买限额</li>
                <li>• 专属客服支持</li>
              </>
            )}
            {tier === 'WHITELISTED' && (
              <>
                <li>• 早期参与机会</li>
                <li>• 保证分配额度</li>
              </>
            )}
          </ul>
        </div>
      </CardContent>
    </Card>
  );
};
