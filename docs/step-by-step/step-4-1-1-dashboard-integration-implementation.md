# Step 4.1.1: Dashboard页面真实数据集成 - 详细实现文档

## 📋 实现概览

本文档详细描述Dashboard页面与智能合约集成的完整实现方案，包括用户投资记录查询、代币释放管理、投资统计计算和交互功能完善。

### 🎯 实现目标
- 替换所有模拟数据，使用真实合约数据
- 实现完整的用户投资组合管理
- 提供代币释放计划查看和操作功能
- 显示准确的投资统计和收益分析

---

## 🏗️ 技术架构设计

### 数据流架构
```
Dashboard页面
    ↓
useUserInvestments Hook ← TokenCrowdsale合约
    ↓
useTokenVesting Hook ← TokenVesting合约
    ↓
useInvestmentStats Hook ← 多合约数据聚合
    ↓
UI组件渲染
```

### 核心Hook设计
1. **useUserInvestments** - 管理用户投资记录
2. **useTokenVesting** - 管理代币释放功能
3. **useInvestmentStats** - 计算投资统计数据
4. **useDashboardData** - 聚合所有Dashboard数据

---

## 🔧 详细实现方案

## 1. 用户投资记录查询功能

### 1.1 创建useUserInvestments Hook

**文件**: `web/src/hooks/useUserInvestments.ts`

#### 功能需求:
- 查询用户在所有众筹项目中的投资记录
- 获取投资金额、代币数量、投资时间
- 实时更新投资状态
- 支持分页和筛选

#### 合约交互:
- `TokenCrowdsale.getUserPurchaseHistory(address user)`
- `TokenCrowdsale.getUserTotalPurchased(address user)`
- `CrowdsaleFactory.getCreatorCrowdsales(address creator)`

#### 数据结构:
```typescript
interface UserInvestment {
  crowdsaleAddress: string;
  crowdsaleName: string;
  tokenSymbol: string;
  investedAmount: string; // ETH amount
  tokenAmount: string; // Token amount received
  investmentDate: number; // Unix timestamp
  status: 'active' | 'completed' | 'refunded';
  currentValue: string; // Current USD value
  profitLoss: string; // Profit/Loss amount
  profitLossPercentage: number; // Profit/Loss percentage
}
```

### 1.2 实现步骤:

#### Step 1: 基础Hook结构
```typescript
export const useUserInvestments = (userAddress?: string) => {
  const [investments, setInvestments] = useState<UserInvestment[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // 实现投资记录查询逻辑
}
```

#### Step 2: 合约数据查询
- 查询CrowdsaleFactory获取所有众筹地址
- 遍历每个众筹合约查询用户投资记录
- 聚合数据并计算当前价值

#### Step 3: 数据缓存和更新
- 实现本地缓存减少重复查询
- 监听合约事件实时更新数据
- 添加手动刷新功能

---

## 2. 代币释放管理集成

### 2.1 创建useTokenVesting Hook

**文件**: `web/src/hooks/useTokenVesting.ts`

#### 功能需求:
- 查询用户所有代币释放计划
- 显示释放进度和下次释放时间
- 实现手动释放代币功能
- 计算可释放代币数量

#### 合约交互:
- `TokenVesting.getBeneficiarySchedules(address beneficiary)`
- `TokenVesting.getReleasableAmount(bytes32 scheduleId)`
- `TokenVesting.releaseTokens(bytes32 scheduleId)`
- `TokenVesting.batchRelease(bytes32[] scheduleIds)`

#### 数据结构:
```typescript
interface VestingSchedule {
  scheduleId: string;
  tokenAddress: string;
  tokenSymbol: string;
  totalAmount: string;
  releasedAmount: string;
  remainingAmount: string;
  releasableAmount: string;
  startTime: number;
  cliffEnd: number;
  endTime: number;
  vestingType: 'LINEAR' | 'CLIFF' | 'STEPPED' | 'MILESTONE';
  nextReleaseDate: number;
  releaseProgress: number; // 0-100
  isRevocable: boolean;
  isRevoked: boolean;
}
```

### 2.2 实现步骤:

