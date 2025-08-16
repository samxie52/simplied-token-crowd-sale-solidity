import React, { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { 
  MagnifyingGlassIcon,
  FunnelIcon,
  ArrowTopRightOnSquareIcon,
  CheckCircleIcon,
  ClockIcon,
  XCircleIcon,
  ArrowDownIcon,
  ArrowUpIcon,
  ArrowPathIcon
} from '@heroicons/react/24/outline';
import { useTransactionHistory } from '../hooks/useTransactionHistory';
import { 
  TransactionType,
  TransactionStatus
} from '../types/transactionTypes';
import {
  getTransactionTypeLabel,
  getTransactionStatusLabel,
  getTransactionStatusColor,
  getTransactionTypeColor,
  formatTimestamp,
  formatAddress,
  formatTransactionHash,
  formatTransactionAmount,
  getTransactionExplorerUrl,
  calculateGasFee
} from '../utils/transactionUtils';

export const TransactionHistory: React.FC = () => {
  const { isConnected } = useAccount();
  const {
    paginatedTransactions,
    isLoading,
    error,
    searchQuery,
    pagination,
    setFilter,
    setSearchQuery,
    setCurrentPage,
    refreshTransactions,
    clearFilter,
    clearSearch
  } = useTransactionHistory();
  
  const [filterType, setFilterType] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [showFilters, setShowFilters] = useState(false);

  // 处理过滤器变化
  useEffect(() => {
    if (filterType !== 'all') {
      const types = filterType === 'purchase' ? [TransactionType.TOKEN_PURCHASE] :
                   filterType === 'refund' ? [TransactionType.REFUND] :
                   filterType === 'release' ? [TransactionType.TOKEN_RELEASE] :
                   filterType === 'whitelist' ? [TransactionType.WHITELIST_ADD, TransactionType.WHITELIST_REMOVE] :
                   [];
      setFilter({ types });
    } else {
      setFilter({});
    }
  }, [filterType, setFilter]);

  useEffect(() => {
    if (filterStatus !== 'all') {
      const status = filterStatus === 'success' ? [TransactionStatus.SUCCESS] :
                    filterStatus === 'pending' ? [TransactionStatus.PENDING] :
                    filterStatus === 'failed' ? [TransactionStatus.FAILED] :
                    [];
      setFilter({ status });
    } else {
      setFilter({ status: [] });
    }
  }, [filterStatus, setFilter]);

  const getTransactionIcon = (type: TransactionType, status: TransactionStatus) => {
    if (status === TransactionStatus.PENDING) {
      return <ClockIcon className="h-5 w-5 text-yellow-500" />;
    }
    if (status === TransactionStatus.FAILED) {
      return <XCircleIcon className="h-5 w-5 text-red-500" />;
    }

    switch (type) {
      case TransactionType.TOKEN_PURCHASE:
        return <ArrowDownIcon className="h-5 w-5 text-blue-500" />;
      case TransactionType.REFUND:
        return <ArrowUpIcon className="h-5 w-5 text-orange-500" />;
      case TransactionType.TOKEN_RELEASE:
        return <CheckCircleIcon className="h-5 w-5 text-green-500" />;
      default:
        return <CheckCircleIcon className="h-5 w-5 text-gray-500" />;
    }
  };

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-4">交易历史</h1>
          <p className="text-gray-600">请先连接钱包查看交易历史</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">交易历史</h1>
        <p className="text-gray-600">查看您的所有交易记录</p>
      </div>

      {/* 搜索和过滤 */}
      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="flex flex-col sm:flex-row gap-4">
            {/* 搜索框 */}
            <div className="flex-1">
              <div className="relative">
                <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="搜索交易哈希、地址..."
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>
            </div>

            {/* 过滤按钮 */}
            <Button
              variant="outline"
              onClick={() => setShowFilters(!showFilters)}
              className="flex items-center gap-2"
            >
              <FunnelIcon className="h-4 w-4" />
              过滤
            </Button>

            {/* 刷新按钮 */}
            <Button
              variant="outline"
              onClick={refreshTransactions}
              className="flex items-center gap-2"
            >
              <ArrowPathIcon className="h-4 w-4" />
              刷新
            </Button>
          </div>

          {/* 过滤选项 */}
          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    交易类型
                  </label>
                  <select
                    className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    value={filterType}
                    onChange={(e) => setFilterType(e.target.value)}
                  >
                    <option value="all">全部类型</option>
                    <option value="purchase">代币购买</option>
                    <option value="refund">退款</option>
                    <option value="release">代币释放</option>
                    <option value="whitelist">白名单管理</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    交易状态
                  </label>
                  <select
                    className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    value={filterStatus}
                    onChange={(e) => setFilterStatus(e.target.value)}
                  >
                    <option value="all">全部状态</option>
                    <option value="success">成功</option>
                    <option value="pending">待确认</option>
                    <option value="failed">失败</option>
                  </select>
                </div>
              </div>

              <div className="mt-4 flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={clearFilter}
                >
                  清除过滤
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={clearSearch}
                >
                  清除搜索
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* 错误提示 */}
      {error && (
        <Card className="mb-6 border-red-200 bg-red-50">
          <CardContent className="p-4">
            <div className="flex items-center gap-2 text-red-600">
              <XCircleIcon className="h-5 w-5" />
              <span>{error}</span>
            </div>
          </CardContent>
        </Card>
      )}

      {/* 交易列表 */}
      <Card>
        <CardHeader>
          <div className="flex justify-between items-center">
            <h2 className="text-xl font-semibold">交易记录</h2>
            <div className="text-sm text-gray-500">
              共 {pagination.totalItems} 条记录，第 {pagination.currentPage} / {pagination.totalPages} 页
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto"></div>
              <p className="mt-2 text-gray-600">加载交易数据...</p>
            </div>
          ) : paginatedTransactions.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-gray-600">
                {searchQuery ? '没有找到匹配的交易记录' : '暂无交易记录'}
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {paginatedTransactions.map((tx, index) => (
                <div
                  key={`${tx.hash}-${index}`}
                  className="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div className="flex items-start space-x-3">
                      <div className="flex-shrink-0 mt-1">
                        {getTransactionIcon(tx.type, tx.status)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center space-x-2 mb-1">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getTransactionTypeColor(tx.type)}`}>
                            {getTransactionTypeLabel(tx.type)}
                          </span>
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getTransactionStatusColor(tx.status)}`}>
                            {getTransactionStatusLabel(tx.status)}
                          </span>
                        </div>
                        
                        <div className="text-sm text-gray-600 space-y-1">
                          <div>交易哈希: {formatTransactionHash(tx.hash)}</div>
                          <div>时间: {formatTimestamp(tx.timestamp)}</div>
                          <div>从: {formatAddress(tx.from)}</div>
                          <div>到: {formatAddress(tx.to)}</div>
                          {tx.gasUsed && tx.gasPrice && (
                            <div>Gas费用: {calculateGasFee(tx.gasUsed, tx.gasPrice)} ETH</div>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="text-right">
                      {tx.type === TransactionType.TOKEN_PURCHASE && (
                        <div>
                          <div className="text-lg font-semibold text-gray-900">
                            {formatTransactionAmount((tx as any).weiAmount)} ETH
                          </div>
                          <div className="text-sm text-gray-600">
                            {formatTransactionAmount((tx as any).tokenAmount)} 代币
                          </div>
                        </div>
                      )}
                      {tx.type === TransactionType.REFUND && (
                        <div className="text-lg font-semibold text-orange-600">
                          {formatTransactionAmount((tx as any).amount)} ETH
                        </div>
                      )}
                      {tx.type === TransactionType.TOKEN_RELEASE && (
                        <div className="text-lg font-semibold text-green-600">
                          {formatTransactionAmount((tx as any).amount)} 代币
                        </div>
                      )}
                      
                      <div className="mt-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => window.open(getTransactionExplorerUrl(tx.hash), '_blank')}
                          className="flex items-center gap-1"
                        >
                          <ArrowTopRightOnSquareIcon className="h-3 w-3" />
                          查看详情
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* 分页 */}
      {pagination.totalPages > 1 && (
        <div className="mt-6 flex justify-center">
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCurrentPage(pagination.currentPage - 1)}
              disabled={pagination.currentPage <= 1}
            >
              上一页
            </Button>
            <span className="text-sm text-gray-600">
              第 {pagination.currentPage} / {pagination.totalPages} 页
            </span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCurrentPage(pagination.currentPage + 1)}
              disabled={pagination.currentPage >= pagination.totalPages}
            >
              下一页
            </Button>
          </div>
        </div>
      )}
    </div>
  );
};
