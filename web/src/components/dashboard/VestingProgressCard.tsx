import React from 'react';
import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { VestingSchedule } from '@/hooks/useTokenVesting';
import { formatDate, formatEther } from '@/utils/formatters';
import { 
  ClockIcon,
  CurrencyDollarIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon 
} from '@heroicons/react/24/outline';

interface VestingProgressCardProps {
  schedule: VestingSchedule;
  onRelease: (scheduleId: string) => void;
  releasing: boolean;
}

export const VestingProgressCard: React.FC<VestingProgressCardProps> = ({ 
  schedule, 
  onRelease, 
  releasing 
}) => {
  const canRelease = parseFloat(schedule.releasableAmount) > 0;
  const isCompleted = schedule.releaseProgress >= 100;
  const isRevoked = schedule.isRevoked;
  
  const getVestingTypeColor = (type: string) => {
    switch (type) {
      case 'LINEAR':
        return 'bg-blue-100 text-blue-800';
      case 'CLIFF':
        return 'bg-purple-100 text-purple-800';
      case 'STEPPED':
        return 'bg-green-100 text-green-800';
      case 'MILESTONE':
        return 'bg-orange-100 text-orange-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getVestingTypeText = (type: string) => {
    switch (type) {
      case 'LINEAR':
        return '线性释放';
      case 'CLIFF':
        return '悬崖释放';
      case 'STEPPED':
        return '阶梯释放';
      case 'MILESTONE':
        return '里程碑释放';
      default:
        return type;
    }
  };

  return (
    <Card className={`p-4 border-l-4 ${
      isRevoked ? 'border-l-red-500 bg-red-50' : 
      isCompleted ? 'border-l-green-500' : 'border-l-blue-500'
    }`}>
      <CardContent className="p-0">
        <div className="flex justify-between items-start mb-3">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              <h4 className="font-semibold text-gray-900">{schedule.tokenSymbol} 释放计划</h4>
              {isRevoked && <ExclamationTriangleIcon className="h-5 w-5 text-red-500" />}
              {isCompleted && <CheckCircleIcon className="h-5 w-5 text-green-500" />}
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              <span className={`px-2 py-1 rounded-full text-xs font-medium ${getVestingTypeColor(schedule.vestingType)}`}>
                {getVestingTypeText(schedule.vestingType)}
              </span>
              <span className="text-xs text-gray-500">
                {formatDate(schedule.startTime)} - {formatDate(schedule.endTime)}
              </span>
            </div>
          </div>
          {canRelease && !isRevoked && (
            <Button 
              size="sm" 
              onClick={() => onRelease(schedule.scheduleId)}
              disabled={releasing}
              className="ml-2"
            >
              {releasing ? '释放中...' : '释放代币'}
            </Button>
          )}
        </div>
        
        {isRevoked ? (
          <div className="bg-red-100 border border-red-200 rounded-lg p-3 mb-3">
            <p className="text-red-800 text-sm font-medium">此释放计划已被撤销</p>
          </div>
        ) : (
          <>
            <div className="mb-4">
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-600">释放进度</span>
                <span className="font-medium">{schedule.releaseProgress.toFixed(1)}%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-3">
                <div 
                  className={`h-3 rounded-full transition-all duration-500 ${
                    isCompleted ? 'bg-green-500' : 'bg-blue-500'
                  }`}
                  style={{ width: `${Math.min(schedule.releaseProgress, 100)}%` }}
                />
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <CurrencyDollarIcon className="h-4 w-4 text-gray-400" />
                  <div>
                    <p className="text-xs text-gray-500">总代币量</p>
                    <p className="font-medium">{formatEther(schedule.totalAmount)}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircleIcon className="h-4 w-4 text-green-400" />
                  <div>
                    <p className="text-xs text-gray-500">已释放</p>
                    <p className="font-medium text-green-600">{formatEther(schedule.releasedAmount)}</p>
                  </div>
                </div>
              </div>
              
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <ClockIcon className="h-4 w-4 text-blue-400" />
                  <div>
                    <p className="text-xs text-gray-500">可释放</p>
                    <p className={`font-medium ${canRelease ? 'text-blue-600' : 'text-gray-500'}`}>
                      {formatEther(schedule.releasableAmount)}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <CurrencyDollarIcon className="h-4 w-4 text-gray-400" />
                  <div>
                    <p className="text-xs text-gray-500">剩余</p>
                    <p className="font-medium">{formatEther(schedule.remainingAmount)}</p>
                  </div>
                </div>
              </div>
            </div>
            
            {schedule.nextReleaseDate > 0 && schedule.nextReleaseDate > Date.now() / 1000 && (
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                <div className="flex items-center gap-2">
                  <ClockIcon className="h-4 w-4 text-blue-500" />
                  <p className="text-blue-800 text-sm">
                    下次释放时间: {formatDate(schedule.nextReleaseDate)}
                  </p>
                </div>
              </div>
            )}
            
            {schedule.cliffEnd > Date.now() / 1000 && (
              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                <div className="flex items-center gap-2">
                  <ExclamationTriangleIcon className="h-4 w-4 text-yellow-500" />
                  <p className="text-yellow-800 text-sm">
                    悬崖期结束: {formatDate(schedule.cliffEnd)}
                  </p>
                </div>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
};
