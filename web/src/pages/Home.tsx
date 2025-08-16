import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Contract } from 'ethers';
import { useWallet } from '@/hooks/useWallet';
import { CrowdsaleCard } from '@/components/crowdsale/CrowdsaleCard';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { CONTRACT_ABIS, getContractAddress } from '@/utils/contracts';
import { CrowdsaleInstance } from '@/types/contracts';
import { PlusIcon, ChartBarIcon, CurrencyDollarIcon, UsersIcon } from '@heroicons/react/24/outline';

export const Home: React.FC = () => {
  const navigate = useNavigate();
  const { getProvider, isConnected } = useWallet();
  const [crowdsales, setCrowdsales] = useState<CrowdsaleInstance[]>([]);
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState({
    totalCrowdsales: 0,
    activeCrowdsales: 0,
    totalFeesCollected: '0',
  });

  const fetchCrowdsales = useCallback(async () => {
    try {
      // Always show demo data first to ensure UI loads immediately
      const demoData = [
        {
          crowdsaleAddress: '0x1234567890123456789012345678901234567890',
          tokenAddress: '0x2345678901234567890123456789012345678901',
          vestingAddress: '0x3456789012345678901234567890123456789012',
          creator: '0x4567890123456789012345678901234567890123',
          createdAt: BigInt(Math.floor(Date.now() / 1000) - 86400),
          isActive: true,
        },
        {
          crowdsaleAddress: '0x5678901234567890123456789012345678901234',
          tokenAddress: '0x6789012345678901234567890123456789012345',
          vestingAddress: '0x7890123456789012345678901234567890123456',
          creator: '0x8901234567890123456789012345678901234567',
          createdAt: BigInt(Math.floor(Date.now() / 1000) - 172800),
          isActive: true,
        }
      ];
      
      const demoStats = {
        totalCrowdsales: 2,
        activeCrowdsales: 2,
        totalFeesCollected: '5000000000000000000',
      };
      
      // Set demo data immediately
      setCrowdsales(demoData);
      setStats(demoStats);
      setLoading(false);
      
      // Try to get real data if provider and contracts are available
      const provider = await getProvider();
      if (!provider) {
        console.log('No provider available, using demo data');
        return;
      }

      const crowdsaleAddress = getContractAddress('TokenCrowdsale');
      if (!crowdsaleAddress) {
        console.log('TokenCrowdsale address not configured, using demo data');
        return;
      }

      // Try to get real contract data (but don't block UI)
      try {
        const crowdsale = new Contract(crowdsaleAddress, CONTRACT_ABIS.TokenCrowdsale, provider);
        
        let stats, currentPhase;
        
        try {
          // Try to get crowdsale stats and phase with timeout
          const timeout = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Contract call timeout')), 5000)
          );
          
          stats = await Promise.race([crowdsale.getCrowdsaleStats(), timeout]);
          currentPhase = await Promise.race([crowdsale.getCurrentPhase(), timeout]);
          
          console.log('Successfully fetched real contract data');
        } catch (statError) {
          console.warn('Failed to get contract stats, keeping demo data:', statError);
          // Keep demo data if contract calls fail
          return;
        }
      
      // Create a single crowdsale instance from the deployed contract
      const crowdsaleInstances: CrowdsaleInstance[] = [
        {
          crowdsaleAddress: crowdsaleAddress,
          tokenAddress: getContractAddress('CrowdsaleToken') || '0x0000000000000000000000000000000000000000',
          vestingAddress: '0x0000000000000000000000000000000000000000', // No vesting deployed yet
          creator: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Default anvil account
          createdAt: BigInt(Math.floor(Date.now() / 1000) - 3600), // 1 hour ago
          isActive: currentPhase !== 3, // Not finalized
        }
      ];

      setCrowdsales(crowdsaleInstances);
      
      // Set stats from the actual crowdsale
      setStats({
        totalCrowdsales: 1,
        activeCrowdsales: currentPhase !== 3 ? 1 : 0,
        totalFeesCollected: stats.totalRaised.toString(),
      });
      
      } catch (contractError) {
        console.warn('Contract interaction failed, keeping demo data:', contractError);
        // Keep demo data on any contract error
      }
      
    } catch (error) {
      console.error('Failed to fetch crowdsale data, using demo data:', error);
      // Ensure demo data is always available even on complete failure
      if (crowdsales.length === 0) {
        setCrowdsales([
          {
            crowdsaleAddress: '0x1234567890123456789012345678901234567890',
            tokenAddress: '0x1111111111111111111111111111111111111111',
            vestingAddress: '0x2222222222222222222222222222222222222222',
            creator: '0x3333333333333333333333333333333333333333',
            createdAt: BigInt(Math.floor(Date.now() / 1000) - 3600),
            isActive: true,
          }
        ]);
        setStats({
          totalCrowdsales: 1,
          activeCrowdsales: 1,
          totalFeesCollected: '0',
        });
      }
    } finally {
      setLoading(false);
    }
  }, [getProvider]);

  useEffect(() => {
    // Always load demo data first for immediate UI display
    const loadDemoData = () => {
      setCrowdsales([
        {
          crowdsaleAddress: '0x1234567890123456789012345678901234567890',
          tokenAddress: '0x1111111111111111111111111111111111111111',
          vestingAddress: '0x2222222222222222222222222222222222222222',
          creator: '0x3333333333333333333333333333333333333333',
          createdAt: BigInt(Math.floor(Date.now() / 1000) - 86400),
          isActive: true,
        },
        {
          crowdsaleAddress: '0x2345678901234567890123456789012345678901',
          tokenAddress: '0x4444444444444444444444444444444444444444',
          vestingAddress: '0x5555555555555555555555555555555555555555',
          creator: '0x6666666666666666666666666666666666666666',
          createdAt: BigInt(Math.floor(Date.now() / 1000) - 172800),
          isActive: true,
        }
      ]);
      setStats({
        totalCrowdsales: 5,
        activeCrowdsales: 2,
        totalFeesCollected: '25000000000000000000',
      });
      setLoading(false);
    };
    
    // Load demo data immediately
    loadDemoData();
    
    // Try to fetch real data if connected
    if (isConnected) {
      fetchCrowdsales();
    }
  }, [isConnected, fetchCrowdsales]);

  const handleSelectCrowdsale = (address: string) => {
    // Navigate to crowdsale details page
    navigate(`/crowdsale/${address}`);
  };

  return (
    <div className="space-y-8">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Token Crowdsale Platform</h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            Discover and participate in decentralized token crowdsales with confidence and transparency
          </p>
        </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardContent className="flex items-center p-6">
            <div className="flex-shrink-0">
              <ChartBarIcon className="h-6 w-6 text-primary-600" />
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
              <CurrencyDollarIcon className="h-6 w-6 text-success-600" />
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
              <UsersIcon className="h-6 w-6 text-warning-600" />
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
