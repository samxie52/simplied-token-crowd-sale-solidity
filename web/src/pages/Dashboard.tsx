import React, { useState, useEffect } from 'react';
import { useWallet } from '@/hooks/useWallet';
import { BalanceCard } from '@/components/wallet/BalanceCard';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { formatEther, formatTokenAmount } from '@/utils/formatters';
import { 
  ChartBarIcon,
  CurrencyDollarIcon,
  TrophyIcon,
  ClockIcon,
  ArrowTopRightOnSquareIcon
} from '@heroicons/react/24/outline';

interface UserInvestment {
  crowdsaleAddress: string;
  crowdsaleName: string;
  investedAmount: string;
  tokenAmount: string;
  investmentDate: number;
  status: 'active' | 'completed' | 'refunded';
}

interface VestingSchedule {
  scheduleId: string;
  tokenAmount: string;
  releasedAmount: string;
  nextReleaseDate: number;
  totalReleases: number;
  completedReleases: number;
}

export const Dashboard: React.FC = () => {
  const { isConnected, address, balance } = useWallet();
  const [investments, setInvestments] = useState<UserInvestment[]>([]);
  const [vestingSchedules, setVestingSchedules] = useState<VestingSchedule[]>([]);
  const [totalStats, setTotalStats] = useState({
    totalInvested: '0',
    totalTokens: '0',
    totalProfit: '0',
    activeInvestments: 0
  });

  useEffect(() => {
    if (isConnected && address) {
      // 模拟用户投资数据
      setInvestments([
        {
          crowdsaleAddress: '0x1234...5678',
          crowdsaleName: 'DeFi Token Sale',
          investedAmount: '2.5',
          tokenAmount: '5000',
          investmentDate: Date.now() - 86400000 * 5,
          status: 'active'
        },
        {
          crowdsaleAddress: '0x9876...5432',
          crowdsaleName: 'GameFi Project',
          investedAmount: '1.0',
          tokenAmount: '2000',
          investmentDate: Date.now() - 86400000 * 15,
          status: 'completed'
        }
      ]);

      // 模拟代币释放计划
      setVestingSchedules([
        {
          scheduleId: '1',
          tokenAmount: '5000',
          releasedAmount: '1000',
          nextReleaseDate: Date.now() + 86400000 * 30,
          totalReleases: 12,
          completedReleases: 2
        }
      ]);

      // 计算总统计
      setTotalStats({
        totalInvested: '3.5',
        totalTokens: '7000',
        totalProfit: '0.8',
        activeInvestments: 1
      });
    }
  }, [isConnected, address]);

  const tokenBalances = [
    {
      symbol: 'DFT',
      balance: '5000',
      decimals: 18,
      address: '0x1234567890123456789012345678901234567890',
      usdValue: 150
    },
    {
      symbol: 'GFT',
      balance: '2000',
      decimals: 18,
      address: '0x9876543210987654321098765432109876543210',
      usdValue: 80
    }
  ];

  if (!isConnected) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className="max-w-md mx-auto">
          <CardContent className="p-8 text-center">
            <ChartBarIcon className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
              连接钱包查看仪表板
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              连接您的钱包以查看投资组合和交易历史
            </p>
            <Button variant="primary" size="lg">
              连接钱包
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* 页面标题 */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
          投资仪表板
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-2">
          管理您的投资组合和代币持仓
        </p>
      </div>

      {/* 统计卡片 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="p-3 rounded-full bg-blue-100 dark:bg-blue-900">
                <CurrencyDollarIcon className="h-6 w-6 text-blue-600 dark:text-blue-400" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                  总投资
                </p>
                <p className="text-2xl font-bold text-gray-900 dark:text-white">
                  {totalStats.totalInvested} ETH
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="p-3 rounded-full bg-green-100 dark:bg-green-900">
                <TrophyIcon className="h-6 w-6 text-green-600 dark:text-green-400" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                  代币总量
                </p>
                <p className="text-2xl font-bold text-gray-900 dark:text-white">
                  {formatTokenAmount(totalStats.totalTokens)}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="p-3 rounded-full bg-purple-100 dark:bg-purple-900">
                <ChartBarIcon className="h-6 w-6 text-purple-600 dark:text-purple-400" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                  预估收益
                </p>
                <p className="text-2xl font-bold text-green-600">
                  +{totalStats.totalProfit} ETH
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="p-3 rounded-full bg-orange-100 dark:bg-orange-900">
                <ClockIcon className="h-6 w-6 text-orange-600 dark:text-orange-400" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                  活跃投资
                </p>
                <p className="text-2xl font-bold text-gray-900 dark:text-white">
                  {totalStats.activeInvestments}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* 左侧主要内容 */}
        <div className="lg:col-span-2 space-y-8">
          {/* 投资历史 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                我的投资
              </h3>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {investments.map((investment, index) => (
                  <div
                    key={index}
                    className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg"
                  >
                    <div className="flex items-center">
                      <div className="w-10 h-10 bg-gradient-to-br from-blue-400 to-purple-500 rounded-full flex items-center justify-center mr-4">
                        <span className="text-white text-sm font-bold">
                          {investment.crowdsaleName.slice(0, 2)}
                        </span>
                      </div>
                      <div>
                        <p className="font-medium text-gray-900 dark:text-white">
                          {investment.crowdsaleName}
                        </p>
                        <p className="text-sm text-gray-500 dark:text-gray-400">
                          {new Date(investment.investmentDate).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold text-gray-900 dark:text-white">
                        {investment.investedAmount} ETH
                      </p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        {formatTokenAmount(investment.tokenAmount)} 代币
                      </p>
                    </div>
                    <div className="flex items-center space-x-2">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        investment.status === 'active' 
                          ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                          : investment.status === 'completed'
                          ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                          : 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                      }`}>
                        {investment.status === 'active' ? '进行中' : 
                         investment.status === 'completed' ? '已完成' : '已退款'}
                      </span>
                      <Button variant="ghost" size="sm">
                        <ArrowTopRightOnSquareIcon className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* 代币释放进度 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                代币释放进度
              </h3>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {vestingSchedules.map((schedule, index) => (
                  <div key={index} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                    <div className="flex justify-between items-center mb-4">
                      <div>
                        <p className="font-medium text-gray-900 dark:text-white">
                          释放计划 #{schedule.scheduleId}
                        </p>
                        <p className="text-sm text-gray-500 dark:text-gray-400">
                          总量: {formatTokenAmount(schedule.tokenAmount)}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                          下次释放
                        </p>
                        <p className="font-medium text-gray-900 dark:text-white">
                          {new Date(schedule.nextReleaseDate).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                    
                    <div className="mb-4">
                      <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400 mb-2">
                        <span>释放进度</span>
                        <span>{schedule.completedReleases}/{schedule.totalReleases}</span>
                      </div>
                      <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div
                          className="bg-blue-600 h-2 rounded-full"
                          style={{
                            width: `${(schedule.completedReleases / schedule.totalReleases) * 100}%`
                          }}
                        />
                      </div>
                    </div>
                    
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600 dark:text-gray-400">
                        已释放: {formatTokenAmount(schedule.releasedAmount)}
                      </span>
                      <span className="text-gray-600 dark:text-gray-400">
                        剩余: {formatTokenAmount((parseFloat(schedule.tokenAmount) - parseFloat(schedule.releasedAmount)).toString())}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 右侧钱包信息 */}
        <div className="space-y-6">
          <BalanceCard
            ethBalance={balance}
            tokenBalances={tokenBalances}
            totalUsdValue={230}
          />

          {/* 快速操作 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                快速操作
              </h3>
            </CardHeader>
            <CardContent className="space-y-3">
              <Button variant="primary" className="w-full">
                浏览众筹项目
              </Button>
              <Button variant="secondary" className="w-full">
                查看交易历史
              </Button>
              <Button variant="ghost" className="w-full">
                导出投资报告
              </Button>
            </CardContent>
          </Card>

          {/* 推荐项目 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                推荐项目
              </h3>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="p-3 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-lg">
                  <p className="font-medium text-gray-900 dark:text-white text-sm">
                    AI Token Launch
                  </p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">
                    即将开始 • 20% 早鸟折扣
                  </p>
                </div>
                <div className="p-3 bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg">
                  <p className="font-medium text-gray-900 dark:text-white text-sm">
                    Green Energy DAO
                  </p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">
                    白名单开放 • 环保主题
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};
