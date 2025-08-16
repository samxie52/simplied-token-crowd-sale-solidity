import React from 'react';
import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { UserInvestment } from '@/hooks/useUserInvestments';
import { formatDate, formatEther } from '@/utils/formatters';
import { 
  ArrowTopRightOnSquareIcon,
  ChartBarIcon,
  CurrencyDollarIcon 
} from '@heroicons/react/24/outline';

interface InvestmentCardProps {
  investment: UserInvestment;
  onClick: () => void;
}

export const InvestmentCard: React.FC<InvestmentCardProps> = ({ investment, onClick }) => {
  const profitColor = parseFloat(investment.profitLoss) >= 0 ? 'text-green-600' : 'text-red-600';
  const profitBgColor = parseFloat(investment.profitLoss) >= 0 ? 'bg-green-100' : 'bg-red-100';
  
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800';
      case 'completed':
        return 'bg-blue-100 text-blue-800';
      case 'refunded':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'active':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'refunded':
        return '已退款';
      default:
        return status;
    }
  };

  return (
    <Card className="p-4 hover:shadow-lg transition-all duration-200 cursor-pointer border-l-4 border-l-blue-500" 
          onClick={onClick}>
      <CardContent className="p-0">
        <div className="flex justify-between items-start mb-3">
          <div className="flex-1">
            <h4 className="font-semibold text-gray-900 mb-1">{investment.crowdsaleName}</h4>
            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-500">{investment.tokenSymbol}</span>
              <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(investment.status)}`}>
                {getStatusText(investment.status)}
              </span>
            </div>
          </div>
          <ArrowTopRightOnSquareIcon className="h-5 w-5 text-gray-400" />
        </div>
        
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-4">
            <div className="flex items-center gap-2">
              <CurrencyDollarIcon className="h-4 w-4 text-gray-400" />
              <div>
                <p className="text-xs text-gray-500">投资金额</p>
                <p className="font-medium">{formatEther(investment.investedAmount)} ETH</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <ChartBarIcon className="h-4 w-4 text-gray-400" />
              <div>
                <p className="text-xs text-gray-500">获得代币</p>
                <p className="font-medium">{formatEther(investment.tokenAmount)}</p>
              </div>
            </div>
          </div>
          
          <div className="border-t pt-3">
            <div className="flex justify-between items-center">
              <div>
                <p className="text-xs text-gray-500">当前价值</p>
                <p className="font-semibold text-gray-900">${investment.currentValue}</p>
              </div>
              <div className="text-right">
                <p className="text-xs text-gray-500">收益</p>
                <div className={`px-2 py-1 rounded ${profitBgColor}`}>
                  <p className={`font-semibold text-sm ${profitColor}`}>
                    ${investment.profitLoss}
                  </p>
                  <p className={`text-xs ${profitColor}`}>
                    ({investment.profitLossPercentage > 0 ? '+' : ''}{investment.profitLossPercentage.toFixed(2)}%)
                  </p>
                </div>
              </div>
            </div>
          </div>
          
          <div className="text-xs text-gray-400">
            投资时间: {formatDate(investment.investmentDate)}
          </div>
        </div>
      </CardContent>
    </Card>
  );
};
