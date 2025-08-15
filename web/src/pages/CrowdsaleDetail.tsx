import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { useWallet } from '@/hooks/useWallet';
import { useCrowdsale } from '@/hooks/useCrowdsale';
import { CrowdsaleStats } from '@/components/crowdsale/CrowdsaleStats';
import { CountdownTimer } from '@/components/crowdsale/CountdownTimer';
import { PurchaseForm } from '@/components/crowdsale/PurchaseForm';
import { WhitelistStatus } from '@/components/crowdsale/WhitelistStatus';
import { PriceDisplay } from '@/components/crowdsale/PriceDisplay';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { 
  ArrowLeftIcon,
  ShareIcon,
  BookmarkIcon,
  ExclamationTriangleIcon 
} from '@heroicons/react/24/outline';

export const CrowdsaleDetail: React.FC = () => {
  const { address } = useParams<{ address: string }>();
  const { isConnected } = useWallet();
  const { 
    crowdsaleData, 
    stats, 
    config, 
    isLoading, 
    error,
    refreshData 
  } = useCrowdsale(address || '');

  const [whitelistStatus, setWhitelistStatus] = useState({
    isWhitelisted: false,
    tier: 'NONE' as 'VIP' | 'WHITELISTED' | 'NONE',
    discount: 0
  });

  useEffect(() => {
    if (address) {
      // 模拟白名单状态检查
      // 实际应用中应该调用合约方法
      setWhitelistStatus({
        isWhitelisted: Math.random() > 0.7,
        tier: Math.random() > 0.8 ? 'VIP' : 'WHITELISTED',
        discount: Math.random() > 0.8 ? 20 : 10
      });
    }
  }, [address]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error || !crowdsaleData) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Card className="max-w-md w-full mx-4">
          <CardContent className="p-6 text-center">
            <ExclamationTriangleIcon className="h-12 w-12 text-red-500 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
              加载失败
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-4">
              {error || '无法加载众筹信息'}
            </p>
            <Button onClick={refreshData} variant="primary">
              重试
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  const currentTime = Math.floor(Date.now() / 1000);
  const isActive = currentTime < parseInt(crowdsaleData.endTime);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* 头部导航 */}
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => window.history.back()}
            className="mr-4"
          >
            <ArrowLeftIcon className="h-4 w-4 mr-2" />
            返回
          </Button>
          <div>
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
              {crowdsaleData.name || '代币众筹'}
            </h1>
            <p className="text-gray-600 dark:text-gray-400 mt-1">
              {address?.slice(0, 6)}...{address?.slice(-4)}
            </p>
          </div>
        </div>
        
        <div className="flex space-x-2">
          <Button variant="ghost" size="sm">
            <BookmarkIcon className="h-4 w-4 mr-2" />
            收藏
          </Button>
          <Button variant="ghost" size="sm">
            <ShareIcon className="h-4 w-4 mr-2" />
            分享
          </Button>
        </div>
      </div>

      {/* 主要内容区域 */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* 左侧主要信息 */}
        <div className="lg:col-span-2 space-y-6">
          {/* 众筹统计 */}
          <CrowdsaleStats
            stats={stats}
            config={config}
          />

          {/* 众筹描述 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                项目介绍
              </h3>
            </CardHeader>
            <CardContent>
              <div className="prose dark:prose-invert max-w-none">
                <p className="text-gray-600 dark:text-gray-400">
                  这是一个创新的代币众筹项目，旨在为投资者提供早期参与机会。
                  项目采用多阶段销售策略，包括白名单预售和公开销售阶段。
                </p>
                <h4 className="text-lg font-semibold mt-6 mb-3">项目亮点</h4>
                <ul className="list-disc list-inside space-y-2 text-gray-600 dark:text-gray-400">
                  <li>经过安全审计的智能合约</li>
                  <li>透明的资金托管机制</li>
                  <li>灵活的代币释放策略</li>
                  <li>白名单用户享受折扣优惠</li>
                </ul>
              </div>
            </CardContent>
          </Card>

          {/* 代币经济学 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                代币经济学
              </h3>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center">
                  <p className="text-2xl font-bold text-blue-600">1,000,000</p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">总供应量</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-green-600">30%</p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">众筹分配</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-purple-600">20%</p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">团队预留</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-orange-600">50%</p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">生态发展</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 右侧操作面板 */}
        <div className="space-y-6">
          {/* 倒计时 */}
          {isActive && (
            <CountdownTimer
              endTime={parseInt(crowdsaleData.endTime)}
              onComplete={refreshData}
            />
          )}

          {/* 价格显示 */}
          <PriceDisplay
            tokenPrice={config.tokenPrice}
            whitelistDiscount={whitelistStatus.discount}
            userTier={whitelistStatus.tier}
          />

          {/* 白名单状态 */}
          {isConnected && (
            <WhitelistStatus
              isWhitelisted={whitelistStatus.isWhitelisted}
              tier={whitelistStatus.tier}
              discount={whitelistStatus.discount}
              maxAllocation="5.0"
              currentAllocation="1.2"
            />
          )}

          {/* 购买表单 */}
          {isActive && (
            <PurchaseForm
              crowdsaleAddress={address || ''}
              tokenPrice={config.tokenPrice}
              minPurchase="0.01"
              maxPurchase="10.0"
              userWhitelistStatus={whitelistStatus}
            />
          )}

          {/* 众筹已结束提示 */}
          {!isActive && (
            <Card className="bg-gray-50 dark:bg-gray-800">
              <CardContent className="p-6 text-center">
                <ExclamationTriangleIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                  众筹已结束
                </h3>
                <p className="text-gray-600 dark:text-gray-400">
                  此众筹项目已于 {new Date(parseInt(crowdsaleData.endTime) * 1000).toLocaleDateString()} 结束
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
};
