import React, { useState, useEffect } from 'react';
import { useWallet } from '@/hooks/useWallet';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { formatEther, formatTokenAmount } from '@/utils/formatters';
import { 
  MagnifyingGlassIcon,
  FunnelIcon,
  ArrowTopRightOnSquareIcon,
  CheckCircleIcon,
  ClockIcon,
  XCircleIcon,
  ArrowDownIcon,
  ArrowUpIcon
} from '@heroicons/react/24/outline';

interface Transaction {
  hash: string;
  type: 'purchase' | 'refund' | 'claim' | 'transfer';
  status: 'pending' | 'confirmed' | 'failed';
  timestamp: number;
  amount: string;
  tokenAmount?: string;
  crowdsaleName?: string;
  crowdsaleAddress?: string;
  gasUsed?: string;
  gasPrice?: string;
}

export const TransactionHistory: React.FC = () => {
  const { isConnected, address } = useWallet();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (isConnected && address) {
      setIsLoading(true);
      // 模拟交易数据加载
      setTimeout(() => {
        const mockTransactions: Transaction[] = [
          {
            hash: '0x1234567890abcdef1234567890abcdef12345678',
            type: 'purchase',
            status: 'confirmed',
            timestamp: Date.now() - 86400000,
            amount: '2.5',
            tokenAmount: '5000',
            crowdsaleName: 'DeFi Token Sale',
            crowdsaleAddress: '0x1234...5678',
            gasUsed: '150000',
            gasPrice: '20'
          },
          {
            hash: '0xabcdef1234567890abcdef1234567890abcdef12',
            type: 'purchase',
            status: 'confirmed',
            timestamp: Date.now() - 172800000,
            amount: '1.0',
            tokenAmount: '2000',
            crowdsaleName: 'GameFi Project',
            crowdsaleAddress: '0x9876...5432',
            gasUsed: '120000',
            gasPrice: '25'
          },
          {
            hash: '0x567890abcdef1234567890abcdef1234567890ab',
            type: 'claim',
            status: 'confirmed',
            timestamp: Date.now() - 259200000,
            amount: '0',
            tokenAmount: '1000',
            crowdsaleName: 'DeFi Token Sale',
            gasUsed: '80000',
            gasPrice: '18'
          },
          {
            hash: '0x890abcdef1234567890abcdef1234567890abcd',
            type: 'purchase',
            status: 'pending',
            timestamp: Date.now() - 3600000,
            amount: '0.5',
            tokenAmount: '1000',
            crowdsaleName: 'AI Token Launch',
            crowdsaleAddress: '0x5555...7777',
            gasUsed: '140000',
            gasPrice: '30'
          }
        ];
        setTransactions(mockTransactions);
        setFilteredTransactions(mockTransactions);
        setIsLoading(false);
      }, 1000);
    }
  }, [isConnected, address]);

  useEffect(() => {
    let filtered = transactions;

    // 按类型过滤
    if (filterType !== 'all') {
      filtered = filtered.filter(tx => tx.type === filterType);
    }

    // 按状态过滤
    if (filterStatus !== 'all') {
      filtered = filtered.filter(tx => tx.status === filterStatus);
    }

    // 搜索过滤
    if (searchTerm) {
      filtered = filtered.filter(tx => 
        tx.hash.toLowerCase().includes(searchTerm.toLowerCase()) ||
        tx.crowdsaleName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        tx.crowdsaleAddress?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    setFilteredTransactions(filtered);
  }, [transactions, filterType, filterStatus, searchTerm]);

  const getTransactionIcon = (type: string, status: string) => {
    if (status === 'pending') {
      return <ClockIcon className="h-5 w-5 text-yellow-500" />;
    }
    if (status === 'failed') {
      return <XCircleIcon className="h-5 w-5 text-red-500" />;
    }

    switch (type) {
      case 'purchase':
        return <ArrowDownIcon className="h-5 w-5 text-blue-500" />;
      case 'refund':
        return <ArrowUpIcon className="h-5 w-5 text-orange-500" />;
      case 'claim':
        return <CheckCircleIcon className="h-5 w-5 text-green-500" />;
      case 'transfer':
        return <ArrowTopRightOnSquareIcon className="h-5 w-5 text-purple-500" />;
      default:
        return <CheckCircleIcon className="h-5 w-5 text-gray-500" />;
    }
  };

  const getTransactionTypeLabel = (type: string) => {
    switch (type) {
      case 'purchase': return '购买代币';
      case 'refund': return '退款';
      case 'claim': return '领取代币';
      case 'transfer': return '转账';
      default: return '未知';
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'pending': return '待确认';
      case 'confirmed': return '已确认';
      case 'failed': return '失败';
      default: return '未知';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending': return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200';
      case 'confirmed': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
      case 'failed': return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
    }
  };

  if (!isConnected) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className="max-w-md mx-auto">
          <CardContent className="p-8 text-center">
            <ClockIcon className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
              连接钱包查看交易历史
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              连接您的钱包以查看所有交易记录
            </p>
            <Button variant="primary" size="lg">
              连接钱包
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
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
          交易历史
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-2">
          查看您的所有交易记录和状态
        </p>
      </div>

      {/* 搜索和过滤器 */}
      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
            {/* 搜索框 */}
            <div className="flex-1">
              <div className="relative">
                <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="搜索交易哈希、项目名称或地址..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
                />
              </div>
            </div>

            {/* 类型过滤器 */}
            <div className="flex items-center space-x-2">
              <FunnelIcon className="h-5 w-5 text-gray-400" />
              <select
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              >
                <option value="all">所有类型</option>
                <option value="purchase">购买</option>
                <option value="refund">退款</option>
                <option value="claim">领取</option>
                <option value="transfer">转账</option>
              </select>
            </div>

            {/* 状态过滤器 */}
            <div>
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              >
                <option value="all">所有状态</option>
                <option value="pending">待确认</option>
                <option value="confirmed">已确认</option>
                <option value="failed">失败</option>
              </select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 交易列表 */}
      <Card>
        <CardHeader>
          <div className="flex justify-between items-center">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
              交易记录 ({filteredTransactions.length})
            </h3>
            <Button variant="ghost" size="sm">
              导出CSV
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <span className="ml-3 text-gray-600 dark:text-gray-400">加载中...</span>
            </div>
          ) : filteredTransactions.length === 0 ? (
            <div className="text-center py-12">
              <ClockIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 dark:text-gray-400">
                {searchTerm || filterType !== 'all' || filterStatus !== 'all' 
                  ? '没有找到匹配的交易记录' 
                  : '暂无交易记录'}
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {filteredTransactions.map((tx, index) => (
                <div
                  key={index}
                  className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                >
                  <div className="flex items-center space-x-4">
                    {getTransactionIcon(tx.type, tx.status)}
                    <div>
                      <div className="flex items-center space-x-2">
                        <p className="font-medium text-gray-900 dark:text-white">
                          {getTransactionTypeLabel(tx.type)}
                        </p>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(tx.status)}`}>
                          {getStatusLabel(tx.status)}
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">
                        {tx.crowdsaleName && `${tx.crowdsaleName} • `}
                        {new Date(tx.timestamp).toLocaleString()}
                      </p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 font-mono">
                        {tx.hash.slice(0, 10)}...{tx.hash.slice(-8)}
                      </p>
                    </div>
                  </div>

                  <div className="text-right">
                    {tx.amount !== '0' && (
                      <p className="font-semibold text-gray-900 dark:text-white">
                        {tx.type === 'refund' ? '+' : '-'}{tx.amount} ETH
                      </p>
                    )}
                    {tx.tokenAmount && (
                      <p className="text-sm text-gray-600 dark:text-gray-400">
                        {tx.type === 'claim' ? '+' : ''}{formatTokenAmount(tx.tokenAmount)} 代币
                      </p>
                    )}
                    {tx.gasUsed && (
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        Gas: {tx.gasUsed} ({tx.gasPrice} gwei)
                      </p>
                    )}
                  </div>

                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => window.open(`https://etherscan.io/tx/${tx.hash}`, '_blank')}
                  >
                    <ArrowTopRightOnSquareIcon className="h-4 w-4" />
                  </Button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* 分页（如果需要） */}
      {filteredTransactions.length > 10 && (
        <div className="mt-6 flex justify-center">
          <div className="flex space-x-2">
            <Button variant="ghost" size="sm" disabled>
              上一页
            </Button>
            <Button variant="ghost" size="sm" className="bg-blue-50 dark:bg-blue-900 text-blue-600 dark:text-blue-400">
              1
            </Button>
            <Button variant="ghost" size="sm">
              2
            </Button>
            <Button variant="ghost" size="sm">
              下一页
            </Button>
          </div>
        </div>
      )}
    </div>
  );
};
