import React from 'react';
import { Card, CardHeader, CardContent, CardFooter } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { useCrowdsaleData } from '@/hooks/useCrowdsaleData';
import { formatWeiToEther, formatTimeRemaining, formatCrowdsalePhase, calculateProgress } from '@/utils/formatters';
import { CrowdsaleInstance } from '@/types/contracts';
import { ClockIcon, CurrencyDollarIcon, UsersIcon } from '@heroicons/react/24/outline';

interface CrowdsaleCardProps {
  instance: CrowdsaleInstance;
  onSelect?: (address: string) => void;
}

export const CrowdsaleCard: React.FC<CrowdsaleCardProps> = ({ instance, onSelect }) => {
  const { config, stats, phase } = useCrowdsaleData(instance.crowdsaleAddress);

  // Use real contract data or fallback to default values
  const displayConfig = config || {
    presaleStartTime: BigInt(Math.floor(Date.now() / 1000)),
    presaleEndTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 7),
    publicSaleStartTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 7),
    publicSaleEndTime: BigInt(Math.floor(Date.now() / 1000) + 86400 * 14),
    softCap: BigInt('100000000000000000000'), // 100 ETH (from deployment)
    hardCap: BigInt('1000000000000000000000'), // 1000 ETH (from deployment)
    minPurchase: BigInt('10000000000000000'), // 0.01 ETH (from deployment)
    maxPurchase: BigInt('1000000000000000000000'), // 1000 ETH (from deployment)
  };

  const displayStats = stats || {
    totalRaised: BigInt('0'), // Start with 0 for new crowdsale
    totalTokensSold: BigInt('0'), // Start with 0 for new crowdsale
    totalPurchases: BigInt(0),
    totalParticipants: BigInt(0),
    participantCount: BigInt(0),
    presaleRaised: BigInt('0'),
    publicSaleRaised: BigInt('0'),
  };

  const displayPhase = phase !== null ? phase : 0; // Default to PENDING phase

  const progress = calculateProgress(displayStats.totalRaised, displayConfig.hardCap);
  const remainingTime = formatTimeRemaining(
    displayPhase === 1 ? displayConfig.presaleEndTime : displayConfig.publicSaleEndTime
  );

  return (
    <Card className="hover:shadow-lg transition-all duration-300 cursor-pointer border-l-4 border-l-primary-500">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900">
            Token Crowdsale
          </h3>
          <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
            displayPhase === 0 ? 'bg-yellow-100 text-yellow-800' :
            displayPhase === 1 ? 'bg-blue-100 text-blue-800' :
            displayPhase === 2 ? 'bg-green-100 text-green-800' :
            displayPhase === 3 ? 'bg-gray-100 text-gray-800' :
            'bg-yellow-100 text-yellow-800'
          }`}>
            {formatCrowdsalePhase(displayPhase)}
          </span>
        </div>
        <p className="text-xs text-gray-500 mt-1 font-mono">
          {instance.crowdsaleAddress.slice(0, 10)}...{instance.crowdsaleAddress.slice(-8)}
        </p>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Progress Bar */}
        <div>
          <div className="flex justify-between text-sm text-gray-600 mb-2">
            <span className="font-medium">Funding Progress</span>
            <span className="font-semibold text-primary-600">{progress.toFixed(1)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
            <div
              className="bg-gradient-to-r from-primary-500 to-primary-600 h-3 rounded-full transition-all duration-500 ease-out shadow-sm"
              style={{ width: `${Math.min(progress, 100)}%` }}
            />
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-gray-50 rounded-lg p-3 flex items-center space-x-3">
            <div className="flex-shrink-0">
              <CurrencyDollarIcon className="w-5 h-5 text-green-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 font-medium">Raised</p>
              <p className="text-sm font-bold text-gray-900">
                {formatWeiToEther(displayStats.totalRaised)} ETH
              </p>
            </div>
          </div>
          
          <div className="bg-gray-50 rounded-lg p-3 flex items-center space-x-3">
            <div className="flex-shrink-0">
              <UsersIcon className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 font-medium">Participants</p>
              <p className="text-sm font-bold text-gray-900">
                {displayStats.totalParticipants.toString()}
              </p>
            </div>
          </div>
        </div>

        {/* Time Remaining */}
        {(displayPhase === 1 || displayPhase === 2) && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 flex items-center space-x-2">
            <ClockIcon className="w-4 h-4 text-blue-600" />
            <span className="text-sm font-medium text-blue-800">Ends in {remainingTime}</span>
          </div>
        )}

        {/* Funding Targets */}
        <div className="border-t border-gray-100 pt-3">
          <div className="flex justify-between text-xs">
            <div className="text-center">
              <p className="text-gray-500 font-medium">Soft Cap</p>
              <p className="font-bold text-gray-700">{formatWeiToEther(displayConfig.softCap)} ETH</p>
            </div>
            <div className="text-center">
              <p className="text-gray-500 font-medium">Hard Cap</p>
              <p className="font-bold text-gray-700">{formatWeiToEther(displayConfig.hardCap)} ETH</p>
            </div>
          </div>
        </div>
      </CardContent>

      <CardFooter>
        <Button
          onClick={() => onSelect?.(instance.crowdsaleAddress)}
          className="w-full"
          disabled={displayPhase === 3}
        >
          {displayPhase === 3 ? 'Finalized' : 'View Details'}
        </Button>
      </CardFooter>
    </Card>
  );
};
