import { useState, useEffect, useCallback } from 'react';
import { useAccount } from 'wagmi';
import { 
  Transaction, 
  TransactionFilter, 
  PaginationInfo 
} from '../types/transactionTypes';
import { TransactionEventListener } from '../utils/eventListeners-simple';
import { 
  filterTransactions, 
  sortTransactionsByTimestamp,
  searchTransactions,
  paginateTransactions 
} from '../utils/transactionUtils';

export interface UseTransactionHistoryReturn {
  transactions: Transaction[];
  filteredTransactions: Transaction[];
  paginatedTransactions: Transaction[];
  isLoading: boolean;
  error: string | null;
  filter: Partial<TransactionFilter>;
  searchQuery: string;
  pagination: PaginationInfo;
  
  // Actions
  setFilter: (filter: Partial<TransactionFilter>) => void;
  setSearchQuery: (query: string) => void;
  setCurrentPage: (page: number) => void;
  setPageSize: (size: number) => void;
  refreshTransactions: () => Promise<void>;
  clearFilter: () => void;
  clearSearch: () => void;
}

const DEFAULT_PAGE_SIZE = 20;

export const useTransactionHistory = (): UseTransactionHistoryReturn => {
  const { address, isConnected } = useAccount();
  
  // State
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [paginatedTransactions, setPaginatedTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Partial<TransactionFilter>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE);
  const [eventListener, setEventListener] = useState<TransactionEventListener | null>(null);

  // 计算分页信息
  const totalItems = filteredTransactions.length;
  const totalPages = Math.ceil(totalItems / pageSize);
  
  const pagination: PaginationInfo = {
    currentPage,
    totalPages,
    pageSize,
    totalItems
  };

  // 获取历史交易数据
  const fetchTransactions = useCallback(async () => {
    if (!eventListener || !isConnected) return;

    setIsLoading(true);
    setError(null);

    try {
      const historicalTransactions = await eventListener.getHistoricalTransactions();
      setTransactions(historicalTransactions);
    } catch (err) {
      console.error('Error fetching transactions:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch transactions');
    } finally {
      setIsLoading(false);
    }
  }, [eventListener, isConnected]);

  // 初始化事件监听器
  useEffect(() => {
    if (isConnected && address) {
      const eventListener = new TransactionEventListener();
      setEventListener(eventListener);
      
      // Start real-time listening
      eventListener.startListening((newTransactions: Transaction[]) => {
        setTransactions(prev => {
          const updated = [...newTransactions, ...prev];
          return sortTransactionsByTimestamp(updated);
        });
      });

      // Initial load
      fetchTransactions();

      return () => {
        if (eventListener) {
          eventListener.stopListening();
        }
      };
    } else {
      setTransactions([]);
      setIsLoading(false);
      setError(null);
    }
  }, [isConnected, address, fetchTransactions]);

  // 初始加载交易数据
  useEffect(() => {
    if (eventListener && isConnected) {
      fetchTransactions();
    }
  }, [eventListener, isConnected, fetchTransactions]);

  // 应用过滤和搜索
  useEffect(() => {
    let result = [...transactions];

    // 应用过滤器
    if (Object.keys(filter).length > 0) {
      result = filterTransactions(result, filter);
    }

    // 应用搜索
    if (searchQuery.trim()) {
      result = searchTransactions(result, searchQuery);
    }

    setFilteredTransactions(result);
    setCurrentPage(1); // 重置到第一页
  }, [transactions, filter, searchQuery]);

  // 应用分页
  useEffect(() => {
    const paginated = paginateTransactions(filteredTransactions, currentPage, pageSize);
    setPaginatedTransactions(paginated);
  }, [filteredTransactions, currentPage, pageSize]);

  // Actions
  const refreshTransactions = useCallback(async () => {
    await fetchTransactions();
  }, [fetchTransactions]);

  const clearFilter = useCallback(() => {
    setFilter({});
    setCurrentPage(1);
  }, []);

  const clearSearch = useCallback(() => {
    setSearchQuery('');
    setCurrentPage(1);
  }, []);

  const handleSetFilter = useCallback((newFilter: Partial<TransactionFilter>) => {
    setFilter(prev => ({ ...prev, ...newFilter }));
  }, []);

  const handleSetCurrentPage = useCallback((page: number) => {
    if (page >= 1 && page <= totalPages) {
      setCurrentPage(page);
    }
  }, [totalPages]);

  const handleSetPageSize = useCallback((size: number) => {
    if (size > 0) {
      setPageSize(size);
      setCurrentPage(1); // 重置到第一页
    }
  }, []);

  return {
    transactions,
    filteredTransactions,
    paginatedTransactions,
    isLoading,
    error,
    filter,
    searchQuery,
    pagination,
    
    setFilter: handleSetFilter,
    setSearchQuery,
    setCurrentPage: handleSetCurrentPage,
    setPageSize: handleSetPageSize,
    refreshTransactions,
    clearFilter,
    clearSearch
  };
};
