// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IRefundVault.sol";
import "./interfaces/ICrowdsale.sol";

/**
 * @title RefundVault
 * @dev 资金托管和退款机制实现
 * @author Crowdsale Platform Team
 */
contract RefundVault is IRefundVault, AccessControl, ReentrancyGuard, Pausable {
    
    // ============ 角色定义 ============
    
    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant VAULT_OPERATOR_ROLE = keccak256("VAULT_OPERATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // ============ 常量定义 ============
    
    uint256 public constant MAX_BATCH_SIZE = 100;  // 最大批量处理数量
    uint256 public constant MIN_REQUIRED_SIGNATURES = 1;  // 最小签名要求
    uint256 public constant MAX_REQUIRED_SIGNATURES = 10; // 最大签名要求
    
    // ============ 状态变量 ============
    
    VaultState public override state;
    address public override getBeneficiary;
    address public override getCrowdsale;
    
    // 资金统计
    uint256 public override getTotalDeposited;
    uint256 public override getTotalRefunded;
    uint256 public refundStartTime;
    
    // 存款记录
    mapping(address => Deposit) public deposits;
    
    // 退款批次
    uint256 public currentBatchId;
    mapping(uint256 => RefundBatch) public refundBatches;
    
    // 多重签名
    mapping(address => bool) public signers;
    mapping(bytes32 => uint256) public signatureCount;
    mapping(bytes32 => mapping(address => bool)) public hasSigned;
    uint256 public override getRequiredSignatures;
    uint256 public signerCount;
    
    // ============ 修饰符 ============
    
    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "RefundVault: caller is not admin");
        _;
    }
    
    modifier onlyOperator() {
        require(
            hasRole(VAULT_OPERATOR_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "RefundVault: caller is not operator"
        );
        _;
    }
    
    modifier onlyCrowdsale() {
        require(msg.sender == getCrowdsale, "RefundVault: caller is not crowdsale");
        _;
    }
    
    modifier requireMultiSig(bytes32 operation) {
        require(signatureCount[operation] >= getRequiredSignatures, "RefundVault: insufficient signatures");
        _;
        // 清除签名记录
        _resetSignatures(operation);
    }
    
    modifier validAddress(address addr) {
        require(addr != address(0), "RefundVault: zero address");
        _;
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数
     * @param beneficiary 资金受益人地址
     * @param crowdsale 众筹合约地址
     * @param requiredSignatures 所需签名数量
     * @param admin 管理员地址
     */
    constructor(
        address beneficiary,
        address crowdsale,
        uint256 requiredSignatures,
        address admin
    ) 
        validAddress(beneficiary)
        validAddress(crowdsale)
        validAddress(admin)
    {
        require(
            requiredSignatures >= MIN_REQUIRED_SIGNATURES && 
            requiredSignatures <= MAX_REQUIRED_SIGNATURES,
            "RefundVault: invalid signature requirement"
        );
        
        getBeneficiary = beneficiary;
        getCrowdsale = crowdsale;
        getRequiredSignatures = requiredSignatures;
        state = VaultState.ACTIVE;
        
        // 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_OPERATOR_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        
        // 初始签名者
        signers[admin] = true;
        signerCount = 1;
    }
    
    // ============ 核心功能实现 ============
    
    /**
     * @dev 接收资金存款
     * @param depositor 存款人地址
     * 
     * 功能概述：
     * 从众筹合约接收用户的资金存款，记录存款信息并更新统计数据
     * 
     * 实现步骤：
     * 1. 验证合约状态为ACTIVE
     * 2. 验证存款金额大于0
     * 3. 更新存款人的存款记录
     * 4. 更新总存款统计
     * 5. 发出Deposited事件
     * 
     * 权限要求：只允许众筹合约调用
     * 用途说明：托管用户在众筹中投入的资金
     * 安全考虑：使用onlyCrowdsale修饰符确保只有授权合约可调用
     */
    function deposit(address depositor) 
        external 
        payable 
        override 
        onlyCrowdsale 
        whenNotPaused 
        validAddress(depositor)
    {
        require(state == VaultState.ACTIVE, "RefundVault: not active");
        require(msg.value > 0, "RefundVault: zero amount");
        
        deposits[depositor].amount += msg.value;
        deposits[depositor].timestamp = block.timestamp;
        getTotalDeposited += msg.value;
        
        emit Deposited(depositor, msg.value, block.timestamp);
    }
    
    /**
     * @dev 单个用户退款
     * @param depositor 退款接收人地址
     * 
     * 功能概述：
     * 为单个用户处理退款，将其存款金额退还给原地址
     * 
     * 实现步骤：
     * 1. 验证合约状态为REFUNDING
     * 2. 检查用户未曾退款
     * 3. 获取用户存款金额
     * 4. 更新退款状态和统计
     * 5. 执行ETH转账退款
     * 6. 发出Refunded事件
     * 
     * 权限要求：任何人都可调用，但只能为有效存款人退款
     * 用途说明：众筹失败后用户主动申请退款
     * 安全考虑：使用ReentrancyGuard防止重入攻击，状态先更新再转账
     */
    function refund(address depositor) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        validAddress(depositor)
    {
        require(state == VaultState.REFUNDING, "RefundVault: not refunding");
        require(!deposits[depositor].refunded, "RefundVault: already refunded");
        
        uint256 amount = deposits[depositor].amount;
        require(amount > 0, "RefundVault: no deposit");
        
        // 更新状态
        deposits[depositor].refunded = true;
        deposits[depositor].refundAmount = amount;
        getTotalRefunded += amount;
        
        // 执行退款
        (bool success, ) = depositor.call{value: amount}("");
        require(success, "RefundVault: refund failed");
        
        emit Refunded(depositor, amount, block.timestamp);
    }
    
    /**
     * @dev 批量退款处理
     * @param depositors 退款接收人地址数组
     * 
     * 功能概述：
     * 批量处理多个用户的退款，提高退款效率并降低Gas成本
     * 
     * 实现步骤：
     * 1. 验证合约状态和批量大小限制
     * 2. 遍历存款人数组
     * 3. 对每个有效存款人执行退款
     * 4. 记录成功和失败的退款
     * 5. 更新批次信息和统计数据
     * 6. 发出BatchRefundProcessed事件
     * 
     * 权限要求：只允许操作员角色调用
     * 用途说明：管理员批量处理退款，提高运营效率
     * 安全考虑：限制批量大小，失败时回滚状态，防止部分失败影响整体
     */
    function batchRefund(address[] calldata depositors) 
        external 
        override 
        onlyOperator 
        nonReentrant 
        whenNotPaused
    {
        require(state == VaultState.REFUNDING, "RefundVault: not refunding");
        require(depositors.length > 0, "RefundVault: empty array");
        require(depositors.length <= MAX_BATCH_SIZE, "RefundVault: batch too large");
        
        uint256 batchId = ++currentBatchId;
        uint256 totalBatchAmount = 0;
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < depositors.length; i++) {
            address depositor = depositors[i];
            
            // 跳过无效地址
            if (depositor == address(0)) continue;
            
            // 检查是否可以退款
            if (!deposits[depositor].refunded && deposits[depositor].amount > 0) {
                uint256 amount = deposits[depositor].amount;
                
                // 更新状态
                deposits[depositor].refunded = true;
                deposits[depositor].refundAmount = amount;
                
                // 尝试退款
                (bool success, ) = depositor.call{value: amount}("");
                if (success) {
                    totalBatchAmount += amount;
                    successCount++;
                    emit Refunded(depositor, amount, block.timestamp);
                } else {
                    // 回滚状态
                    deposits[depositor].refunded = false;
                    deposits[depositor].refundAmount = 0;
                    emit RefundFailed(depositor, amount, "Transfer failed");
                }
            }
        }
        
        getTotalRefunded += totalBatchAmount;
        
        // 记录批次信息
        refundBatches[batchId] = RefundBatch({
            batchId: batchId,
            totalAmount: totalBatchAmount,
            userCount: successCount,
            timestamp: block.timestamp,
            completed: true
        });
        
        emit BatchRefundProcessed(batchId, successCount, totalBatchAmount);
    }
    
    /**
     * @dev 启用退款模式
     * 
     * 功能概述：
     * 将托管合约从ACTIVE状态切换到REFUNDING状态，允许用户申请退款
     * 
     * 实现步骤：
     * 1. 验证当前状态为ACTIVE
     * 2. 检查启用退款的条件
     * 3. 切换状态到REFUNDING
     * 4. 记录退款开始时间
     * 5. 发出RefundsEnabled事件
     * 
     * 权限要求：只允许操作员角色调用
     * 用途说明：众筹失败后启用退款机制
     * 安全考虑：通过shouldEnableRefunds()验证启用条件，防止误操作
     */
    function enableRefunds() external override onlyOperator whenNotPaused {
        require(state == VaultState.ACTIVE, "RefundVault: not active");
        require(shouldEnableRefunds(), "RefundVault: conditions not met");
        
        state = VaultState.REFUNDING;
        refundStartTime = block.timestamp;
        
        emit RefundsEnabled(block.timestamp);
    }
    
    /**
     * @dev 释放资金给受益人
     * 
     * 功能概述：
     * 众筹成功后将托管的所有资金释放给指定的受益人
     * 
     * 实现步骤：
     * 1. 验证当前状态为ACTIVE
     * 2. 检查释放资金的条件
     * 3. 切换状态到CLOSED
     * 4. 获取合约余额
     * 5. 转账给受益人
     * 6. 发出Released事件
     * 
     * 权限要求：只允许操作员角色调用
     * 用途说明：众筹成功后释放资金给项目方
     * 安全考虑：使用ReentrancyGuard防止重入，通过canRelease()验证释放条件
     */
    function release() external override onlyOperator nonReentrant whenNotPaused {
        require(state == VaultState.ACTIVE, "RefundVault: not active");
        require(canRelease(), "RefundVault: cannot release yet");
        
        state = VaultState.CLOSED;
        uint256 amount = address(this).balance;
        
        (bool success, ) = getBeneficiary.call{value: amount}("");
        require(success, "RefundVault: release failed");
        
        emit Released(getBeneficiary, amount, block.timestamp);
    }
    
    /**
     * @dev 紧急提取资金
     * @param reason 紧急提取的原因说明
     * 
     * 功能概述：
     * 在紧急情况下提取合约中的所有资金，需要多重签名确认
     * 
     * 实现步骤：
     * 1. 验证原因说明不为空
     * 2. 检查多重签名确认
     * 3. 获取合约余额
     * 4. 转账给调用者
     * 5. 发出EmergencyWithdraw事件
     * 6. 重置相关签名记录
     * 
     * 权限要求：只允许紧急角色调用，且需要多重签名确认
     * 用途说明：应对合约漏洞或其他紧急情况的资金保护机制
     * 安全考虑：使用多重签名防止单点故障，ReentrancyGuard防止重入攻击
     */
    function emergencyWithdraw(string calldata reason) 
        external 
        override 
        onlyRole(EMERGENCY_ROLE) 
        nonReentrant 
        requireMultiSig(keccak256(abi.encodePacked("EMERGENCY_WITHDRAW", reason)))
    {
        require(bytes(reason).length > 0, "RefundVault: empty reason");
        
        uint256 amount = address(this).balance;
        require(amount > 0, "RefundVault: no funds");
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "RefundVault: emergency withdraw failed");
        
        emit EmergencyWithdraw(msg.sender, amount, reason);
    }
    
    // ============ 多重签名功能 ============
    
    /**
     * @dev 添加操作签名
     * @param operation 操作的哈希标识
     * 
     * 功能概述：
     * 为特定操作添加签名确认，用于多重签名机制
     * 
     * 实现步骤：
     * 1. 验证调用者是有效签名者
     * 2. 检查是否已经签名
     * 3. 记录签名状态
     * 4. 增加签名计数
     * 5. 发出SignatureAdded事件
     * 
     * 权限要求：只允许授权的签名者调用
     * 用途说明：多重签名操作的签名收集
     * 安全考虑：防止重复签名，确保签名者身份验证
     */
    function addSignature(bytes32 operation) external override {
        require(signers[msg.sender], "RefundVault: not a signer");
        require(!hasSigned[operation][msg.sender], "RefundVault: already signed");
        
        hasSigned[operation][msg.sender] = true;
        signatureCount[operation]++;
        
        emit SignatureAdded(operation, msg.sender, signatureCount[operation]);
    }
    
    /**
     * @dev 重置操作签名
     * @param operation 操作的哈希标识
     * 
     * 功能概述：
     * 清除特定操作的所有签名记录，用于取消或重新开始多重签名流程
     * 
     * 实现步骤：
     * 1. 调用内部重置函数
     * 2. 清零签名计数
     * 3. 保留签名映射以节省gas
     * 
     * 权限要求：只允许操作员角色调用
     * 用途说明：管理多重签名流程，取消错误的签名请求
     * 安全考虑：只有授权操作员可以重置，防止恶意干扰
     */
    function resetSignatures(bytes32 operation) external override onlyOperator {
        _resetSignatures(operation);
    }
    
    /**
     * @dev 内部重置签名函数
     */
    function _resetSignatures(bytes32 operation) internal {
        signatureCount[operation] = 0;
        // 注意：这里不清除hasSigned映射以节省gas，依赖signatureCount为0的检查
    }
    
    // ============ 管理功能 ============
    
    /**
     * @dev 更新受益人地址
     * @param newBeneficiary 新的受益人地址
     * 
     * 功能概述：
     * 更改资金释放的受益人地址，需要多重签名确认
     * 
     * 实现步骤：
     * 1. 验证新地址有效性
     * 2. 检查多重签名确认
     * 3. 更新受益人地址
     * 4. 发出BeneficiaryUpdated事件
     * 5. 重置签名记录
     * 
     * 权限要求：只允许管理员调用，且需要多重签名确认
     * 用途说明：更改项目方资金接收地址
     * 安全考虑：多重签名防止单点控制，地址验证防止错误设置
     */
    function updateBeneficiary(address newBeneficiary) 
        external 
        override 
        onlyOwner 
        validAddress(newBeneficiary)
        requireMultiSig(keccak256(abi.encodePacked("UPDATE_BENEFICIARY", newBeneficiary)))
    {
        address oldBeneficiary = getBeneficiary;
        getBeneficiary = newBeneficiary;
        
        emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
    }
    
    /**
     * @dev 添加签名者
     * @param signer 新签名者地址
     * 
     * 功能概述：
     * 向多重签名系统中添加新的授权签名者
     * 
     * 实现步骤：
     * 1. 验证地址有效性
     * 2. 检查是否已是签名者
     * 3. 验证签名者数量限制
     * 4. 添加签名者并更新计数
     * 
     * 权限要求：只允许管理员调用
     * 用途说明：扩展多重签名的授权范围
     * 安全考虑：限制最大签名者数量，防止系统过度复杂化
     */
    function addSigner(address signer) 
        external 
        override 
        onlyOwner 
        validAddress(signer)
    {
        require(!signers[signer], "RefundVault: already signer");
        require(signerCount < MAX_REQUIRED_SIGNATURES, "RefundVault: too many signers");
        
        signers[signer] = true;
        signerCount++;
    }
    
    /**
     * @dev 移除签名者
     * @param signer 要移除的签名者地址
     * 
     * 功能概述：
     * 从多重签名系统中移除指定的签名者
     * 
     * 实现步骤：
     * 1. 验证地址有效性
     * 2. 检查是否为现有签名者
     * 3. 验证移除后仍满足最小签名者要求
     * 4. 移除签名者并更新计数
     * 
     * 权限要求：只允许管理员调用
     * 用途说明：管理多重签名授权，移除不再需要的签名者
     * 安全考虑：确保移除后仍有足够的签名者满足安全要求
     */
    function removeSigner(address signer) 
        external 
        override 
        onlyOwner 
        validAddress(signer)
    {
        require(signers[signer], "RefundVault: not a signer");
        require(signerCount > getRequiredSignatures, "RefundVault: cannot remove required signer");
        
        signers[signer] = false;
        signerCount--;
    }
    
    /**
     * @dev 暂停合约
     * 
     * 功能概述：
     * 在紧急情况下暂停合约的所有操作，防止进一步损失
     * 
     * 实现步骤：
     * 1. 调用OpenZeppelin的_pause()函数
     * 2. 设置暂停状态标志
     * 3. 阻止所有带有whenNotPaused修饰符的操作
     * 
     * 权限要求：只允许紧急角色调用
     * 用途说明：应对安全威胁或系统异常的紧急停机
     * 安全考虑：只有授权的紧急角色可以执行，防止滥用
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     * 
     * 功能概述：
     * 解除合约暂停状态，恢复正常操作
     * 
     * 实现步骤：
     * 1. 调用OpenZeppelin的_unpause()函数
     * 2. 清除暂停状态标志
     * 3. 允许所有操作恢复正常执行
     * 
     * 权限要求：只允许紧急角色调用
     * 用途说明：问题解决后恢复系统正常运行
     * 安全考虑：只有授权的紧急角色可以恢复，确保安全性
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    // ============ 查询功能 ============
    
    /**
     * @dev 获取存款信息
     * @param depositor 存款人地址
     * @return amount 存款金额
     * @return timestamp 存款时间戳
     * @return refunded 是否已退款
     * @return refundAmount 退款金额
     * 
     * 功能概述：
     * 查询指定地址的存款详细信息
     * 
     * 实现步骤：
     * 1. 从存储中获取存款记录
     * 2. 返回存款的所有相关信息
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询用户存款和退款状态
     * 安全考虑：只读操作，无安全风险
     */
    function getDeposit(address depositor) 
        external 
        view 
        override 
        returns (uint256 amount, uint256 timestamp, bool refunded, uint256 refundAmount) 
    {
        Deposit memory depositInfo = deposits[depositor];
        return (depositInfo.amount, depositInfo.timestamp, depositInfo.refunded, depositInfo.refundAmount);
    }
    
    /**
     * @dev 检查是否可以退款
     * @param depositor 存款人地址
     * @return 是否可以退款
     * 
     * 功能概述：
     * 检查指定用户是否符合退款条件
     * 
     * 实现步骤：
     * 1. 检查合约状态是否为REFUNDING
     * 2. 检查用户是否未曾退款
     * 3. 检查用户是否有存款
     * 4. 返回综合判断结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：退款前的资格检查
     * 安全考虑：只读操作，无安全风险
     */
    function canRefund(address depositor) external view override returns (bool) {
        return state == VaultState.REFUNDING && 
               !deposits[depositor].refunded && 
               deposits[depositor].amount > 0;
    }
    
    /**
     * @dev 获取退款批次信息
     * @param batchId 批次ID
     * @return totalAmount 批次总金额
     * @return userCount 批次用户数量
     * @return timestamp 批次时间戳
     * @return completed 批次是否完成
     * 
     * 功能概述：
     * 查询指定批次的退款统计信息
     * 
     * 实现步骤：
     * 1. 从存储中获取批次记录
     * 2. 返回批次的所有相关信息
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询批量退款的执行情况
     * 安全考虑：只读操作，无安全风险
     */
    function getRefundBatch(uint256 batchId) 
        external 
        view 
        override 
        returns (uint256 totalAmount, uint256 userCount, uint256 timestamp, bool completed) 
    {
        RefundBatch memory batch = refundBatches[batchId];
        return (batch.totalAmount, batch.userCount, batch.timestamp, batch.completed);
    }
    
    /**
     * @dev 检查是否应该启用退款
     * @return 是否应该启用退款
     * 
     * 功能概述：
     * 检查众筹是否失败且符合启用退款的条件
     * 
     * 实现步骤：
     * 1. 获取众筹统计和配置信息
     * 2. 检查是否未达到软顶
     * 3. 检查是否超过众筹结束时间
     * 4. 返回综合判断结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：在启用退款前验证条件
     * 安全考虑：使用try-catch处理外部调用异常
     */
    function shouldEnableRefunds() public view override returns (bool) {
        try ICrowdsale(getCrowdsale).getCrowdsaleStats() returns (ICrowdsale.CrowdsaleStats memory stats) {
            try ICrowdsale(getCrowdsale).getCrowdsaleConfig() returns (ICrowdsale.CrowdsaleConfig memory config) {
                // 检查是否未达到软顶
                if (stats.totalRaised >= config.softCap) {
                    return false;
                }
                
                // 检查是否超过众筹结束时间
                if (block.timestamp <= config.publicSaleEndTime) {
                    return false;
                }
                
                return true;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }
    
    /**
     * @dev 检查是否可以释放资金
     * @return 是否可以释放资金
     * 
     * 功能概述：
     * 检查众筹是否成功且符合释放资金的条件
     * 
     * 实现步骤：
     * 1. 获取众筹统计和配置信息
     * 2. 检查是否达到软顶目标
     * 3. 返回判断结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：在释放资金前验证条件
     * 安全考虑：使用try-catch处理外部调用异常
     */
    function canRelease() public view override returns (bool) {
        try ICrowdsale(getCrowdsale).getCrowdsaleStats() returns (ICrowdsale.CrowdsaleStats memory stats) {
            try ICrowdsale(getCrowdsale).getCrowdsaleConfig() returns (ICrowdsale.CrowdsaleConfig memory config) {
                // 必须达到软顶
                return stats.totalRaised >= config.softCap;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }
    
    /**
     * @dev 获取签名者状态
     * @param signer 签名者地址
     * @return 是否为有效签名者
     * 
     * 功能概述：
     * 检查指定地址是否为授权的签名者
     * 
     * 实现步骤：
     * 1. 查询签名者映射
     * 2. 返回授权状态
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：验证签名者身份
     * 安全考虑：只读操作，无安全风险
     */
    function isSigner(address signer) external view override returns (bool) {
        return signers[signer];
    }
    
    /**
     * @dev 获取操作签名数量
     * @param operation 操作的哈希标识
     * @return 当前签名数量
     * 
     * 功能概述：
     * 查询指定操作已收集的签名数量
     * 
     * 实现步骤：
     * 1. 查询签名计数映射
     * 2. 返回当前签名数量
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：监控多重签名进度
     * 安全考虑：只读操作，无安全风险
     */
    function getSignatureCount(bytes32 operation) external view override returns (uint256) {
        return signatureCount[operation];
    }
    
    // ============ 接收ETH ============
    
    /**
     * @dev 接收ETH（仅允许众筹合约调用deposit）
     * 
     * 功能概述：
     * 拒绝直接向合约发送ETH，强制使用deposit函数进行资金存入
     * 
     * 实现步骤：
     * 1. 直接回滚交易
     * 2. 提供明确的错误信息
     * 
     * 权限要求：无，但会拒绝所有直接转账
     * 用途说明：防止意外的ETH转入，确保资金管理的规范性
     * 安全考虑：强制使用受控的deposit接口，防止资金管理混乱
     */
    receive() external payable {
        revert("RefundVault: use deposit function");
    }
    
    /**
     * @dev 回退函数
     * 
     * 功能概述：
     * 处理调用不存在函数的情况，拒绝所有未定义的函数调用
     * 
     * 实现步骤：
     * 1. 直接回滚交易
     * 2. 提供明确的错误信息
     * 
     * 权限要求：无，但会拒绝所有未定义的调用
     * 用途说明：防止意外的函数调用，提供清晰的错误反馈
     * 安全考虑：拒绝未知调用，防止潜在的攻击向量
     */
    fallback() external payable {
        revert("RefundVault: function not found");
    }
}
