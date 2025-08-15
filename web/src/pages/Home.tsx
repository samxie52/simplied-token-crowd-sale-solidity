import React, { useEffect, useState } from 'react';
import { Contract } from 'ethers';
import { useWallet } from '@/hooks/useWallet';
import { CrowdsaleCard } from '@/components/crowdsale/CrowdsaleCard';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { CONTRACT_ABIS, getContractAddress } from '@/utils/contracts';
import { CrowdsaleInstance } from '@/types/contracts';
import { PlusIcon, ChartBarIcon, CurrencyDollarIcon, UsersIcon } from '@heroicons/react/24/outline';

export const Home: React.FC = () => {
  const { getProvider, isConnected } = useWallet();
  const [crowdsales, setCrowdsales] = useState<CrowdsaleInstance[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalCrowdsales: 0,
    activeCrowdsales: 0,
    totalFeesCollected: '0',
  });

  const fetchCrowdsales = async () => {
    try {
      const provider = await getProvider();
      if (!provider) return;

      const factoryAddress = getContractAddress('CrowdsaleFactory');
      if (!factoryAddress) {
        console.warn('Factory address not configured');
        return;
      }

      const factory = new Contract(factoryAddress, CONTRACT_ABIS.CrowdsaleFactory, provider);
      
      const [activeCrowdsales, factoryStats] = await Promise.all([
        factory.getActiveCrowdsales(),
        factory.getFactoryStats(),
      ]);

      setCrowdsales(activeCrowdsales);
      setStats({
        totalCrowdsales: Number(factoryStats[0]),
        activeCrowdsales: Number(factoryStats[1]),
        totalFeesCollected: factoryStats[2].toString(),
      });
    } catch (error) {
      console.error('Failed to fetch crowdsales:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isConnected) {
      fetchCrowdsales();
    } else {
      setLoading(false);
    }
  }, [isConnected]);

  const handleSelectCrowdsale = (address: string) => {
    // Navigate to crowdsale details (will be implemented in routing)
    console.log('Selected crowdsale:', address);
  };

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <div className="max-w-md mx-auto">
          <ChartBarIcon className="mx-auto h-12 w-12 text-gray-400" />
          <h3 className="mt-2 text-sm font-medium text-gray-900">Connect Your Wallet</h3>
          <p className="mt-1 text-sm text-gray-500">
            Connect your wallet to view and participate in token crowdsales.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center">
        <h1 className="text-3xl font-bold text-gray-900">Token Crowdsale Platform</h1>
        <p className="mt-2 text-lg text-gray-600">
          Discover and participate in decentralized token crowdsales
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardContent className="flex items-center p-6">
            <div className="flex-shrink-0">
              <ChartBarIcon className="h-8 w-8 text-primary-600" />
            </div>
            <div className="ml-4">
              <div className="text-sm font-medium text-gray-500">Total Crowdsales</div>
              <div className="text-2xl font-bold text-gray-900">{stats.totalCrowdsales}</div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="flex items-center p-6">
            <div className="flex-shrink-0">
              <CurrencyDollarIcon className="h-8 w-8 text-success-600" />
            </div>
            <div className="ml-4">
              <div className="text-sm font-medium text-gray-500">Active Crowdsales</div>
              <div className="text-2xl font-bold text-gray-900">{stats.activeCrowdsales}</div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="flex items-center p-6">
            <div className="flex-shrink-0">
              <UsersIcon className="h-8 w-8 text-warning-600" />
            </div>
            <div className="ml-4">
              <div className="text-sm font-medium text-gray-500">Platform Fees</div>
              <div className="text-2xl font-bold text-gray-900">
                {(Number(stats.totalFeesCollected) / 1e18).toFixed(2)} ETH
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Actions */}
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold text-gray-900">Active Crowdsales</h2>
        <Button className="inline-flex items-center">
          <PlusIcon className="w-4 h-4 mr-2" />
          Create Crowdsale
        </Button>
      </div>

      {/* Crowdsales Grid */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[...Array(6)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <CardContent className="p-6">
                <div className="space-y-3">
                  <div className="h-4 bg-gray-200 rounded w-3/4"></div>
                  <div className="h-4 bg-gray-200 rounded w-1/2"></div>
                  <div className="h-4 bg-gray-200 rounded w-2/3"></div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : crowdsales.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {crowdsales.map((crowdsale) => (
            <CrowdsaleCard
              key={crowdsale.crowdsaleAddress}
              instance={crowdsale}
              onSelect={handleSelectCrowdsale}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-12">
          <ChartBarIcon className="mx-auto h-12 w-12 text-gray-400" />
          <h3 className="mt-2 text-sm font-medium text-gray-900">No Active Crowdsales</h3>
          <p className="mt-1 text-sm text-gray-500">
            Be the first to create a crowdsale on this platform.
          </p>
          <div className="mt-6">
            <Button className="inline-flex items-center">
              <PlusIcon className="w-4 h-4 mr-2" />
              Create First Crowdsale
            </Button>
          </div>
        </div>
      )}
    </div>
  );
};
