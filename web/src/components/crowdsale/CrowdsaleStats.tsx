import React from 'react';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { ProgressBar } from '@/components/charts/ProgressBar';
import { PieChart } from '@/components/charts/PieChart';
import { formatEther, formatTokenAmount, formatPercentage } from '@/utils/formatters';
import { CrowdsaleStats as CrowdsaleStatsType } from '@/types/contracts';
import { 
  CurrencyDollarIcon, 
  UsersIcon, 
  ClockIcon, 
  ChartBarIcon 
} from '@heroicons/react/24/outline';

interface CrowdsaleStatsProps {
  stats: CrowdsaleStatsType;
  config: {
    softCap: string;
    hardCap: string;
    tokenPrice: string;
  };
  className?: string;
}

export const CrowdsaleStats: React.FC<CrowdsaleStatsProps> = ({
  stats,
  config,
  className = ''
}) => {
  const raisedAmount = parseFloat(formatEther(stats.totalRaised));
  const softCap = parseFloat(formatEther(config.softCap));
  const hardCap = parseFloat(formatEther(config.hardCap));
  
  const progress = (raisedAmount / hardCap) * 100;
  const softCapProgress = (raisedAmount / softCap) * 100;
  
  // 饼图数据
  const pieData = [
    {
      name: '已筹集',
      value: raisedAmount,
      color: '#3B82F6'
    },
    {
      name: '剩余目标',
      value: Math.max(0, hardCap - raisedAmount),
      color: '#E5E7EB'
    }
  ];

  const statCards = [
    {
      title: '筹集金额',
      value: `${raisedAmount.toFixed(2)} ETH`,
      subValue: `目标: ${hardCap.toFixed(0)} ETH`,
      icon: CurrencyDollarIcon,
      color: 'text-blue-600'
    },
    {
      title: '参与人数',
      value: stats.totalParticipants.toString(),
      subValue: `平均: ${(raisedAmount / parseInt(stats.totalParticipants) || 0).toFixed(2)} ETH`,
      icon: UsersIcon,
      color: 'text-green-600'
    },
    {
      title: '代币销售',
      value: formatTokenAmount(stats.tokensSold),
      subValue: `价格: ${formatEther(config.tokenPrice)} ETH`,
      icon: ChartBarIcon,
      color: 'text-purple-600'
    },
    {
      title: '完成度',
      value: formatPercentage(progress),
      subValue: `软顶: ${formatPercentage(softCapProgress)}`,
      icon: ClockIcon,
      color: progress >= 100 ? 'text-green-600' : 'text-orange-600'
    }
  ];

  return (
    <div className={`space-y-6 ${className}`}>
      {/* 统计卡片网格 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat, index) => (
          <Card key={index} className="p-4">
            <CardContent className="p-0">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                    {stat.title}
                  </p>
                  <p className={`text-2xl font-bold ${stat.color}`}>
                    {stat.value}
                  </p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    {stat.subValue}
                  </p>
                </div>
                <stat.icon className={`h-8 w-8 ${stat.color}`} />
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* 进度条和饼图 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* 筹资进度 */}
        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
              筹资进度
            </h3>
          </CardHeader>
          <CardContent className="space-y-4">
            <ProgressBar
              current={raisedAmount}
              target={hardCap}
              color={progress >= 100 ? 'success' : progress >= 75 ? 'warning' : 'primary'}
            />
            
            {/* 软顶指示器 */}
            <div className="relative">
              <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400">
                <span>软顶: {softCap.toFixed(0)} ETH</span>
                <span className={softCapProgress >= 100 ? 'text-green-600 font-medium' : ''}>
                  {softCapProgress >= 100 ? '✓ 已达成' : `还需 ${(softCap - raisedAmount).toFixed(2)} ETH`}
                </span>
              </div>
              <div className="w-full bg-gray-100 rounded-full h-1 mt-2">
                <div
                  className={`h-1 rounded-full ${
                    softCapProgress >= 100 ? 'bg-green-500' : 'bg-orange-500'
                  }`}
                  style={{ width: `${Math.min(softCapProgress, 100)}%` }}
                />
              </div>
            </div>
          </CardContent>
        </Card>

        {/* 资金分布饼图 */}
        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
              资金分布
            </h3>
          </CardHeader>
          <CardContent>
            <PieChart
              data={pieData}
              height={250}
              showLegend={true}
            />
          </CardContent>
        </Card>
      </div>

      {/* 关键指标 */}
      <Card>
        <CardHeader>
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
            关键指标
          </h3>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="text-center">
              <p className="text-2xl font-bold text-blue-600">
                {formatPercentage((raisedAmount / hardCap) * 100)}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">硬顶完成度</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-green-600">
                {formatPercentage((raisedAmount / softCap) * 100)}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">软顶完成度</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-purple-600">
                {(raisedAmount / parseInt(stats.totalParticipants) || 0).toFixed(2)}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">平均投资(ETH)</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-orange-600">
                {stats.totalPurchases}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">总交易数</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};
