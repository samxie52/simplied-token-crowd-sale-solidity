# Step 2.1: 众筹主合约架构

## 📋 概述

**功能目标**: 实现众筹合约的核心架构和状态管理  
**前置条件**: Step 1.3 (WhitelistManager) 完成  
**输入依赖**: OpenZeppelin Security和Math库  

## 🎯 设计目标

### 核心功能
- **多阶段众筹管理**: 预售 → 公售 → 结束的完整生命周期
- **状态机设计**: 严格的状态转换控制和验证
- **时间控制机制**: 基于区块时间的精确控制
- **资金目标管理**: 软顶/硬顶目标设置和监控
- **权限控制系统**: 分层权限管理和操作控制
- **紧急控制机制**: 暂停/恢复功能保障安全

### 架构原则
- **模块化设计**: 清晰的职责分离和接口定义
- **可扩展性**: 预留扩展接口支持未来功能
- **安全第一**: 多重安全检查和防护机制
- **Gas优化**: 高效的存储布局和计算逻辑
- **事件驱动**: 完整的事件记录便于监控

## 🏗️ 架构设计

### 状态机设计

```
┌─────────────┐    startCrowdsale()    ┌─────────────┐
│   PENDING   │ ──────────────────────→ │  PRESALE    │
│   (初始)     │                        │   (预售)     │
└─────────────┘                        └─────────────┘
                                              │
                                              │ startPublicSale()
                                              ▼
┌─────────────┐    finalize()          ┌─────────────┐
│  FINALIZED  │ ←──────────────────────│ PUBLIC_SALE │
│   (已结束)   │                        │   (公售)     │
└─────────────┘                        └─────────────┘
       ▲                                      │
       │                                      │ 
       └──────── emergencyStop() ─────────────┘
```

### 合约架构层次

```
TokenCrowdsale (主合约)
├── ICrowdsale (接口定义)
├── CrowdsaleConstants (常量定义)  
├── AccessControl (权限管理)
├── Pausable (暂停机制)
├── ReentrancyGuard (重入防护)
└── 集成合约:
    ├── CrowdsaleToken (ERC20代币)
    └── WhitelistManager (白名单管理)
```

## 📊 核心组件

### 1. 众筹阶段枚举

```solidity
enum CrowdsalePhase {
    PENDING,        // 0: 待开始
    PRESALE,        // 1: 预售阶段
    PUBLIC_SALE,    // 2: 公售阶段  
    FINALIZED       // 3: 已结束
}
```

### 2. 众筹配置结构

```solidity
struct CrowdsaleConfig {
    uint256 presaleStartTime;     // 预售开始时间
    uint256 presaleEndTime;       // 预售结束时间
    uint256 publicSaleStartTime;  // 公售开始时间
    uint256 publicSaleEndTime;    // 公售结束时间
    uint256 softCap;              // 软顶目标 (最小筹资目标)
    uint256 hardCap;              // 硬顶目标 (最大筹资目标)
    uint256 minPurchase;          // 最小购买金额
    uint256 maxPurchase;          // 最大购买金额
}
```

### 3. 众筹状态跟踪

```solidity
struct CrowdsaleStats {
    uint256 totalRaised;         // 总筹资金额
    uint256 totalTokensSold;     // 总售出代币数量
    uint256 participantCount;    // 参与人数
    uint256 presaleRaised;       // 预售筹资金额
    uint256 publicSaleRaised;    // 公售筹资金额
}
```

## 🔧 核心功能实现

### 1. 状态管理系统

**状态转换控制**:
- 严格的状态转换验证
- 时间窗口检查
- 权限验证
- 条件满足检查

**关键修饰符**:
- `onlyInPhase(CrowdsalePhase _phase)`: 阶段检查
- `onlyValidTransition(CrowdsalePhase _from, CrowdsalePhase _to)`: 转换验证
- `withinTimeWindow()`: 时间窗口验证

### 2. 时间控制机制

**时间管理**:
- 基于 `block.timestamp` 的精确时间控制
- 预售和公售时间窗口管理
- 自动阶段转换触发
- 时间边界验证

**时间验证逻辑**:
```solidity
modifier withinTimeWindow() {
    if (currentPhase == CrowdsalePhase.PRESALE) {
        require(
            block.timestamp >= config.presaleStartTime && 
            block.timestamp <= config.presaleEndTime,
            "Not in presale time window"
        );
    }
    // 其他阶段的时间验证...
    _;
}
```

### 3. 资金目标管理