#### Step 1: 查询释放计划
```typescript
const fetchVestingSchedules = useCallback(async () => {
  if (!userAddress) return;
  
  try {
    const vestingContract = await getVestingContract();
    const scheduleIds = await vestingContract.getBeneficiarySchedules(userAddress);
    
    const schedules = await Promise.all(
      scheduleIds.map(async (id) => {
        const schedule = await vestingContract.getVestingSchedule(id);
        const releasableAmount = await vestingContract.getReleasableAmount(id);
        return {
          scheduleId: id,
          ...schedule,
          releasableAmount: releasableAmount.toString(),
          releaseProgress: calculateProgress(schedule),
        };
      })
    );
    
    setVestingSchedules(schedules);
  } catch (error) {
    setError(handleContractError(error));
  }
}, [userAddress]);
```

#### Step 2: 释放代币功能
```typescript
const releaseTokens = useCallback(async (scheduleId: string) => {
  try {
    setReleasing(true);
    const vestingContract = await getVestingContract();
    const tx = await vestingContract.releaseTokens(scheduleId);
    
    // 添加交易到状态管理
    addTransaction({
      hash: tx.hash,
      type: 'TOKEN_RELEASE',
      status: 'PENDING',
      amount: releasableAmount,
    });
    
    await tx.wait();
    
    // 更新交易状态和刷新数据
    updateTransaction(tx.hash, { status: 'SUCCESS' });
    await fetchVestingSchedules();
    
  } catch (error) {
    setError(handleContractError(error));
  } finally {
    setReleasing(false);
  }
}, []);
```

---

## 3. 投资统计计算

### 3.1 创建useInvestmentStats Hook

**文件**: `web/src/hooks/useInvestmentStats.ts`

#### 功能需求:
- 计算用户总投资金额
- 计算获得的代币总量
- 计算当前投资组合价值
- 计算收益率和盈亏

#### 数据结构:
```typescript
interface InvestmentStats {
  totalInvested: string; // Total ETH invested
  totalTokens: string; // Total tokens received
  currentValue: string; // Current portfolio value in USD
  totalProfit: string; // Total profit/loss in USD
  profitPercentage: number; // Profit percentage
  activeInvestments: number; // Number of active investments
  completedInvestments: number; // Number of completed investments
  averageROI: number; // Average return on investment
  bestPerforming: UserInvestment | null; // Best performing investment
  portfolioDistribution: PortfolioItem[]; // Token distribution
}

interface PortfolioItem {
  tokenSymbol: string;
  tokenAddress: string;
  amount: string;
  value: string;
  percentage: number;
}
```

### 3.2 实现步骤:

#### Step 1: 基础统计计算
```typescript
const calculateStats = useCallback((investments: UserInvestment[], vestingSchedules: VestingSchedule[]) => {
  const totalInvested = investments.reduce((sum, inv) => 
    sum + parseFloat(inv.investedAmount), 0
  );
  
  const totalTokens = investments.reduce((sum, inv) => 
    sum + parseFloat(inv.tokenAmount), 0
  );
  
  const currentValue = investments.reduce((sum, inv) => 
    sum + parseFloat(inv.currentValue), 0
  );
  
  const totalProfit = currentValue - totalInvested;
  const profitPercentage = totalInvested > 0 ? (totalProfit / totalInvested) * 100 : 0;
  
  return {
    totalInvested: totalInvested.toString(),
    totalTokens: totalTokens.toString(),
    currentValue: currentValue.toString(),
    totalProfit: totalProfit.toString(),
    profitPercentage,
    activeInvestments: investments.filter(inv => inv.status === 'active').length,
    completedInvestments: investments.filter(inv => inv.status === 'completed').length,
  };
}, []);
```

#### Step 2: 价格数据集成
```typescript
const fetchTokenPrices = useCallback(async (tokenAddresses: string[]) => {
  // 集成价格API或使用DEX价格
  // 可以使用Coingecko API或Uniswap价格
  try {
    const prices = await Promise.all(
      tokenAddresses.map(async (address) => {
        // 实现价格查询逻辑
        return await getTokenPrice(address);
      })
    );
    return prices;
  } catch (error) {
    console.error('Failed to fetch token prices:', error);
    return [];
  }
}, []);
```

---

## 4. 交互功能完善

### 4.1 Dashboard页面组件重构

**文件**: `web/src/pages/Dashboard.tsx`

#### 重构要点:
1. 移除所有模拟数据
2. 集成新的Hook
3. 添加加载状态和错误处理
4. 实现交互功能

