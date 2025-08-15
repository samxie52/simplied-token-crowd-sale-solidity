# Step 3.1: 代币释放合约(Vesting)

## 📋 概述

Step 3.1 实现灵活的代币释放和锁定机制，为众筹平台提供防抛售保护和长期激励机制。通过线性释放、阶梯式释放等多种策略，确保代币的有序流通和项目的长期稳定发展。

## 🎯 设计目标

### 核心功能目标
- **多种释放策略**: 支持线性释放、阶梯式释放、悬崖期释放等
- **精确时间控制**: 基于区块时间戳的精确释放计算
- **多受益人管理**: 支持为不同用户设置不同的释放计划
- **实时查询**: 提供可释放代币数量的实时查询
- **释放历史**: 完整的释放记录和统计数据

### 技术目标
- **高精度计算**: 支持18位小数精度的释放计算
- **Gas优化**: 释放操作Gas消耗 <100,000 gas
- **安全保障**: 防止重入攻击和权限绕过
- **模块化设计**: 可扩展的释放策略架构

## 🏗️ 架构设计

### 释放策略类型

```solidity
// 释放策略枚举
enum VestingType {
    LINEAR,        // 线性释放
    CLIFF,         // 悬崖期释放
    STEPPED,       // 阶梯式释放
    MILESTONE,     // 里程碑释放
    CUSTOM         // 自定义释放
}

// 释放计划结构
struct VestingSchedule {
    address beneficiary;      // 受益人地址
    uint256 totalAmount;      // 总释放数量
    uint256 startTime;        // 开始时间
    uint256 cliffDuration;    // 悬崖期时长
    uint256 vestingDuration;  // 释放期时长
    uint256 releasedAmount;   // 已释放数量
    VestingType vestingType;  // 释放类型
    bool revocable;           // 是否可撤销
    bool revoked;             // 是否已撤销
}
```

## 💰 释放机制设计

### 1. 线性释放策略 (Linear Vesting)

**特点**:
- 在释放期内均匀释放代币
- 计算简单，Gas消耗低
- 适用于大部分标准场景

**计算公式**:
```solidity
function calculateLinearVesting(
    uint256 totalAmount,
    uint256 startTime,
    uint256 duration,
    uint256 currentTime
) pure returns (uint256) {
    if (currentTime < startTime) return 0;
    if (currentTime >= startTime + duration) return totalAmount;
    
    return (totalAmount * (currentTime - startTime)) / duration;
}
```

### 2. 悬崖期释放策略 (Cliff Vesting)

**特点**:
- 初始锁定期内不释放任何代币
- 悬崖期后开始线性释放
- 防止短期投机行为

**计算逻辑**:
```solidity
function calculateCliffVesting(
    uint256 totalAmount,
    uint256 startTime,
    uint256 cliffDuration,
    uint256 vestingDuration,
    uint256 currentTime
) pure returns (uint256) {
    if (currentTime < startTime + cliffDuration) return 0;
    
    uint256 vestingStart = startTime + cliffDuration;
    if (currentTime >= vestingStart + vestingDuration) return totalAmount;
    
    return (totalAmount * (currentTime - vestingStart)) / vestingDuration;
}
```

### 3. 阶梯式释放策略 (Stepped Vesting)

**特点**:
- 分阶段批量释放代币
- 每个阶段释放固定比例
- 适用于里程碑奖励

**阶段设计**:
- **第1阶段** (3个月后): 释放25%
- **第2阶段** (6个月后): 释放25% 
- **第3阶段** (9个月后): 释放25%
- **第4阶段** (12个月后): 释放25%

## 📋 实现检查清单

### 核心合约实现
- [ ] **ITokenVesting.sol**: 代币释放接口定义
- [ ] **TokenVesting.sol**: 主释放合约实现
- [ ] **VestingMath.sol**: 释放数学计算库
- [ ] **释放策略实现**: 线性、悬崖期、阶梯式释放
- [ ] **多受益人管理**: 支持批量创建和管理
- [ ] **权限控制**: 基于角色的访问控制
- [ ] **查询接口**: 实时释放进度查询

### 安全功能实现
- [ ] **重入攻击防护**: ReentrancyGuard集成
- [ ] **权限验证**: 严格的角色权限控制
- [ ] **输入验证**: 全面的参数验证
- [ ] **溢出保护**: 安全的数学运算
- [ ] **紧急控制**: 暂停和紧急提取功能

### 测试实现
- [ ] **TokenVesting.t.sol**: 完整的单元测试套件
- [ ] **VestingFuzz.t.sol**: 模糊测试边界条件
- [ ] **集成测试**: 与众筹合约的集成测试
- [ ] **性能测试**: Gas消耗和批量操作测试

## 🚀 部署和验证

### 部署脚本
```solidity
// DeployVesting.s.sol
contract DeployVesting is Script {
    function run() external {
        // 部署TokenVesting合约
        // 配置角色权限
        // 验证部署结果
    }
}
```

### 验证步骤
1. **功能验证**: 所有释放策略正常工作
2. **性能验证**: Gas消耗符合预期
3. **安全验证**: 权限控制和攻击防护有效
4. **集成验证**: 与众筹系统集成正常

## 📚 相关文档

- **Step 2.3**: [资金托管和退款机制](./step-2-3-refund-vault.md)
- **Step 2.2**: [代币购买和定价机制](./step-2-2-purchase-pricing.md)
- **Step 2.1**: [众筹主合约架构](./step-2-1-crowdsale-architecture.md)

## 🔄 下一步: Step 3.2

完成Step 3.1后，将进入Step 3.2: 众筹合约集成和完善，实现：
- 整合所有子合约功能
- 完善众筹生命周期管理
- 优化合约间调用效率
- 添加完整的事件系统

---

**预期成果**: 完整的代币释放系统，支持多种释放策略、精确时间控制、多受益人管理和实时查询功能，为众筹平台提供专业的代币锁定和释放服务。
