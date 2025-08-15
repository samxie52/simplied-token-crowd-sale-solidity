import React, { useState, useEffect } from 'react';
import { useWallet } from '@/hooks/useWallet';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { formatTokenAmount } from '@/utils/formatters';
import { 
  CogIcon,
  UserGroupIcon,
  ChartBarIcon,
  ExclamationTriangleIcon,
  PlusIcon,
  PencilIcon,
  TrashIcon,
  PlayIcon,
  PauseIcon
} from '@heroicons/react/24/outline';

interface CrowdsaleManagement {
  address: string;
  name: string;
  status: 'active' | 'paused' | 'finalized';
  raised: string;
  target: string;
  participants: number;
  endTime: number;
}

interface WhitelistUser {
  address: string;
  tier: 'VIP' | 'WHITELISTED';
  allocation: string;
  used: string;
  addedDate: number;
}

export const AdminPanel: React.FC = () => {
  const { isConnected, address } = useWallet();
  const [isAdmin, setIsAdmin] = useState(false);
  const [crowdsales, setCrowdsales] = useState<CrowdsaleManagement[]>([]);
  const [whitelistUsers, setWhitelistUsers] = useState<WhitelistUser[]>([]);
  const [selectedCrowdsale, setSelectedCrowdsale] = useState<string>('');
  const [newUserAddress, setNewUserAddress] = useState('');
  const [newUserTier, setNewUserTier] = useState<'VIP' | 'WHITELISTED'>('WHITELISTED');
  const [newUserAllocation, setNewUserAllocation] = useState('');

  useEffect(() => {
    if (isConnected && address) {
      // 模拟管理员权限检查
      setIsAdmin(address.toLowerCase().includes('admin') || Math.random() > 0.7);
      
      // 模拟众筹数据
      setCrowdsales([
        {
          address: '0x1234567890123456789012345678901234567890',
          name: 'DeFi Token Sale',
          status: 'active',
          raised: '150.5',
          target: '500.0',
          participants: 234,
          endTime: Date.now() + 86400000 * 7
        },
        {
          address: '0x9876543210987654321098765432109876543210',
          name: 'GameFi Project',
          status: 'paused',
          raised: '89.2',
          target: '200.0',
          participants: 156,
          endTime: Date.now() + 86400000 * 14
        }
      ]);

      // 模拟白名单用户数据
      setWhitelistUsers([
        {
          address: '0x1111222233334444555566667777888899990000',
          tier: 'VIP',
          allocation: '10.0',
          used: '2.5',
          addedDate: Date.now() - 86400000 * 3
        },
        {
          address: '0x2222333344445555666677778888999900001111',
          tier: 'WHITELISTED',
          allocation: '5.0',
          used: '1.0',
          addedDate: Date.now() - 86400000 * 5
        }
      ]);
    }
  }, [isConnected, address]);

  const handlePauseCrowdsale = async (crowdsaleAddress: string) => {
    // 实际应用中调用合约方法
    setCrowdsales(prev => prev.map(cs => 
      cs.address === crowdsaleAddress 
        ? { ...cs, status: cs.status === 'active' ? 'paused' : 'active' }
        : cs
    ));
  };

  const handleFinalizeCrowdsale = async (crowdsaleAddress: string) => {
    // 实际应用中调用合约方法
    setCrowdsales(prev => prev.map(cs => 
      cs.address === crowdsaleAddress 
        ? { ...cs, status: 'finalized' }
        : cs
    ));
  };

  const handleAddWhitelistUser = async () => {
    if (!newUserAddress || !newUserAllocation) return;

    const newUser: WhitelistUser = {
      address: newUserAddress,
      tier: newUserTier,
      allocation: newUserAllocation,
      used: '0',
      addedDate: Date.now()
    };

    setWhitelistUsers(prev => [...prev, newUser]);
    setNewUserAddress('');
    setNewUserAllocation('');
  };

  const handleRemoveWhitelistUser = async (userAddress: string) => {
    setWhitelistUsers(prev => prev.filter(user => user.address !== userAddress));
  };

  if (!isConnected) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className="max-w-md mx-auto">
          <CardContent className="p-8 text-center">
            <CogIcon className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
              连接钱包访问管理面板
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              需要管理员权限才能访问此页面
            </p>
            <Button variant="primary" size="lg">
              连接钱包
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className="max-w-md mx-auto">
          <CardContent className="p-8 text-center">
            <ExclamationTriangleIcon className="h-16 w-16 text-red-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
              访问被拒绝
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              您没有管理员权限访问此页面
            </p>
            <Button variant="secondary" onClick={() => window.history.back()}>
              返回
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
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white flex items-center">
          <CogIcon className="h-8 w-8 mr-3" />
          管理员控制面板
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-2">
          管理众筹项目和白名单用户
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* 众筹管理 */}
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white flex items-center">
                  <ChartBarIcon className="h-5 w-5 mr-2" />
                  众筹项目管理
                </h3>
                <Button variant="primary" size="sm">
                  <PlusIcon className="h-4 w-4 mr-2" />
                  创建众筹
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {crowdsales.map((crowdsale, index) => (
                  <div
                    key={index}
                    className="border border-gray-200 dark:border-gray-700 rounded-lg p-4"
                  >
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <h4 className="font-medium text-gray-900 dark:text-white">
                          {crowdsale.name}
                        </h4>
                        <p className="text-sm text-gray-500 dark:text-gray-400 font-mono">
                          {crowdsale.address.slice(0, 10)}...{crowdsale.address.slice(-8)}
                        </p>
                      </div>
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        crowdsale.status === 'active' 
                          ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                          : crowdsale.status === 'paused'
                          ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                          : 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200'
                      }`}>
                        {crowdsale.status === 'active' ? '进行中' : 
                         crowdsale.status === 'paused' ? '已暂停' : '已结束'}
                      </span>
                    </div>

                    <div className="grid grid-cols-3 gap-4 mb-4">
                      <div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">已筹集</p>
                        <p className="font-semibold text-gray-900 dark:text-white">
                          {crowdsale.raised} ETH
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">目标</p>
                        <p className="font-semibold text-gray-900 dark:text-white">
                          {crowdsale.target} ETH
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">参与者</p>
                        <p className="font-semibold text-gray-900 dark:text-white">
                          {crowdsale.participants}
                        </p>
                      </div>
                    </div>

                    <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 mb-4">
                      <div
                        className="bg-blue-600 h-2 rounded-full"
                        style={{
                          width: `${Math.min((parseFloat(crowdsale.raised) / parseFloat(crowdsale.target)) * 100, 100)}%`
                        }}
                      />
                    </div>

                    <div className="flex space-x-2">
                      {crowdsale.status !== 'finalized' && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handlePauseCrowdsale(crowdsale.address)}
                        >
                          {crowdsale.status === 'active' ? (
                            <>
                              <PauseIcon className="h-4 w-4 mr-1" />
                              暂停
                            </>
                          ) : (
                            <>
                              <PlayIcon className="h-4 w-4 mr-1" />
                              恢复
                            </>
                          )}
                        </Button>
                      )}
                      
                      {crowdsale.status !== 'finalized' && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleFinalizeCrowdsale(crowdsale.address)}
                          className="text-red-600 hover:text-red-700"
                        >
                          结束众筹
                        </Button>
                      )}
                      
                      <Button variant="ghost" size="sm">
                        <PencilIcon className="h-4 w-4 mr-1" />
                        编辑
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* 系统统计 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                系统统计
              </h3>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-4">
                <div className="text-center p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                  <p className="text-2xl font-bold text-blue-600">
                    {crowdsales.length}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    总众筹项目
                  </p>
                </div>
                <div className="text-center p-4 bg-green-50 dark:bg-green-900/20 rounded-lg">
                  <p className="text-2xl font-bold text-green-600">
                    {crowdsales.reduce((sum, cs) => sum + cs.participants, 0)}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    总参与者
                  </p>
                </div>
                <div className="text-center p-4 bg-purple-50 dark:bg-purple-900/20 rounded-lg">
                  <p className="text-2xl font-bold text-purple-600">
                    {crowdsales.reduce((sum, cs) => sum + parseFloat(cs.raised), 0).toFixed(1)}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    总筹集 (ETH)
                  </p>
                </div>
                <div className="text-center p-4 bg-orange-50 dark:bg-orange-900/20 rounded-lg">
                  <p className="text-2xl font-bold text-orange-600">
                    {whitelistUsers.length}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    白名单用户
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 白名单管理 */}
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white flex items-center">
                <UserGroupIcon className="h-5 w-5 mr-2" />
                白名单管理
              </h3>
            </CardHeader>
            <CardContent>
              {/* 添加用户表单 */}
              <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 mb-6">
                <h4 className="font-medium text-gray-900 dark:text-white mb-3">
                  添加白名单用户
                </h4>
                <div className="space-y-3">
                  <input
                    type="text"
                    placeholder="用户地址 (0x...)"
                    value={newUserAddress}
                    onChange={(e) => setNewUserAddress(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  />
                  <div className="flex space-x-3">
                    <select
                      value={newUserTier}
                      onChange={(e) => setNewUserTier(e.target.value as 'VIP' | 'WHITELISTED')}
                      className="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                    >
                      <option value="WHITELISTED">白名单用户</option>
                      <option value="VIP">VIP用户</option>
                    </select>
                    <input
                      type="number"
                      placeholder="配额 (ETH)"
                      value={newUserAllocation}
                      onChange={(e) => setNewUserAllocation(e.target.value)}
                      className="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                    />
                  </div>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={handleAddWhitelistUser}
                    className="w-full"
                  >
                    <PlusIcon className="h-4 w-4 mr-2" />
                    添加用户
                  </Button>
                </div>
              </div>

              {/* 用户列表 */}
              <div className="space-y-3">
                {whitelistUsers.map((user, index) => (
                  <div
                    key={index}
                    className="flex items-center justify-between p-3 border border-gray-200 dark:border-gray-700 rounded-lg"
                  >
                    <div className="flex-1">
                      <div className="flex items-center space-x-2">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                          user.tier === 'VIP' 
                            ? 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200'
                            : 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                        }`}>
                          {user.tier === 'VIP' ? 'VIP' : '白名单'}
                        </span>
                        <p className="font-mono text-sm text-gray-900 dark:text-white">
                          {user.address.slice(0, 8)}...{user.address.slice(-6)}
                        </p>
                      </div>
                      <div className="flex items-center space-x-4 mt-1">
                        <span className="text-xs text-gray-500 dark:text-gray-400">
                          配额: {user.allocation} ETH
                        </span>
                        <span className="text-xs text-gray-500 dark:text-gray-400">
                          已用: {user.used} ETH
                        </span>
                        <span className="text-xs text-gray-500 dark:text-gray-400">
                          添加: {new Date(user.addedDate).toLocaleDateString()}
                        </span>
                      </div>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleRemoveWhitelistUser(user.address)}
                      className="text-red-600 hover:text-red-700"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </Button>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* 快速操作 */}
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                快速操作
              </h3>
            </CardHeader>
            <CardContent className="space-y-3">
              <Button variant="secondary" className="w-full">
                导出白名单用户
              </Button>
              <Button variant="secondary" className="w-full">
                批量导入白名单
              </Button>
              <Button variant="secondary" className="w-full">
                生成众筹报告
              </Button>
              <Button variant="ghost" className="w-full text-red-600 hover:text-red-700">
                紧急暂停所有众筹
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};