**软顶/硬顶机制**:
- **软顶 (Soft Cap)**: 最小成功筹资目标
- **硬顶 (Hard Cap)**: 最大筹资上限
- 实时目标达成检查
- 自动结束触发条件

**目标检查逻辑**:
- 达到硬顶自动结束众筹
- 软顶未达成触发退款机制
- 实时进度计算和更新

### 4. 权限控制系统

**角色定义**:
```solidity
bytes32 public constant CROWDSALE_ADMIN_ROLE = keccak256("CROWDSALE_ADMIN_ROLE");
bytes32 public constant CROWDSALE_OPERATOR_ROLE = keccak256("CROWDSALE_OPERATOR_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```

**权限分配**:
- **CROWDSALE_ADMIN_ROLE**: 众筹配置和管理
- **CROWDSALE_OPERATOR_ROLE**: 日常操作和监控  
- **EMERGENCY_ROLE**: 紧急暂停和恢复

## 🛡️ 安全机制

### 1. 重入攻击防护
- 使用 OpenZeppelin 的 `ReentrancyGuard`
- 关键函数添加 `nonReentrant` 修饰符
- 状态更新在外部调用之前完成

### 2. 整数溢出防护
- 使用 Solidity 0.8+ 内置溢出检查
- 关键计算使用 SafeMath 验证
- 边界条件检查

### 3. 访问控制
- 基于角色的权限管理
- 函数级别的访问控制
- 敏感操作的多重验证

### 4. 紧急控制
- 紧急暂停机制
- 管理员紧急干预能力
- 状态回滚和恢复功能

## 📝 接口设计

### ICrowdsale 核心接口

```solidity
interface ICrowdsale {
    // 状态查询
    function getCurrentPhase() external view returns (CrowdsalePhase);
    function getCrowdsaleConfig() external view returns (CrowdsaleConfig memory);
    function getCrowdsaleStats() external view returns (CrowdsaleStats memory);
    
    // 状态管理
    function startPresale() external;
    function startPublicSale() external;
    function finalizeCrowdsale() external;
    
    // 紧急控制
    function emergencyPause() external;
    function emergencyResume() external;
    
    // 配置管理
    function updateConfig(CrowdsaleConfig calldata _config) external;
}
```

## 🧪 测试策略

### 1. 单元测试覆盖

**状态管理测试**:
- 初始状态验证
- 状态转换逻辑
- 非法转换拒绝
- 边界条件处理

**时间控制测试**:
- 时间窗口验证
- 自动转换触发
- 时间边界处理
- 过期状态检查

**权限控制测试**:
- 角色权限验证
- 未授权访问拒绝
- 权限转移测试
- 紧急权限测试

### 2. 集成测试场景

**完整流程测试**:
- 众筹生命周期测试
- 多合约交互测试
- 异常情况处理
- 边界条件验证

### 3. 模糊测试

**随机输入测试**:
- 随机时间参数
- 随机配置组合
- 边界值测试
- 异常输入处理

## 📈 Gas优化策略

### 1. 存储优化
- 结构体打包优化
- 状态变量布局优化
- 减少存储读写操作

### 2. 计算优化
- 避免重复计算
- 使用位运算优化
- 批量操作支持

### 3. 事件优化
- 索引字段优化
- 事件数据最小化
- 批量事件发射

## 🚀 部署和验证

### 1. 部署脚本
- 环境配置检查
- 依赖合约验证
- 初始化参数设置
- 部署后验证

### 2. 验证步骤
- 合约状态验证
- 权限配置检查
- 集成测试执行
- 功能完整性验证

## 📚 最佳实践

### 1. 代码质量
- 遵循 Solidity 编码规范
- 完整的 NatSpec 文档
- 错误处理和回滚机制
- 代码可读性和维护性

### 2. 安全考虑
- 最小权限原则
- 多重验证机制
- 紧急响应能力
- 审计友好的代码结构

### 3. 可扩展性
- 模块化接口设计
- 升级预留接口
- 配置参数化
- 功能插件化支持

---

## 📋 实施检查清单

- [ ] 创建 ICrowdsale 接口定义
- [ ] 实现 CrowdsaleConstants 常量文件
- [ ] 开发 TokenCrowdsale 主合约
- [ ] 编写完整的单元测试
- [ ] 实现部署脚本
- [ ] 执行集成测试
- [ ] 进行安全审查
- [ ] 完成文档编写

---

**下一步**: 实现 Step 2.2 代币购买和定价机制，在当前架构基础上添加具体的购买逻辑和定价策略。
