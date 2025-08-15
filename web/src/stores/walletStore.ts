import { create } from 'zustand';
import { WalletState, Transaction, WalletError } from '@/types/wallet';

interface WalletStore extends WalletState {
  // Actions
  setAddress: (address: string | null) => void;
  setChainId: (chainId: number | null) => void;
  setConnected: (isConnected: boolean) => void;
  setConnecting: (isConnecting: boolean) => void;
  setBalance: (balance: string) => void;
  setEnsName: (ensName: string | undefined) => void;
  
  // Transaction management
  transactions: Transaction[];
  addTransaction: (transaction: Omit<Transaction, 'timestamp'>) => void;
  updateTransaction: (hash: string, updates: Partial<Transaction>) => void;
  clearTransactions: () => void;
  
  // Error handling
  error: WalletError | null;
  setError: (error: WalletError | null) => void;
  
  // Reset state
  reset: () => void;
}

const initialState: WalletState = {
  address: null,
  chainId: null,
  isConnected: false,
  isConnecting: false,
  balance: '0',
  ensName: undefined,
};

export const useWalletStore = create<WalletStore>((set) => ({
  ...initialState,
  transactions: [],
  error: null,

  setAddress: (address) => set({ address }),
  setChainId: (chainId) => set({ chainId }),
  setConnected: (isConnected) => set({ isConnected }),
  setConnecting: (isConnecting) => set({ isConnecting }),
  setBalance: (balance) => set({ balance }),
  setEnsName: (ensName) => set({ ensName }),

  addTransaction: (transaction) => {
    const newTransaction: Transaction = {
      ...transaction,
      timestamp: Date.now(),
    };
    set((state) => ({
      transactions: [newTransaction, ...state.transactions],
    }));
  },

  updateTransaction: (hash, updates) => {
    set((state) => ({
      transactions: state.transactions.map((tx) =>
        tx.hash === hash ? { ...tx, ...updates } : tx
      ),
    }));
  },

  clearTransactions: () => set({ transactions: [] }),

  setError: (error) => set({ error }),

  reset: () => set({
    ...initialState,
    transactions: [],
    error: null,
  }),
}));
