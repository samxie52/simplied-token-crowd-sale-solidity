import React, { useState } from 'react';
import { useWallet } from '@/hooks/useWallet';
import { useAdminAuth } from '@/hooks/useAdminAuth';
import { useCrowdsaleManagement } from '@/hooks/useCrowdsaleManagement';
import { useWhitelistManagement } from '@/hooks/useWhitelistManagement';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { handleContractError } from '@/utils/errorHandler';
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

// 接口定义移到Hook文件中

export const AdminPanel: React.FC = () => {
  const { isConnected } = useWallet();
  const { isAdmin, isOperator, loading: authLoading, error: authError } = useAdminAuth();
  const { 
    crowdsales, 
    pauseCrowdsale,
    resumeCrowdsale,
    finalizeCrowdsale
  } = useCrowdsaleManagement();
  const {
    users: whitelistUsers,
    addWhitelistUser,
    removeWhitelistUser
  } = useWhitelistManagement();
  
  const [newUserAddress, setNewUserAddress] = useState('');
  const [newUserTier, setNewUserTier] = useState<'VIP' | 'WHITELISTED'>('WHITELISTED');
  const [operationLoading, setOperationLoading] = useState(false);
  const [operationError, setOperationError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [showBatchImport, setShowBatchImport] = useState(false);
  const [batchImportText, setBatchImportText] = useState('');

  // 清除消息的函数
  const clearMessages = () => {
    setOperationError(null);
    setSuccessMessage(null);
  };

  // 显示成功消息
  const showSuccess = (message: string) => {
    setSuccessMessage(message);
    setTimeout(() => setSuccessMessage(null), 5000);
  };

  // 显示错误消息
  const showError = (message: string) => {
    setOperationError(message);
    setTimeout(() => setOperationError(null), 8000);
  };

  const handlePauseCrowdsale = async (crowdsaleAddress: string) => {
    setOperationLoading(true);
    clearMessages();
    
    try {
      const crowdsale = crowdsales.find(cs => cs.address === crowdsaleAddress);
      if (!crowdsale) return;
      
      if (crowdsale.isPaused) {
        const result = await resumeCrowdsale(crowdsaleAddress);
        showSuccess(`众筹已恢复 - 交易哈希: ${result.txHash}`);
      } else {
        const result = await pauseCrowdsale(crowdsaleAddress);
        showSuccess(`众筹已暂停 - 交易哈希: ${result.txHash}`);
      }
    } catch (error) {
      showError(handleContractError(error));
    } finally {
      setOperationLoading(false);
    }
  };

  const handleFinalizeCrowdsale = async (crowdsaleAddress: string) => {
    setOperationLoading(true);
    clearMessages();
    
    try {
      const result = await finalizeCrowdsale(crowdsaleAddress);
      showSuccess(`众筹已结束 - 交易哈希: ${result.txHash}`);
    } catch (error) {
      showError(handleContractError(error));
    } finally {
      setOperationLoading(false);
    }
  };

  const handleAddWhitelistUser = async () => {
    if (!newUserAddress.trim()) {
      showError('请输入有效的用户地址');
      return;
    }

    setOperationLoading(true);
    clearMessages();
    
    try {
      const result = await addWhitelistUser({ 
        address: newUserAddress.trim(), 
        tier: newUserTier 
      });
      showSuccess(`用户已添加到白名单 - 交易哈希: ${result.txHash}`);
      setNewUserAddress('');
    } catch (error) {
      showError(handleContractError(error));
    } finally {
      setOperationLoading(false);
    }
  };

  const handleRemoveWhitelistUser = async (userAddress: string) => {
    setOperationLoading(true);
    clearMessages();
    
    try {
      const result = await removeWhitelistUser(userAddress);
      showSuccess(`用户已从白名单移除 - 交易哈希: ${result.txHash}`);
    } catch (error) {
      showError(handleContractError(error));
    } finally {
      setOperationLoading(false);
    }
  };

  const handleBatchImport = async () => {
    if (!batchImportText.trim()) {
      showError('请输入批量导入数据');
      return;
    }

    setOperationLoading(true);
    clearMessages();

    try {
      // 解析批量导入文本
      const lines = batchImportText.trim().split('\n');
      const users: Array<{ address: string; tier: 'VIP' | 'WHITELISTED' }> = [];
      
      for (const line of lines) {
        const trimmedLine = line.trim();
        if (!trimmedLine) continue;
        
        const parts = trimmedLine.split(',').map(p => p.trim());
        if (parts.length < 1) continue;
        
        const address = parts[0];
        const tier = parts[1]?.toUpperCase() === 'VIP' ? 'VIP' : 'WHITELISTED';
        
        // 验证地址格式
        if (!address.startsWith('0x') || address.length !== 42) {
          showError(`无效的地址格式: ${address}`);
          return;
        }
        
        users.push({ address, tier });
      }

      if (users.length === 0) {
        showError('没有找到有效的用户数据');
        return;
      }

      // 逐个添加用户
      let successCount = 0;
      let errorCount = 0;
      
      for (const user of users) {
        try {
          await addWhitelistUser(user);
          successCount++;
        } catch (error) {
          console.error(`Failed to add user ${user.address}:`, error);
          errorCount++;
        }
      }

      if (successCount > 0) {
        showSuccess(`批量导入完成: ${successCount} 个用户成功添加${errorCount > 0 ? `, ${errorCount} 个失败` : ''}`);
      } else {
        showError('批量导入失败，没有用户被添加');
      }
      
      setBatchImportText('');
      setShowBatchImport(false);
    } catch (error) {
      showError(handleContractError(error));
    } finally {
      setOperationLoading(false);
    }
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

  if (authLoading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className="max-w-md mx-auto">
          <CardContent className="p-8 text-center">
            <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
              验证权限中...
            </h2>
            <p className="text-gray-600 dark:text-gray-400">
              正在检查管理员权限
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!isAdmin && !isOperator) {
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
            {authError && (
              <p className="text-red-600 text-sm mb-4">
                错误: {authError}
              </p>
            )}
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

      {/* 状态消息 */}
      {successMessage && (
        <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
          <p className="text-green-800">{successMessage}</p>
        </div>
      )}
      
      {operationError && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-red-800">{operationError}</p>
        </div>
      )}

      {/* 批量导入模态框 */}
      {showBatchImport && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-2xl mx-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                批量导入白名单用户
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setShowBatchImport(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                ✕
              </Button>
            </div>
            
            <div className="mb-4">
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
                请输入用户地址，每行一个。格式：地址,层级（可选，默认为WHITELISTED）
              </p>
              <p className="text-xs text-gray-500 dark:text-gray-500 mb-3">
                示例：<br/>
                0x1234567890123456789012345678901234567890,VIP<br/>
                0x0987654321098765432109876543210987654321,WHITELISTED<br/>
                0x1111111111111111111111111111111111111111
              </p>
              <textarea
                value={batchImportText}
                onChange={(e) => setBatchImportText(e.target.value)}
                placeholder="0x1234567890123456789012345678901234567890,VIP
0x0987654321098765432109876543210987654321,WHITELISTED
0x1111111111111111111111111111111111111111"
                className="w-full h-32 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-700 text-gray-900 dark:text-white resize-none"
              />
            </div>
            
            <div className="flex space-x-3">
              <Button
                variant="primary"
                onClick={handleBatchImport}
                disabled={operationLoading || !batchImportText.trim()}
                className="flex-1"
              >
                {operationLoading ? '导入中...' : '开始导入'}
              </Button>
              <Button
                variant="secondary"
                onClick={() => setShowBatchImport(false)}
                disabled={operationLoading}
              >
                取消
              </Button>
            </div>
          </div>
        </div>
      )}

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
                          disabled={operationLoading}
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
                          disabled={operationLoading}
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
                  </div>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={handleAddWhitelistUser}
                    className="w-full"
                    disabled={operationLoading}
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
                      disabled={operationLoading}
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
              <Button 
                variant="secondary" 
                className="w-full"
                onClick={() => setShowBatchImport(true)}
                disabled={operationLoading}
              >
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
