// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICrowdsale
 * @dev 众筹合约核心接口定义
 * @author CrowdsaleTeam
 */
interface ICrowdsale {
    
    /**
     * @dev 众筹阶段枚举
     */
    enum CrowdsalePhase {
        PENDING,        // 0: 待开始
        PRESALE,        // 1: 预售阶段
        PUBLIC_SALE,    // 2: 公售阶段
        FINALIZED       // 3: 已结束
    }
    
    /**
     * @dev 众筹配置结构
     */
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
    
    /**
     * @dev 众筹统计结构
     */
    struct CrowdsaleStats {
        uint256 totalRaised;         // 总筹资金额
        uint256 totalTokensSold;     // 总售出代币数量
        uint256 participantCount;    // 参与人数
        uint256 presaleRaised;       // 预售筹资金额
        uint256 publicSaleRaised;    // 公售筹资金额
    }
    
    // ============ Events ============
    
    /**
     * @dev 众筹阶段变更事件
     */
    event PhaseChanged(
        CrowdsalePhase indexed previousPhase,
        CrowdsalePhase indexed newPhase,
        uint256 timestamp,
        address indexed changedBy
    );
    
    /**
     * @dev 众筹配置更新事件
     */
    event ConfigUpdated(
        CrowdsaleConfig config,
        address indexed updatedBy
    );
    
    /**
     * @dev 众筹目标达成事件
     */
    event CapReached(
        string indexed capType, // "soft" or "hard"
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev 紧急暂停事件
     */
    event EmergencyAction(
        string indexed action, // "pause" or "resume"
        address indexed executor,
        uint256 timestamp,
        string reason
    );
    
    // ============ View Functions ============
    
    /**
     * @dev 获取当前众筹阶段
     */
    function getCurrentPhase() external view returns (CrowdsalePhase);
    
    /**
     * @dev 获取众筹配置
     */
    function getCrowdsaleConfig() external view returns (CrowdsaleConfig memory);
    
    /**
     * @dev 获取众筹统计信息
     */
    function getCrowdsaleStats() external view returns (CrowdsaleStats memory);
    
    /**
     * @dev 检查是否在有效时间窗口内
     */
    function isInValidTimeWindow() external view returns (bool);
    
    /**
     * @dev 检查软顶是否达成
     */
    function isSoftCapReached() external view returns (bool);
    
    /**
     * @dev 检查硬顶是否达成
     */
    function isHardCapReached() external view returns (bool);
    
    /**
     * @dev 获取当前筹资进度百分比 (基于硬顶)
     */
    function getFundingProgress() external view returns (uint256);
    
    /**
     * @dev 获取剩余可筹资金额
     */
    function getRemainingFunding() external view returns (uint256);
    
    // ============ State Management Functions ============
    
    /**
     * @dev 开始预售阶段
     */
    function startPresale() external;
    
    /**
     * @dev 开始公售阶段
     */
    function startPublicSale() external;
    
    /**
     * @dev 结束众筹
     */
    function finalizeCrowdsale() external;
    
    /**
     * @dev 紧急暂停众筹
     */
    function emergencyPause(string calldata reason) external;
    
    /**
     * @dev 恢复众筹
     */
    function emergencyResume(string calldata reason) external;
    
    // ============ Configuration Functions ============
    
    /**
     * @dev 更新众筹配置
     */
    function updateConfig(CrowdsaleConfig calldata _config) external;
    
    /**
     * @dev 更新时间配置
     */
    function updateTimeConfig(
        uint256 _presaleStartTime,
        uint256 _presaleEndTime,
        uint256 _publicSaleStartTime,
        uint256 _publicSaleEndTime
    ) external;
    
    /**
     * @dev 更新资金目标
     */
    function updateFundingTargets(
        uint256 _softCap,
        uint256 _hardCap
    ) external;
    
    /**
     * @dev 更新购买限额
     */
    function updatePurchaseLimits(
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) external;
}