#### 组件结构:
```typescript
export const Dashboard: React.FC = () => {
  const { address, isConnected } = useWallet();
  const { investments, loading: investmentsLoading, error: investmentsError, refreshInvestments } = useUserInvestments(address);
  const { vestingSchedules, loading: vestingLoading, releaseTokens, batchRelease } = useTokenVesting(address);
  const { stats, loading: statsLoading } = useInvestmentStats(investments, vestingSchedules);
  
  // 组件逻辑实现
};
```

### 4.2 新增交互功能

#### 4.2.1 代币释放操作
```typescript
const handleTokenRelease = async (scheduleId: string) => {
  try {
    await releaseTokens(scheduleId);
    toast.success('代币释放成功！');
  } catch (error) {
    toast.error('代币释放失败：' + error.message);
  }
};

const handleBatchRelease = async (scheduleIds: string[]) => {
  try {
    await batchRelease(scheduleIds);
    toast.success(`成功释放 ${scheduleIds.length} 个释放计划的代币！`);
  } catch (error) {
    toast.error('批量释放失败：' + error.message);
  }
};
```

#### 4.2.2 投资详情查看
```typescript
const [selectedInvestment, setSelectedInvestment] = useState<UserInvestment | null>(null);

const InvestmentDetailModal = ({ investment, onClose }) => {
  return (
    <Modal isOpen={!!investment} onClose={onClose}>
      <div className="p-6">
        <h3 className="text-lg font-semibold mb-4">投资详情</h3>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-gray-500">众筹项目</label>
            <p className="font-medium">{investment.crowdsaleName}</p>
          </div>
          <div>
            <label className="text-sm text-gray-500">投资金额</label>
            <p className="font-medium">{investment.investedAmount} ETH</p>
          </div>
          <div>
            <label className="text-sm text-gray-500">获得代币</label>
            <p className="font-medium">{investment.tokenAmount} {investment.tokenSymbol}</p>
          </div>
          <div>
            <label className="text-sm text-gray-500">当前价值</label>
            <p className="font-medium">${investment.currentValue}</p>
          </div>
          <div>
            <label className="text-sm text-gray-500">收益</label>
            <p className={`font-medium ${parseFloat(investment.profitLoss) >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              {investment.profitLoss} ({investment.profitLossPercentage.toFixed(2)}%)
            </p>
          </div>
        </div>
      </div>
    </Modal>
  );
};
```

---

## 5. UI组件优化

### 5.1 投资组合卡片
```typescript
const InvestmentCard = ({ investment }: { investment: UserInvestment }) => {
  const profitColor = parseFloat(investment.profitLoss) >= 0 ? 'text-green-600' : 'text-red-600';
  
  return (
    <Card className="p-4 hover:shadow-lg transition-shadow cursor-pointer" 
          onClick={() => setSelectedInvestment(investment)}>
      <div className="flex justify-between items-start mb-3">
        <div>
          <h4 className="font-semibold">{investment.crowdsaleName}</h4>
          <p className="text-sm text-gray-500">{investment.tokenSymbol}</p>
        </div>
        <span className={`px-2 py-1 rounded-full text-xs ${
          investment.status === 'active' ? 'bg-green-100 text-green-800' :
          investment.status === 'completed' ? 'bg-blue-100 text-blue-800' :
          'bg-red-100 text-red-800'
        }`}>
          {investment.status}
        </span>
      </div>
      
      <div className="space-y-2">
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">投资金额</span>
          <span className="font-medium">{investment.investedAmount} ETH</span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">获得代币</span>
          <span className="font-medium">{investment.tokenAmount}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">当前价值</span>
          <span className="font-medium">${investment.currentValue}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">收益</span>
          <span className={`font-medium ${profitColor}`}>
            {investment.profitLoss} ({investment.profitLossPercentage.toFixed(2)}%)
          </span>
        </div>
      </div>
    </Card>
  );
};
```

### 5.2 代币释放进度条
```typescript
const VestingProgressCard = ({ schedule }: { schedule: VestingSchedule }) => {
  const canRelease = parseFloat(schedule.releasableAmount) > 0;
  
  return (
    <Card className="p-4">
      <div className="flex justify-between items-start mb-3">
        <div>
          <h4 className="font-semibold">{schedule.tokenSymbol} 释放计划</h4>
          <p className="text-sm text-gray-500">
            {schedule.vestingType} • {formatDate(schedule.startTime)} - {formatDate(schedule.endTime)}
          </p>
        </div>
        {canRelease && (
          <Button 
            size="sm" 
            onClick={() => handleTokenRelease(schedule.scheduleId)}
            disabled={releasing}
          >
            释放代币
          </Button>
        )}
      </div>
      
      <div className="space-y-3">
        <div>
          <div className="flex justify-between text-sm mb-1">
            <span>释放进度</span>
            <span>{schedule.releaseProgress.toFixed(1)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div 
              className="bg-blue-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${schedule.releaseProgress}%` }}
            />
          </div>
        </div>
        
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-gray-500">总量</span>
            <p className="font-medium">{schedule.totalAmount}</p>
          </div>
          <div>
            <span className="text-gray-500">已释放</span>
            <p className="font-medium">{schedule.releasedAmount}</p>
          </div>
          <div>
            <span className="text-gray-500">可释放</span>
            <p className="font-medium text-green-600">{schedule.releasableAmount}</p>
          </div>
          <div>
            <span className="text-gray-500">剩余</span>
            <p className="font-medium">{schedule.remainingAmount}</p>
          </div>
        </div>
        
        {schedule.nextReleaseDate > Date.now() / 1000 && (
          <div className="text-sm text-gray-500">
            下次释放: {formatDate(schedule.nextReleaseDate)}
          </div>
        )}
      </div>
    </Card>
  );
};
```

---

## 6. 错误处理和加载状态

### 6.1 统一错误处理
```typescript
const ErrorBoundary = ({ error, retry }: { error: string; retry: () => void }) => (
  <div className="text-center py-8">
    <ExclamationTriangleIcon className="h-12 w-12 text-red-500 mx-auto mb-4" />
    <h3 className="text-lg font-semibold text-gray-900 mb-2">加载失败</h3>
    <p className="text-gray-500 mb-4">{error}</p>
    <Button onClick={retry}>重试</Button>
  </div>
);
```

### 6.2 加载状态组件
```typescript
const LoadingSpinner = ({ message = "加载中..." }: { message?: string }) => (
  <div className="flex flex-col items-center justify-center py-8">
    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mb-4"></div>
    <p className="text-gray-500">{message}</p>
  </div>
);
```

---

## 7. 测试策略

### 7.1 单元测试
- Hook函数测试
- 数据计算逻辑测试
- 组件渲染测试

### 7.2 集成测试
- 合约交互测试
- 数据流测试
- 用户操作流程测试

### 7.3 测试文件结构
```
tests/
├── hooks/
│   ├── useUserInvestments.test.ts
│   ├── useTokenVesting.test.ts
│   └── useInvestmentStats.test.ts
├── components/
│   ├── InvestmentCard.test.tsx
│   └── VestingProgressCard.test.tsx
└── pages/
    └── Dashboard.test.tsx
```

---

## 8. 性能优化

### 8.1 数据缓存策略
- 使用React Query缓存合约查询结果
- 实现本地存储缓存
- 设置合理的缓存失效时间

### 8.2 懒加载和分页
- 投资记录分页加载
- 图表组件懒加载
- 大数据量虚拟滚动

### 8.3 网络请求优化
- 批量合约调用
- 并行数据查询
- 请求去重和防抖

---

## 9. 部署和验证

### 9.1 部署步骤
1. 确保所有合约已部署并配置正确
2. 更新环境变量配置
3. 运行完整测试套件
4. 部署前端应用
5. 验证功能完整性

### 9.2 验收标准
- [ ] 显示真实的用户投资记录
- [ ] 代币释放计划正确展示
- [ ] 统计数据准确计算
- [ ] 所有交互功能正常工作
- [ ] 错误处理和加载状态完善
- [ ] 性能指标达标

---

## 📝 实施计划

### Day 1: Hook开发
- 创建useUserInvestments Hook
- 创建useTokenVesting Hook
- 实现基础数据查询功能

### Day 2: 统计和UI
- 创建useInvestmentStats Hook
- 重构Dashboard页面组件
- 实现新的UI组件

### Day 3: 交互功能
- 实现代币释放功能
- 添加投资详情查看
- 完善错误处理

### Day 4: 测试和优化
- 编写单元测试
- 性能优化
- 用户体验优化

### Day 5: 集成测试
- 端到端测试
- 修复问题
- 最终验收

---

*本文档将在实施过程中持续更新，确保实现质量和进度可控。*
