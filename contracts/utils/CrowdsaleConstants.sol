// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CrowdsaleConstants
 * @dev 众筹合约常量定义
 * @author CrowdsaleTeam
 */
library CrowdsaleConstants {
    
    // ============ Role Constants ============
    
    /// @dev 众筹管理员角色
    bytes32 public constant CROWDSALE_ADMIN_ROLE = keccak256("CROWDSALE_ADMIN_ROLE");
    
    /// @dev 众筹操作员角色
    bytes32 public constant CROWDSALE_OPERATOR_ROLE = keccak256("CROWDSALE_OPERATOR_ROLE");
    
    /// @dev 紧急控制角色
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // ============ Time Constants ============
    
    /// @dev 最小众筹持续时间 (1天)
    uint256 public constant MIN_CROWDSALE_DURATION = 1 days;
    
    /// @dev 最大众筹持续时间 (90天)
    uint256 public constant MAX_CROWDSALE_DURATION = 90 days;
    
    /// @dev 预售最小持续时间 (1小时)
    uint256 public constant MIN_PRESALE_DURATION = 1 hours;
    
    /// @dev 公售最小持续时间 (1小时)
    uint256 public constant MIN_PUBLIC_SALE_DURATION = 1 hours;
    
    /// @dev 阶段间最小间隔时间 (10分钟)
    uint256 public constant MIN_PHASE_INTERVAL = 10 minutes;
    
    // ============ Financial Constants ============
    
    /// @dev 最小软顶金额 (0.1 ETH)
    uint256 public constant MIN_SOFT_CAP = 0.1 ether;
    
    /// @dev 最小硬顶金额 (1 ETH)
    uint256 public constant MIN_HARD_CAP = 1 ether;
    
    /// @dev 最大硬顶金额 (10000 ETH)
    uint256 public constant MAX_HARD_CAP = 10000 ether;
    
    /// @dev 最小购买金额 (0.001 ETH)
    uint256 public constant MIN_PURCHASE_AMOUNT = 0.001 ether;
    
    /// @dev 默认最大购买金额 (100 ETH)
    uint256 public constant DEFAULT_MAX_PURCHASE = 100 ether;
    
    /// @dev 软顶硬顶最小比例 (软顶至少是硬顶的10%)
    uint256 public constant MIN_SOFT_CAP_RATIO = 10; // 10%
    
    /// @dev 百分比基数
    uint256 public constant PERCENTAGE_BASE = 100;
    
    // ============ Gas Optimization Constants ============
    
    /// @dev 批量操作最大数量
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    /// @dev 状态更新批量大小
    uint256 public constant STATE_UPDATE_BATCH_SIZE = 50;
    
    // ============ Security Constants ============
    
    /// @dev 紧急暂停最大持续时间 (7天)
    uint256 public constant MAX_EMERGENCY_PAUSE_DURATION = 7 days;
    
    /// @dev 配置更新冷却时间 (1小时)
    uint256 public constant CONFIG_UPDATE_COOLDOWN = 1 hours;
    
    /// @dev 最大重试次数
    uint256 public constant MAX_RETRY_COUNT = 3;
    
    // ============ Error Messages ============
    
    /// @dev 通用错误消息
    string public constant ERROR_INVALID_ADDRESS = "CrowdsaleConstants: invalid address";
    string public constant ERROR_INVALID_AMOUNT = "CrowdsaleConstants: invalid amount";
    string public constant ERROR_INVALID_TIME = "CrowdsaleConstants: invalid time";
    string public constant ERROR_INVALID_PHASE = "CrowdsaleConstants: invalid phase";
    string public constant ERROR_UNAUTHORIZED = "CrowdsaleConstants: unauthorized";
    string public constant ERROR_PAUSED = "CrowdsaleConstants: contract is paused";
    string public constant ERROR_NOT_PAUSED = "CrowdsaleConstants: contract is not paused";
    
    /// @dev 时间相关错误
    string public constant ERROR_TIME_WINDOW_CLOSED = "CrowdsaleConstants: time window closed";
    string public constant ERROR_TIME_WINDOW_NOT_OPEN = "CrowdsaleConstants: time window not open";
    string public constant ERROR_INVALID_TIME_SEQUENCE = "CrowdsaleConstants: invalid time sequence";
    string public constant ERROR_DURATION_TOO_SHORT = "CrowdsaleConstants: duration too short";
    string public constant ERROR_DURATION_TOO_LONG = "CrowdsaleConstants: duration too long";
    
    /// @dev 资金相关错误
    string public constant ERROR_SOFT_CAP_TOO_LOW = "CrowdsaleConstants: soft cap too low";
    string public constant ERROR_HARD_CAP_TOO_LOW = "CrowdsaleConstants: hard cap too low";
    string public constant ERROR_HARD_CAP_TOO_HIGH = "CrowdsaleConstants: hard cap too high";
    string public constant ERROR_SOFT_CAP_RATIO_TOO_LOW = "CrowdsaleConstants: soft cap ratio too low";
    string public constant ERROR_HARD_CAP_REACHED = "CrowdsaleConstants: hard cap reached";
    string public constant ERROR_SOFT_CAP_NOT_REACHED = "CrowdsaleConstants: soft cap not reached";
    
    /// @dev 购买相关错误
    string public constant ERROR_PURCHASE_TOO_SMALL = "CrowdsaleConstants: purchase amount too small";
    string public constant ERROR_PURCHASE_TOO_LARGE = "CrowdsaleConstants: purchase amount too large";
    string public constant ERROR_INSUFFICIENT_FUNDS = "CrowdsaleConstants: insufficient funds";
    string public constant ERROR_PURCHASE_LIMIT_EXCEEDED = "CrowdsaleConstants: purchase limit exceeded";
    
    /// @dev 状态相关错误
    string public constant ERROR_INVALID_STATE_TRANSITION = "CrowdsaleConstants: invalid state transition";
    string public constant ERROR_CROWDSALE_NOT_STARTED = "CrowdsaleConstants: crowdsale not started";
    string public constant ERROR_CROWDSALE_ENDED = "CrowdsaleConstants: crowdsale ended";
    string public constant ERROR_CROWDSALE_FINALIZED = "CrowdsaleConstants: crowdsale finalized";
    
    // ============ Success Messages ============
    
    /// @dev 成功消息
    string public constant SUCCESS_PHASE_CHANGED = "CrowdsaleConstants: phase changed successfully";
    string public constant SUCCESS_CONFIG_UPDATED = "CrowdsaleConstants: config updated successfully";
    string public constant SUCCESS_EMERGENCY_PAUSED = "CrowdsaleConstants: emergency paused successfully";
    string public constant SUCCESS_EMERGENCY_RESUMED = "CrowdsaleConstants: emergency resumed successfully";
    
    // ============ Utility Functions ============
    
    /**
     * @dev 验证时间序列是否有效
     */
    function validateTimeSequence(
        uint256 _presaleStart,
        uint256 _presaleEnd,
        uint256 _publicSaleStart,
        uint256 _publicSaleEnd
    ) internal pure returns (bool) {
        return _presaleStart < _presaleEnd &&
               _presaleEnd + MIN_PHASE_INTERVAL <= _publicSaleStart &&
               _publicSaleStart < _publicSaleEnd &&
               _presaleEnd - _presaleStart >= MIN_PRESALE_DURATION &&
               _publicSaleEnd - _publicSaleStart >= MIN_PUBLIC_SALE_DURATION &&
               _publicSaleEnd - _presaleStart <= MAX_CROWDSALE_DURATION;
    }
    
    /**
     * @dev 验证资金目标是否有效
     */
    function validateFundingTargets(
        uint256 _softCap,
        uint256 _hardCap
    ) internal pure returns (bool) {
        return _softCap >= MIN_SOFT_CAP &&
               _hardCap >= MIN_HARD_CAP &&
               _hardCap <= MAX_HARD_CAP &&
               _softCap <= _hardCap &&
               (_softCap * PERCENTAGE_BASE) / _hardCap >= MIN_SOFT_CAP_RATIO;
    }
    
    /**
     * @dev 验证购买限额是否有效
     */
    function validatePurchaseLimits(
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) internal pure returns (bool) {
        return _minPurchase >= MIN_PURCHASE_AMOUNT &&
               _maxPurchase >= _minPurchase &&
               _maxPurchase <= DEFAULT_MAX_PURCHASE;
    }
    
    /**
     * @dev 计算百分比
     */
    function calculatePercentage(
        uint256 _amount,
        uint256 _total
    ) internal pure returns (uint256) {
        if (_total == 0) return 0;
        return (_amount * PERCENTAGE_BASE) / _total;
    }
    
    /**
     * @dev 检查地址是否有效
     */
    function isValidAddress(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }
}
