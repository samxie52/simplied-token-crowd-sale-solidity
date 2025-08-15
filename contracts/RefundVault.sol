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
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    // ============ 查询功能 ============
    
    /**
     * @dev 获取存款信息
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
     */
    function canRefund(address depositor) external view override returns (bool) {
        return state == VaultState.REFUNDING && 
               !deposits[depositor].refunded && 
               deposits[depositor].amount > 0;
    }
    
    /**
     * @dev 获取退款批次信息
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
     */
    function isSigner(address signer) external view override returns (bool) {
        return signers[signer];
    }
    
    /**
     * @dev 获取操作签名数量
     */
    function getSignatureCount(bytes32 operation) external view override returns (uint256) {
        return signatureCount[operation];
    }
    
    // ============ 接收ETH ============
    
    /**
     * @dev 接收ETH（仅允许众筹合约调用deposit）
     */
    receive() external payable {
        revert("RefundVault: use deposit function");
    }
    
    /**
     * @dev 回退函数
     */
    fallback() external payable {
        revert("RefundVault: function not found");
    }
}
