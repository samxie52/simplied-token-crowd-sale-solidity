// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRefundVault
 * @dev 资金托管和退款机制接口
 * @author Crowdsale Platform Team
 */
interface IRefundVault {
    
    // ============ 枚举定义 ============
    
    /**
     * @dev 托管状态枚举
     */
    enum VaultState {
        ACTIVE,      // 活跃托管中
        REFUNDING,   // 退款进行中  
        CLOSED       // 已关闭
    }
    
    // ============ 结构体定义 ============
    
    /**
     * @dev 存款记录结构
     */
    struct Deposit {
        uint256 amount;        // 存款金额
        uint256 timestamp;     // 存款时间
        bool refunded;         // 是否已退款
        uint256 refundAmount;  // 退款金额
    }
    
    /**
     * @dev 退款批次信息
     */
    struct RefundBatch {
        uint256 batchId;       // 批次ID
        uint256 totalAmount;   // 总退款金额
        uint256 userCount;     // 用户数量
        uint256 timestamp;     // 处理时间
        bool completed;        // 是否完成
    }
    
    // ============ 事件定义 ============
    
    /**
     * @dev 资金存入事件
     */
    event Deposited(
        address indexed depositor, 
        uint256 amount, 
        uint256 timestamp
    );
    
    /**
     * @dev 退款事件
     */
    event Refunded(
        address indexed depositor, 
        uint256 amount, 
        uint256 timestamp
    );
    
    /**
     * @dev 退款失败事件
     */
    event RefundFailed(
        address indexed depositor, 
        uint256 amount, 
        string reason
    );
    
    /**
     * @dev 启用退款事件
     */
    event RefundsEnabled(uint256 timestamp);
    
    /**
     * @dev 资金释放事件
     */
    event Released(
        address indexed beneficiary, 
        uint256 amount, 
        uint256 timestamp
    );
    
    /**
     * @dev 批量退款处理事件
     */
    event BatchRefundProcessed(
        uint256 indexed batchId, 
        uint256 userCount, 
        uint256 totalAmount
    );
    
    /**
     * @dev 紧急提取事件
     */
    event EmergencyWithdraw(
        address indexed admin, 
        uint256 amount, 
        string reason
    );
    
    /**
     * @dev 多重签名事件
     */
    event SignatureAdded(
        bytes32 indexed operation,
        address indexed signer,
        uint256 currentCount
    );
    
    /**
     * @dev 受益人更新事件
     */
    event BeneficiaryUpdated(
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );
    
    // ============ 核心功能函数 ============
    
    /**
     * @dev 存入资金
     * @param depositor 存款人地址
     */
    function deposit(address depositor) external payable;
    
    /**
     * @dev 单个用户退款
     * @param depositor 存款人地址
     */
    function refund(address depositor) external;
    
    /**
     * @dev 批量退款
     * @param depositors 存款人地址数组
     */
    function batchRefund(address[] calldata depositors) external;
    
    /**
     * @dev 启用退款模式
     */
    function enableRefunds() external;
    
    /**
     * @dev 释放资金给受益人
     */
    function release() external;
    
    /**
     * @dev 紧急提取资金
     * @param reason 提取原因
     */
    function emergencyWithdraw(string calldata reason) external;
    
    // ============ 多重签名功能 ============
    
    /**
     * @dev 添加操作签名
     * @param operation 操作哈希
     */
    function addSignature(bytes32 operation) external;
    
    /**
     * @dev 重置操作签名
     * @param operation 操作哈希
     */
    function resetSignatures(bytes32 operation) external;
    
    // ============ 管理功能 ============
    
    /**
     * @dev 更新受益人地址
     * @param newBeneficiary 新受益人地址
     */
    function updateBeneficiary(address newBeneficiary) external;
    
    /**
     * @dev 添加签名者
     * @param signer 签名者地址
     */
    function addSigner(address signer) external;
    
    /**
     * @dev 移除签名者
     * @param signer 签名者地址
     */
    function removeSigner(address signer) external;
    
    // ============ 查询功能 ============
    
    /**
     * @dev 获取当前状态
     */
    function state() external view returns (VaultState);
    
    /**
     * @dev 获取存款信息
     * @param depositor 存款人地址
     */
    function getDeposit(address depositor) external view returns (
        uint256 amount, 
        uint256 timestamp,
        bool refunded,
        uint256 refundAmount
    );
    
    /**
     * @dev 检查是否可以退款
     * @param depositor 存款人地址
     */
    function canRefund(address depositor) external view returns (bool);
    
    /**
     * @dev 获取总存款金额
     */
    function getTotalDeposited() external view returns (uint256);
    
    /**
     * @dev 获取总退款金额
     */
    function getTotalRefunded() external view returns (uint256);
    
    /**
     * @dev 获取退款批次信息
     * @param batchId 批次ID
     */
    function getRefundBatch(uint256 batchId) external view returns (
        uint256 totalAmount,
        uint256 userCount,
        uint256 timestamp,
        bool completed
    );
    
    /**
     * @dev 检查是否应该启用退款
     */
    function shouldEnableRefunds() external view returns (bool);
    
    /**
     * @dev 检查是否可以释放资金
     */
    function canRelease() external view returns (bool);
    
    /**
     * @dev 获取签名者状态
     * @param signer 签名者地址
     */
    function isSigner(address signer) external view returns (bool);
    
    /**
     * @dev 获取操作签名数量
     * @param operation 操作哈希
     */
    function getSignatureCount(bytes32 operation) external view returns (uint256);
    
    /**
     * @dev 获取所需签名数量
     */
    function getRequiredSignatures() external view returns (uint256);
    
    /**
     * @dev 获取受益人地址
     */
    function getBeneficiary() external view returns (address);
    
    /**
     * @dev 获取众筹合约地址
     */
    function getCrowdsale() external view returns (address);
}
