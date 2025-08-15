// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITokenVesting
 * @dev 代币释放合约接口定义
 * @author Crowdsale Platform Team
 */
interface ITokenVesting {
    
    // ============ 枚举定义 ============
    
    /**
     * @dev 释放策略类型
     */
    enum VestingType {
        LINEAR,        // 线性释放
        CLIFF,         // 悬崖期释放
        STEPPED,       // 阶梯式释放
        MILESTONE,     // 里程碑释放
        CUSTOM         // 自定义释放
    }
    
    // ============ 结构体定义 ============
    
    /**
     * @dev 释放计划结构
     */
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
    
    /**
     * @dev 阶梯式释放步骤
     */
    struct VestingStep {
        uint256 timestamp;     // 释放时间
        uint256 percentage;    // 释放比例 (basis points)
        bool released;         // 是否已释放
    }
    
    /**
     * @dev 里程碑结构
     */
    struct Milestone {
        string description;    // 里程碑描述
        uint256 percentage;    // 释放比例 (basis points)
        bool achieved;         // 是否达成
        uint256 achievedTime;  // 达成时间
    }
    
    // ============ 事件定义 ============
    
    /**
     * @dev 创建释放计划事件
     */
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 totalAmount,
        VestingType vestingType,
        uint256 startTime
    );
    
    /**
     * @dev 代币释放事件
     */
    event TokensReleased(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev 释放计划撤销事件
     */
    event VestingRevoked(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 unvestedAmount,
        uint256 timestamp
    );
    
    /**
     * @dev 里程碑达成事件
     */
    event MilestoneAchieved(
        uint256 indexed scheduleId,
        uint256 milestoneIndex,
        uint256 releasedAmount,
        uint256 timestamp
    );
    
    /**
     * @dev 批量释放事件
     */
    event BatchReleaseProcessed(
        address indexed operator,
        uint256 scheduleCount,
        uint256 totalAmount,
        uint256 timestamp
    );
    
    // ============ 核心功能接口 ============
    
    /**
     * @dev 创建释放计划
     * @param beneficiary 受益人地址
     * @param totalAmount 总释放数量
     * @param startTime 开始时间
     * @param cliffDuration 悬崖期时长
     * @param vestingDuration 释放期时长
     * @param vestingType 释放类型
     * @param revocable 是否可撤销
     * @return scheduleId 释放计划ID
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        VestingType vestingType,
        bool revocable
    ) external returns (uint256 scheduleId);
    
    /**
     * @dev 释放代币
     * @param scheduleId 释放计划ID
     */
    function release(uint256 scheduleId) external;
    
    /**
     * @dev 批量释放代币
     * @param scheduleIds 释放计划ID数组
     */
    function batchRelease(uint256[] calldata scheduleIds) external;
    
    /**
     * @dev 撤销释放计划
     * @param scheduleId 释放计划ID
     */
    function revokeVesting(uint256 scheduleId) external;
    
    // ============ 查询功能接口 ============
    
    /**
     * @dev 获取释放计划详情
     * @param scheduleId 释放计划ID
     * @return beneficiary 受益人地址
     * @return totalAmount 总释放数量
     * @return startTime 开始时间
     * @return cliffDuration 悬崖期时长
     * @return vestingDuration 释放期时长
     * @return releasedAmount 已释放数量
     * @return vestingType 释放类型
     * @return revocable 是否可撤销
     * @return revoked 是否已撤销
     */
    function getVestingSchedule(uint256 scheduleId) 
        external 
        view 
        returns (
            address beneficiary,
            uint256 totalAmount,
            uint256 startTime,
            uint256 cliffDuration,
            uint256 vestingDuration,
            uint256 releasedAmount,
            VestingType vestingType,
            bool revocable,
            bool revoked
        );
    
    /**
     * @dev 获取可释放数量
     * @param scheduleId 释放计划ID
     * @return 可释放的代币数量
     */
    function getReleasableAmount(uint256 scheduleId) external view returns (uint256);
    
    /**
     * @dev 获取已释放数量
     * @param scheduleId 释放计划ID
     * @return 已释放的代币数量
     */
    function getVestedAmount(uint256 scheduleId) external view returns (uint256);
    
    /**
     * @dev 获取受益人的所有释放计划
     * @param beneficiary 受益人地址
     * @return 释放计划ID数组
     */
    function getBeneficiarySchedules(address beneficiary) 
        external 
        view 
        returns (uint256[] memory);
    
    /**
     * @dev 获取总释放数量
     * @return 总释放代币数量
     */
    function getTotalVestingAmount() external view returns (uint256);
    
    /**
     * @dev 获取总已释放数量
     * @return 总已释放代币数量
     */
    function getTotalReleasedAmount() external view returns (uint256);
    
    /**
     * @dev 获取受益人总释放数量
     * @param beneficiary 受益人地址
     * @return 该受益人的总释放数量
     */
    function getBeneficiaryTotalAmount(address beneficiary) external view returns (uint256);
    
    /**
     * @dev 获取受益人已释放数量
     * @param beneficiary 受益人地址
     * @return 该受益人的已释放数量
     */
    function getBeneficiaryReleasedAmount(address beneficiary) external view returns (uint256);
    
    // ============ 管理功能接口 ============
    
    /**
     * @dev 添加里程碑
     * @param scheduleId 释放计划ID
     * @param description 里程碑描述
     * @param percentage 释放比例 (basis points)
     */
    function addMilestone(
        uint256 scheduleId,
        string calldata description,
        uint256 percentage
    ) external;
    
    /**
     * @dev 标记里程碑完成
     * @param scheduleId 释放计划ID
     * @param milestoneIndex 里程碑索引
     */
    function achieveMilestone(uint256 scheduleId, uint256 milestoneIndex) external;
    
    /**
     * @dev 获取里程碑信息
     * @param scheduleId 释放计划ID
     * @param milestoneIndex 里程碑索引
     * @return description 描述
     * @return percentage 释放比例
     * @return achieved 是否达成
     * @return achievedTime 达成时间
     */
    function getMilestone(uint256 scheduleId, uint256 milestoneIndex)
        external
        view
        returns (
            string memory description,
            uint256 percentage,
            bool achieved,
            uint256 achievedTime
        );
    
    /**
     * @dev 获取阶梯式释放步骤
     * @param scheduleId 释放计划ID
     * @param stepIndex 步骤索引
     * @return timestamp 释放时间
     * @return percentage 释放比例
     * @return released 是否已释放
     */
    function getVestingStep(uint256 scheduleId, uint256 stepIndex)
        external
        view
        returns (
            uint256 timestamp,
            uint256 percentage,
            bool released
        );
}
