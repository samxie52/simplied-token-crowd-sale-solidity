import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWallet } from '@/hooks/useWallet';
import { useUserInvestments } from '@/hooks/useUserInvestments';
import { useTokenVesting } from '@/hooks/useTokenVesting';
import { useInvestmentStats } from '@/hooks/useInvestmentStats';
import { useMultiCrowdsale } from '@/hooks/useMultiCrowdsale';
import { BalanceCard } from '@/components/wallet/BalanceCard';
import { InvestmentCard } from '@/components/dashboard/InvestmentCard';
import { VestingProgressCard } from '@/components/dashboard/VestingProgressCard';
import { InvestmentDetailModal } from '@/components/dashboard/InvestmentDetailModal';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { formatTokenAmount } from '@/utils/formatters';
import { 
  ChartBarIcon,
  CurrencyDollarIcon,
  TrophyIcon,
  ClockIcon,
  ExclamationTriangleIcon,
  ArrowPathIcon
} from '@heroicons/react/24/outline';
import { UserInvestment } from '@/hooks/useUserInvestments';
import toast from 'react-hot-toast';


export const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const { address, isConnected, balance } = useWallet();
  const { investments, loading: investmentsLoading, error: investmentsError, refreshInvestments } = useUserInvestments(address || undefined);
  const { vestingSchedules, loading: vestingLoading, error: vestingError, releaseTokens, batchReleaseTokens, releasing, refresh: refreshVestingSchedules } = useTokenVesting();
  const { projects, loading: multiLoading } = useMultiCrowdsale();
  const { stats } = useInvestmentStats(investments, vestingSchedules);
  const [selectedInvestment, setSelectedInvestment] = useState<UserInvestment | null>(null);
  const [selectedVestingIds, setSelectedVestingIds] = useState<string[]>([]);

  const handleTokenRelease = async (scheduleId: string) => {
    try {
      await releaseTokens(scheduleId);
    } catch (error) {
      console.error('Token release failed:', error);
    }
  };

  const handleBatchRelease = async () => {
    if (selectedVestingIds.length === 0) {
      toast.error('请选择要释放的计划');
      return;
    }
    try {
      await batchReleaseTokens(selectedVestingIds);
      setSelectedVestingIds([]);
    } catch (error) {
      console.error('Batch release failed:', error);
    }
  };

  const handleRefreshData = async () => {
    await refreshInvestments();
    await refreshVestingSchedules();
    toast.success('数据已刷新');
  };

  const handleBrowseCrowdsales = () => {
    navigate('/');
  };

  const toggleVestingSelection = (scheduleId: string) => {
    setSelectedVestingIds(prev => 
      prev.includes(scheduleId) 
        ? prev.filter(id => id !== scheduleId)
        : [...prev, scheduleId]
    );
  };

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
                <div className="text-2xl font-bold text-gray-900">
                  ${parseFloat(stats.totalInvested || '0').toFixed(2)}
                </div>
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
                <div className="text-2xl font-bold text-gray-900">
                  {formatTokenAmount(stats.totalTokens || '0')}
                </div>
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
                <div className="text-2xl font-bold text-gray-900">
                  <span className={parseFloat(stats.totalProfit || '0') >= 0 ? 'text-green-600' : 'text-red-600'}>
                    ${parseFloat(stats.totalProfit || '0') >= 0 ? '+' : ''}${parseFloat(stats.totalProfit || '0').toFixed(2)}
                  </span>
                </div>
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
                <div className="text-2xl font-bold text-gray-900">
                  {stats.activeInvestments || 0}
                </div>
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
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                  我的投资
                </h3>
                <Button 
                  variant="ghost" 
                  size="sm" 
                  onClick={handleRefreshData}
                  disabled={investmentsLoading}
                >
                  <ArrowPathIcon className={`h-4 w-4 ${investmentsLoading ? 'animate-spin' : ''}`} />
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {investmentsLoading ? (
                <div className="flex items-center justify-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span className="ml-2 text-gray-500">加载投资数据...</span>
                </div>
              ) : investmentsError ? (
                <div className="text-center py-8">
                  <ExclamationTriangleIcon className="h-12 w-12 text-red-500 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">加载失败</h3>
                  <p className="text-gray-500 mb-4">{investmentsError}</p>
                  <Button onClick={handleRefreshData}>重试</Button>
                </div>
              ) : investments.length === 0 ? (
                <div className="text-center py-8">
                  <ChartBarIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">暂无投资记录</h3>
                  <p className="text-gray-500 mb-4">您还没有参与任何众筹项目</p>
                  <Button variant="primary" onClick={handleBrowseCrowdsales}>浏览众筹项目</Button>
                </div>
              ) : (
                <div className="grid gap-4">
                  {investments.map((investment, index) => (
                    <InvestmentCard
                      key={`${investment.crowdsaleAddress}-${index}`}
                      investment={investment}
                      onClick={() => setSelectedInvestment(investment)}
                    />
                  ))}
                  {investmentsError && (
                    <Card className="p-4 border-red-200 bg-red-50">
                      <div className="text-red-600">{investmentsError}</div>
                      <Button 
                        onClick={refreshInvestments}
                        className="mt-2 bg-red-600 hover:bg-red-700"
                        size="sm"
                      >
                        Retry
                      </Button>
                    </Card>
                  )}
                </div>
              )}
            </CardContent>
          </Card>

          {/* 代币释放进度 */}
          <Card>
            <CardHeader>
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                  代币释放进度
                </h3>
                {vestingSchedules.length > 0 && (
                  <div className="flex gap-2">
                    {selectedVestingIds.length > 0 && (
                      <Button 
                        size="sm" 
                        onClick={handleBatchRelease}
                        disabled={releasing}
                      >
                        批量释放 ({selectedVestingIds.length})
                      </Button>
                    )}
                    <Button 
                      variant="ghost" 
                      size="sm" 
                      onClick={refreshVestingSchedules}
                      disabled={vestingLoading}
                    >
                      <ArrowPathIcon className={`h-4 w-4 ${vestingLoading ? 'animate-spin' : ''}`} />
                    </Button>
                  </div>
                )}
              </div>
            </CardHeader>
            <CardContent>
              {vestingLoading ? (
                <div className="flex items-center justify-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span className="ml-2 text-gray-500">加载释放数据...</span>
                </div>
              ) : vestingError ? (
                <div className="text-center py-8">
                  <ExclamationTriangleIcon className="h-12 w-12 text-red-500 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">加载失败</h3>
                  <p className="text-gray-500 mb-4">{vestingError}</p>
                  <Button onClick={refreshVestingSchedules}>重试</Button>
                </div>
              ) : vestingSchedules.length === 0 ? (
                <div className="text-center py-8">
                  <ClockIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">暂无释放计划</h3>
                  <p className="text-gray-500">您还没有任何代币释放计划</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {vestingSchedules.map((schedule) => (
                    <div key={schedule.id} className="relative">
                      <div className="absolute top-4 left-4 z-10">
                        <input
                          type="checkbox"
                          checked={selectedVestingIds.includes(schedule.id)}
                          onChange={() => toggleVestingSelection(schedule.id)}
                          className="h-4 w-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                          disabled={parseFloat(schedule.releasableAmount) === 0 || schedule.isRevoked}
                        />
                      </div>
                      <VestingProgressCard
                        schedule={schedule}
                        onRelease={handleTokenRelease}
                        releasing={releasing}
                      />
                    </div>
                  ))}
                  {vestingError && (
                    <Card className="p-4 border-red-200 bg-red-50">
                      <div className="text-red-600">{vestingError}</div>
                      <Button onClick={refreshVestingSchedules} className="mt-2 bg-red-600 hover:bg-red-700" size="sm">
                        Retry
                      </Button>
                    </Card>
                  )}
                  {vestingSchedules.length === 0 && !vestingLoading && !vestingError && (
                    <Card className="p-8 text-center text-gray-500">
                      <ClockIcon className="h-12 w-12 mx-auto mb-4 text-gray-400" />
                      <p>No vesting schedules found</p>
                    </Card>
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* 右侧钱包信息 */}
        <div className="space-y-6">
          <BalanceCard 
            ethBalance={balance || '0'}
            tokenBalances={[]}
          />

          {/* 快速操作 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                快速操作
              </h3>
            </CardHeader>
            <CardContent className="space-y-3">
              <Button variant="primary" className="w-full" onClick={handleBrowseCrowdsales}>
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

      {/* Investment Detail Modal */}
      <InvestmentDetailModal
        investment={selectedInvestment}
        isOpen={!!selectedInvestment}
        onClose={() => setSelectedInvestment(null)}
      />
    </div>
  );
};
