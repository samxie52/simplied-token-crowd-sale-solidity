import { create } from 'zustand';
import { CrowdsaleConfig, CrowdsaleStats, CrowdsalePhase, CrowdsaleInstance } from '@/types/contracts';

interface CrowdsaleStore {
  // Current crowdsale data
  currentCrowdsale: string | null;
  config: CrowdsaleConfig | null;
  stats: CrowdsaleStats | null;
  phase: CrowdsalePhase | null;
  
  // All crowdsales
  crowdsales: CrowdsaleInstance[];
  activeCrowdsales: CrowdsaleInstance[];
  
  // Loading states
  isLoading: boolean;
  isCreating: boolean;
  isPurchasing: boolean;
  
  // Actions
  setCurrentCrowdsale: (address: string | null) => void;
  setConfig: (config: CrowdsaleConfig | null) => void;
  setStats: (stats: CrowdsaleStats | null) => void;
  setPhase: (phase: CrowdsalePhase | null) => void;
  setCrowdsales: (crowdsales: CrowdsaleInstance[]) => void;
  setActiveCrowdsales: (crowdsales: CrowdsaleInstance[]) => void;
  setLoading: (isLoading: boolean) => void;
  setCreating: (isCreating: boolean) => void;
  setPurchasing: (isPurchasing: boolean) => void;
  
  // Computed values
  getFundingProgress: () => number;
  getRemainingTime: () => number;
  isActive: () => boolean;
  canPurchase: () => boolean;
  
  // Reset
  reset: () => void;
}

export const useCrowdsaleStore = create<CrowdsaleStore>((set, get) => ({
  currentCrowdsale: null,
  config: null,
  stats: null,
  phase: null,
  crowdsales: [],
  activeCrowdsales: [],
  isLoading: false,
  isCreating: false,
  isPurchasing: false,

  setCurrentCrowdsale: (address) => set({ currentCrowdsale: address }),
  setConfig: (config) => set({ config }),
  setStats: (stats) => set({ stats }),
  setPhase: (phase) => set({ phase }),
  setCrowdsales: (crowdsales) => set({ crowdsales }),
  setActiveCrowdsales: (crowdsales) => set({ activeCrowdsales: crowdsales }),
  setLoading: (isLoading) => set({ isLoading }),
  setCreating: (isCreating) => set({ isCreating }),
  setPurchasing: (isPurchasing) => set({ isPurchasing }),

  getFundingProgress: () => {
    const { stats, config } = get();
    if (!stats || !config || config.hardCap === 0n) return 0;
    return Math.min(Number(stats.totalRaised * 100n / config.hardCap), 100);
  },

  getRemainingTime: () => {
    const { config, phase } = get();
    if (!config || !phase) return 0;
    
    const now = Math.floor(Date.now() / 1000);
    let endTime: bigint;
    
    switch (phase) {
      case CrowdsalePhase.PRESALE:
        endTime = config.presaleEndTime;
        break;
      case CrowdsalePhase.PUBLIC_SALE:
        endTime = config.publicSaleEndTime;
        break;
      default:
        return 0;
    }
    
    return Math.max(Number(endTime) - now, 0);
  },

  isActive: () => {
    const { phase } = get();
    return phase === CrowdsalePhase.PRESALE || phase === CrowdsalePhase.PUBLIC_SALE;
  },

  canPurchase: () => {
    const { phase, stats, config } = get();
    if (!phase || !stats || !config) return false;
    
    const isActivePhase = phase === CrowdsalePhase.PRESALE || phase === CrowdsalePhase.PUBLIC_SALE;
    const hasNotReachedHardCap = stats.totalRaised < config.hardCap;
    
    return isActivePhase && hasNotReachedHardCap;
  },

  reset: () => set({
    currentCrowdsale: null,
    config: null,
    stats: null,
    phase: null,
    crowdsales: [],
    activeCrowdsales: [],
    isLoading: false,
    isCreating: false,
    isPurchasing: false,
  }),
}));
