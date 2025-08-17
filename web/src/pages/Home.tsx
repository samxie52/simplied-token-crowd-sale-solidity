import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ethers } from 'ethers';
import { useWallet } from '../hooks/useWallet';
import { useCrowdsaleFactory } from '../hooks/useCrowdsaleFactory';
import { CONTRACTS } from '../utils/contracts';
import { formatEther, formatUnits } from 'ethers';
import Layout from '../components/common/Layout';
import LoadingSpinner from '../components/ui/LoadingSpinner';

const Home: React.FC = () => {
  const { provider, account } = useWallet();
  const {
    activeCrowdsales,
    factoryStats,
    isLoading: factoryLoading,
    error: factoryError,
    refreshAll
  } = useCrowdsaleFactory();
  
  const [crowdsaleDetails, setCrowdsaleDetails] = useState<any[]>([]);
  const [detailsLoading, setDetailsLoading] = useState(false);

  // Fetch detailed information for each crowdsale
  const fetchCrowdsaleDetails = async () => {
    if (!provider || activeCrowdsales.length === 0) return;
    
    setDetailsLoading(true);
    try {
      const details = await Promise.all(
        activeCrowdsales.map(async (crowdsale) => {
          try {
            const contract = new ethers.Contract(
              crowdsale.crowdsaleAddress,
              CONTRACTS.TokenCrowdsale,
              provider
            );
            
            // Fetch crowdsale config and stats
            const [config, stats, phase] = await Promise.all([
              contract.getCrowdsaleConfig(),
              contract.getCrowdsaleStats(), 
              contract.getCurrentPhase()
            ]);
            
            // Get token contract for name and symbol
            const tokenContract = new ethers.Contract(
              crowdsale.tokenAddress,
              CONTRACTS.CrowdsaleToken,
              provider
            );
            
            const [name, symbol] = await Promise.all([
              tokenContract.name(),
              tokenContract.symbol()
            ]);
            
            // Calculate time left
            const now = Math.floor(Date.now() / 1000);
            const endTime = Number(config.endTime);
            const timeLeft = endTime > now ? endTime - now : 0;
            
            // Format phase
            const phases = ['PENDING', 'PRESALE', 'PUBLIC_SALE', 'FINALIZED'];
            const phaseString = phases[Number(phase)] || 'UNKNOWN';
            
            return {
              id: crowdsale.crowdsaleAddress,
              name,
              symbol,
              description: `${name} 众筹项目`,
              raised: formatEther(stats.totalRaised || '0'),
              target: formatEther(config.hardCap || '0'),
              participants: Number(stats.totalParticipants || 0),
              timeLeft: timeLeft > 0 ? `${Math.ceil(timeLeft / 86400)}天` : '已结束',
              price: formatEther(config.tokenPrice || '0'),
              phase: phaseString,
              address: crowdsale.crowdsaleAddress,
              isActive: crowdsale.isActive
            };
          } catch (err) {
            console.error(`Error fetching details for ${crowdsale.crowdsaleAddress}:`, err);
            return {
              id: crowdsale.crowdsaleAddress,
              name: 'Unknown Token',
              symbol: 'UNK',
              description: '获取详情失败',
              raised: '0',
              target: '0',
              participants: 0,
              timeLeft: '未知',
              price: '0',
              phase: 'UNKNOWN',
              address: crowdsale.crowdsaleAddress,
              isActive: crowdsale.isActive
            };
          }
        })
      );
      
      setCrowdsaleDetails(details);
    } catch (err) {
      console.error('Error fetching crowdsale details:', err);
    } finally {
      setDetailsLoading(false);
    }
  };

  // Fetch crowdsale details when active crowdsales change
  useEffect(() => {
    if (activeCrowdsales.length > 0) {
      fetchCrowdsaleDetails();
    }
  }, [activeCrowdsales, provider]);
  
  // Calculate total stats from factory data and crowdsale details
  const calculateTotalStats = () => {
    if (factoryStats) {
      return {
        totalCrowdsales: factoryStats.totalCrowdsales.toString(),
        activeCrowdsales: factoryStats.activeCrowdsales.toString(),
        totalFeesCollected: formatEther(factoryStats.totalFeesCollected),
        totalParticipants: crowdsaleDetails.reduce((sum, c) => sum + c.participants, 0).toString()
      };
    }
    
    // Fallback calculation from crowdsale details
    const totalRaised = crowdsaleDetails.reduce((sum, c) => sum + parseFloat(c.raised || '0'), 0);
    const totalParticipants = crowdsaleDetails.reduce((sum, c) => sum + c.participants, 0);
    
    return {
      totalCrowdsales: crowdsaleDetails.length.toString(),
      activeCrowdsales: crowdsaleDetails.filter(c => c.isActive).length.toString(),
      totalFeesCollected: totalRaised.toFixed(2),
      totalParticipants: totalParticipants.toString()
    };
  };
  
  const stats = calculateTotalStats();

  if (factoryLoading || detailsLoading) {
    return (
      <Layout>
        <div className="flex justify-center items-center min-h-64">
          <LoadingSpinner />
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="space-y-8">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Token Crowdsale Platform</h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            发现并参与去中心化代币众筹，享受透明可信的投资体验
          </p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="text-sm font-medium text-gray-500">总众筹数</div>
            <div className="text-2xl font-bold text-gray-900">{stats.totalCrowdsales}</div>
          </div>
          
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="text-sm font-medium text-gray-500">活跃众筹</div>
            <div className="text-2xl font-bold text-green-600">{stats.activeCrowdsales}</div>
          </div>
          
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="text-sm font-medium text-gray-500">平台费用</div>
            <div className="text-2xl font-bold text-blue-600">{stats.totalFeesCollected} ETH</div>
          </div>
          
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="text-sm font-medium text-gray-500">总参与者</div>
            <div className="text-2xl font-bold text-purple-600">{stats.totalParticipants}</div>
          </div>
        </div>

        {/* Error Display */}
        {factoryError && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-600">获取数据失败: {factoryError}</p>
            <button 
              onClick={refreshAll}
              className="mt-2 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
              重试
            </button>
          </div>
        )}

        {/* Actions */}
        <div className="flex justify-between items-center">
          <h2 className="text-2xl font-semibold text-gray-900">活跃众筹项目</h2>
          <Link 
            to="/create" 
            className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            创建众筹
          </Link>
        </div>

        {/* Crowdsales Grid */}
        {crowdsaleDetails.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-gray-500 text-lg mb-4">暂无活跃的众筹项目</div>
            <p className="text-gray-400 mb-6">成为第一个在平台上创建众筹的用户</p>
            <Link 
              to="/create" 
              className="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              创建首个众筹
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {crowdsaleDetails.map((crowdsale) => (
              <div key={crowdsale.id} className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <h3 className="text-lg font-semibold text-gray-900">{crowdsale.name}</h3>
                    <p className="text-sm text-gray-500">{crowdsale.symbol}</p>
                  </div>
                  <span className={`px-2 py-1 text-xs rounded-full ${
                    crowdsale.phase === 'PUBLIC_SALE' ? 'bg-green-100 text-green-800' :
                    crowdsale.phase === 'PRESALE' ? 'bg-yellow-100 text-yellow-800' :
                    crowdsale.phase === 'PENDING' ? 'bg-gray-100 text-gray-800' :
                    'bg-red-100 text-red-800'
                  }`}>
                    {crowdsale.phase}
                  </span>
                </div>
                
                <p className="text-gray-600 mb-4 text-sm">{crowdsale.description}</p>
                
                <div className="space-y-2 mb-4">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">已筹集:</span>
                    <span className="font-medium">{crowdsale.raised} ETH</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">目标:</span>
                    <span className="font-medium">{crowdsale.target} ETH</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">参与者:</span>
                    <span className="font-medium">{crowdsale.participants}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">剩余时间:</span>
                    <span className="font-medium">{crowdsale.timeLeft}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">代币价格:</span>
                    <span className="font-medium">{crowdsale.price} ETH</span>
                  </div>
                </div>
                
                {/* Progress bar */}
                <div className="mb-4">
                  <div className="flex justify-between text-xs text-gray-500 mb-1">
                    <span>进度</span>
                    <span>{((parseFloat(crowdsale.raised) / parseFloat(crowdsale.target)) * 100).toFixed(1)}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-blue-600 h-2 rounded-full" 
                      style={{ width: `${Math.min((parseFloat(crowdsale.raised) / parseFloat(crowdsale.target)) * 100, 100)}%` }}
                    ></div>
                  </div>
                </div>
                
                <Link 
                  to={`/crowdsale/${crowdsale.address}`}
                  className="block w-full text-center px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                >
                  查看详情
                </Link>
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
};

export default Home;
