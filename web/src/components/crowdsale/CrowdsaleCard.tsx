import React from 'react';
import { Card, CardHeader, CardContent, CardFooter } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { useCrowdsale } from '@/hooks/useCrowdsale';
import { formatWeiToEther, formatTimeRemaining, formatCrowdsalePhase, calculateProgress } from '@/utils/formatters';
import { CrowdsaleInstance } from '@/types/contracts';
import { ClockIcon, CurrencyDollarIcon, UsersIcon } from '@heroicons/react/24/outline';

interface CrowdsaleCardProps {
  instance: CrowdsaleInstance;
  onSelect?: (address: string) => void;
}

export const CrowdsaleCard: React.FC<CrowdsaleCardProps> = ({ instance, onSelect }) => {
  const { config, stats, phase } = useCrowdsale(instance.crowdsaleAddress);

  if (!config || !stats || phase === null) {
    return (
      <Card className="animate-pulse">
        <CardContent>
          <div className="space-y-3">
            <div className="h-4 bg-gray-200 rounded w-3/4"></div>
            <div className="h-4 bg-gray-200 rounded w-1/2"></div>
            <div className="h-4 bg-gray-200 rounded w-2/3"></div>
          </div>
        </CardContent>
      </Card>
    );
  }

  const progress = calculateProgress(stats.totalRaised, config.hardCap);
  const remainingTime = formatTimeRemaining(
    phase === 1 ? config.presaleEndTime : config.publicSaleEndTime
  );

  return (
    <Card className="hover:shadow-md transition-shadow cursor-pointer">
      <CardHeader>
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900">
            Token Crowdsale
          </h3>
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
            phase === 1 ? 'bg-blue-100 text-blue-800' :
            phase === 2 ? 'bg-green-100 text-green-800' :
            phase === 3 ? 'bg-gray-100 text-gray-800' :
            'bg-yellow-100 text-yellow-800'
          }`}>
            {formatCrowdsalePhase(phase)}
          </span>
        </div>
        <p className="text-sm text-gray-500 mt-1">
          {instance.crowdsaleAddress.slice(0, 10)}...{instance.crowdsaleAddress.slice(-8)}
        </p>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Progress Bar */}
        <div>
          <div className="flex justify-between text-sm text-gray-600 mb-1">
            <span>Progress</span>
            <span>{progress.toFixed(1)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-primary-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${Math.min(progress, 100)}%` }}
            />
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 gap-4">
          <div className="flex items-center space-x-2">
            <CurrencyDollarIcon className="w-4 h-4 text-gray-400" />
            <div>
              <p className="text-xs text-gray-500">Raised</p>
              <p className="text-sm font-medium">
                {formatWeiToEther(stats.totalRaised)} ETH
              </p>
            </div>
          </div>
          
          <div className="flex items-center space-x-2">
            <UsersIcon className="w-4 h-4 text-gray-400" />
            <div>
              <p className="text-xs text-gray-500">Participants</p>
              <p className="text-sm font-medium">
                {stats.totalParticipants.toString()}
              </p>
            </div>
          </div>
        </div>

        {/* Time Remaining */}
        {(phase === 1 || phase === 2) && (
          <div className="flex items-center space-x-2 text-sm text-gray-600">
            <ClockIcon className="w-4 h-4" />
            <span>Ends in {remainingTime}</span>
          </div>
        )}

        {/* Funding Targets */}
        <div className="text-xs text-gray-500">
          <div className="flex justify-between">
            <span>Soft Cap: {formatWeiToEther(config.softCap)} ETH</span>
            <span>Hard Cap: {formatWeiToEther(config.hardCap)} ETH</span>
          </div>
        </div>
      </CardContent>

      <CardFooter>
        <Button
          onClick={() => onSelect?.(instance.crowdsaleAddress)}
          className="w-full"
          disabled={phase === 3}
        >
          {phase === 3 ? 'Finalized' : 'View Details'}
        </Button>
      </CardFooter>
    </Card>
  );
};
