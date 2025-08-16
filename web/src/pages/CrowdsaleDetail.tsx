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
  const isActive = config ? currentTime < parseInt(config.publicSaleEndTime.toString()) : false;

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
              Crowdsale Project
            </h1>
            <p className="text-gray-600 dark:text-gray-400 mt-1">
              {address?.slice(0, 6)}...{address?.slice(-4)}
            </p>
          </div>
        </div>
        
        <div className="flex space-x-2">
          <Button variant="ghost" size="sm">
            <ShareIcon className="h-5 w-5" />
            分享
          </Button>
          <Button variant="outline" size="sm">
            <BookmarkIcon className="h-5 w-5" />
            收藏
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* 左侧主要内容 */}
        <div className="lg:col-span-2 space-y-6">
          {/* 项目描述 */}
          <Card>
            <CardHeader>
              <h2 className="text-xl font-semibold">项目描述</h2>
            </CardHeader>
            <CardContent>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
                这是一个创新的区块链项目，旨在通过去中心化的方式为用户提供更好的服务。
                我们的团队拥有丰富的区块链开发经验，致力于构建一个安全、高效、用户友好的平台。
              </p>
            </CardContent>
          </Card>

          {/* 路线图 */}
          <Card>
            <CardHeader>
              <h2 className="text-xl font-semibold">项目路线图</h2>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-start space-x-3">
                  <div className="w-2 h-2 bg-green-500 rounded-full mt-2"></div>
                  <div>
                    <h3 className="font-medium">Q1 2024 - 项目启动</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">完成项目规划和团队组建</p>
                  </div>
                </div>
                <div className="flex items-start space-x-3">
                  <div className="w-2 h-2 bg-blue-500 rounded-full mt-2"></div>
                  <div>
                    <h3 className="font-medium">Q2 2024 - 开发阶段</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">核心功能开发和测试</p>
                  </div>
                </div>
                <div className="flex items-start space-x-3">
                  <div className="w-2 h-2 bg-gray-300 rounded-full mt-2"></div>
                  <div>
                    <h3 className="font-medium">Q3 2024 - 主网上线</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">正式发布和社区推广</p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 右侧操作面板 */}
        <div className="space-y-6">
          {/* 倒计时 */}
          {isActive && config && (
            <CountdownTimer
              endTime={parseInt(config.publicSaleEndTime.toString())}
              onComplete={refreshData}
            />
          )}

          {/* 价格显示 */}
          {config && (
            <PriceDisplay
              tokenPrice="0.001"
              whitelistDiscount={whitelistStatus.discount}
              userTier={whitelistStatus.tier}
            />
          )}

          {/* 白名单状态 */}
          {isConnected && (
            <WhitelistStatus />
          )}

          {/* 购买表单 */}
          {config && address && (
            <PurchaseForm
              crowdsaleAddress={address}
              tokenPrice="0.001"
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
