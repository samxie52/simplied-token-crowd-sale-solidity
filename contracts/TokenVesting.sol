// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/ITokenVesting.sol";
import "./utils/VestingMath.sol";

/**
 * @title TokenVesting
 * @dev 代币释放合约实现
 * @author Crowdsale Platform Team
 */
contract TokenVesting is ITokenVesting, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using VestingMath for uint256;
    
    // ============ 角色定义 ============
    
    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");
    bytes32 public constant VESTING_OPERATOR_ROLE = keccak256("VESTING_OPERATOR_ROLE");
    bytes32 public constant MILESTONE_MANAGER_ROLE = keccak256("MILESTONE_MANAGER_ROLE");
    
    // ============ 常量定义 ============
    
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant MAX_SCHEDULES_PER_BENEFICIARY = 100;
    uint256 public constant BASIS_POINTS = 10000;
    
    // ============ 状态变量 ============
    
    IERC20 public immutable token;
    uint256 public nextScheduleId;
    uint256 public totalVestingAmount;
    uint256 public totalReleasedAmount;
    
    // 释放计划存储
    mapping(uint256 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256[]) public beneficiarySchedules;
    
    // 阶梯式释放数据
    mapping(uint256 => VestingStep[]) public vestingSteps;
    
    // 里程碑释放数据
    mapping(uint256 => Milestone[]) public milestones;
    
    // 统计数据
    mapping(address => uint256) public beneficiaryTotalAmount;
    mapping(address => uint256) public beneficiaryReleasedAmount;
    
    // ============ 构造函数 ============
    
    constructor(address _token, address _admin) {
        require(_token != address(0), "TokenVesting: zero token address");
        require(_admin != address(0), "TokenVesting: zero admin address");
        
        token = IERC20(_token);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VESTING_ADMIN_ROLE, _admin);
        _grantRole(VESTING_OPERATOR_ROLE, _admin);
        _grantRole(MILESTONE_MANAGER_ROLE, _admin);
    }
    
    // ============ 核心功能实现 ============
    
    /**
     * @dev 创建释放计划
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        VestingType vestingType,
        bool revocable
    ) external override onlyRole(VESTING_ADMIN_ROLE) returns (uint256 scheduleId) {
        require(beneficiary != address(0), "TokenVesting: zero beneficiary");
        require(totalAmount > 0, "TokenVesting: zero amount");
        require(startTime > 0, "TokenVesting: zero start time");
        require(vestingDuration > 0, "TokenVesting: zero vesting duration");
        require(
            beneficiarySchedules[beneficiary].length < MAX_SCHEDULES_PER_BENEFICIARY,
            "TokenVesting: too many schedules"
        );
        
        // 检查代币余额
        require(
            token.balanceOf(address(this)) >= totalVestingAmount + totalAmount,
            "TokenVesting: insufficient token balance"
        );
        
        scheduleId = nextScheduleId++;
        
        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: totalAmount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releasedAmount: 0,
            vestingType: vestingType,
            revocable: revocable,
            revoked: false
        });
        
        beneficiarySchedules[beneficiary].push(scheduleId);
        totalVestingAmount += totalAmount;
        beneficiaryTotalAmount[beneficiary] += totalAmount;
        
        // 根据释放类型初始化特殊数据
        if (vestingType == VestingType.STEPPED) {
            _initializeSteppedVesting(scheduleId, startTime, vestingDuration);
        }
        
        emit VestingScheduleCreated(beneficiary, scheduleId, totalAmount, vestingType, startTime);
    }
    
    /**
     * @dev 释放代币
     */
    function release(uint256 scheduleId) external override nonReentrant whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.beneficiary != address(0), "TokenVesting: schedule not found");
        require(!schedule.revoked, "TokenVesting: schedule revoked");
        require(
            msg.sender == schedule.beneficiary || hasRole(VESTING_OPERATOR_ROLE, msg.sender),
            "TokenVesting: not authorized"
        );
        
        uint256 releasableAmount = _getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "TokenVesting: no tokens to release");
        
        schedule.releasedAmount += releasableAmount;
        beneficiaryReleasedAmount[schedule.beneficiary] += releasableAmount;
        totalReleasedAmount += releasableAmount;
        
        token.safeTransfer(schedule.beneficiary, releasableAmount);
        
        emit TokensReleased(schedule.beneficiary, scheduleId, releasableAmount, block.timestamp);
    }
    
    /**
     * @dev 批量释放代币
     */
    function batchRelease(uint256[] calldata scheduleIds) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        require(scheduleIds.length <= MAX_BATCH_SIZE, "TokenVesting: batch too large");
        
        uint256 totalBatchAmount = 0;
        uint256 processedCount = 0;
        
        for (uint256 i = 0; i < scheduleIds.length; i++) {
            uint256 scheduleId = scheduleIds[i];
            VestingSchedule storage schedule = vestingSchedules[scheduleId];
            
            if (schedule.beneficiary == address(0) || schedule.revoked) continue;
            if (msg.sender != schedule.beneficiary && !hasRole(VESTING_OPERATOR_ROLE, msg.sender)) continue;
            
            uint256 releasableAmount = _getReleasableAmount(scheduleId);
            if (releasableAmount == 0) continue;
            
            schedule.releasedAmount += releasableAmount;
            beneficiaryReleasedAmount[schedule.beneficiary] += releasableAmount;
            totalReleasedAmount += releasableAmount;
            totalBatchAmount += releasableAmount;
            processedCount++;
            
            token.safeTransfer(schedule.beneficiary, releasableAmount);
            
            emit TokensReleased(schedule.beneficiary, scheduleId, releasableAmount, block.timestamp);
        }
        
        if (processedCount > 0) {
            emit BatchReleaseProcessed(msg.sender, processedCount, totalBatchAmount, block.timestamp);
        }
    }
    
    /**
     * @dev 撤销释放计划
     */
    function revokeVesting(uint256 scheduleId) 
        external 
        override 
        onlyRole(VESTING_ADMIN_ROLE) 
    {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.beneficiary != address(0), "TokenVesting: schedule not found");
        require(schedule.revocable, "TokenVesting: not revocable");
        require(!schedule.revoked, "TokenVesting: already revoked");
        
        uint256 vestedAmount = _getVestedAmount(scheduleId);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;
        
        schedule.revoked = true;
        totalVestingAmount -= unvestedAmount;
        beneficiaryTotalAmount[schedule.beneficiary] -= unvestedAmount;
        
        emit VestingRevoked(schedule.beneficiary, scheduleId, unvestedAmount, block.timestamp);
    }
    
    // ============ 查询功能实现 ============
    
    /**
     * @dev 获取释放计划详情
     */
    function getVestingSchedule(uint256 scheduleId) 
        external 
        view 
        override 
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
        ) 
    {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];
        return (
            schedule.beneficiary,
            schedule.totalAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.releasedAmount,
            schedule.vestingType,
            schedule.revocable,
            schedule.revoked
        );
    }
    
    /**
     * @dev 获取可释放数量
     */
    function getReleasableAmount(uint256 scheduleId) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return _getReleasableAmount(scheduleId);
    }
    
    /**
     * @dev 获取已释放数量
     */
    function getVestedAmount(uint256 scheduleId) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return _getVestedAmount(scheduleId);
    }
    
    /**
     * @dev 获取受益人的所有释放计划
     */
    function getBeneficiarySchedules(address beneficiary) 
        external 
        view 
        override 
        returns (uint256[] memory) 
    {
        return beneficiarySchedules[beneficiary];
    }
    
    /**
     * @dev 获取总释放数量
     */
    function getTotalVestingAmount() external view override returns (uint256) {
        return totalVestingAmount;
    }
    
    /**
     * @dev 获取总已释放数量
     */
    function getTotalReleasedAmount() external view override returns (uint256) {
        return totalReleasedAmount;
    }
    
    /**
     * @dev 获取受益人总释放数量
     */
    function getBeneficiaryTotalAmount(address beneficiary) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return beneficiaryTotalAmount[beneficiary];
    }
    
    /**
     * @dev 获取受益人已释放数量
     */
    function getBeneficiaryReleasedAmount(address beneficiary) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return beneficiaryReleasedAmount[beneficiary];
    }
    
    // ============ 内部函数 ============
    
    /**
     * @dev 计算可释放数量
     */
    function _getReleasableAmount(uint256 scheduleId) internal view returns (uint256) {
        return _getVestedAmount(scheduleId) - vestingSchedules[scheduleId].releasedAmount;
    }
    
    /**
     * @dev 计算已释放数量
     */
    function _getVestedAmount(uint256 scheduleId) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];
        
        if (schedule.revoked) {
            return schedule.releasedAmount;
        }
        
        if (schedule.vestingType == VestingType.LINEAR) {
            return VestingMath.calculateLinearVesting(
                schedule.totalAmount,
                schedule.startTime,
                schedule.vestingDuration,
                block.timestamp
            );
        } else if (schedule.vestingType == VestingType.CLIFF) {
            return VestingMath.calculateCliffVesting(
                schedule.totalAmount,
                schedule.startTime,
                schedule.cliffDuration,
                schedule.vestingDuration,
                block.timestamp
            );
        } else if (schedule.vestingType == VestingType.STEPPED) {
            return _calculateSteppedVesting(scheduleId);
        } else if (schedule.vestingType == VestingType.MILESTONE) {
            return _calculateMilestoneVesting(scheduleId);
        }
        
        return 0;
    }
    
    /**
     * @dev 初始化阶梯式释放
     */
    function _initializeSteppedVesting(
        uint256 scheduleId,
        uint256 startTime,
        uint256 vestingDuration
    ) internal {
        uint256 stepDuration = vestingDuration / 4;
        uint256 stepPercentage = 2500; // 25% in basis points
        
        for (uint256 i = 0; i < 4; i++) {
            vestingSteps[scheduleId].push(VestingStep({
                timestamp: startTime + (i + 1) * stepDuration,
                percentage: stepPercentage,
                released: false
            }));
        }
    }
    
    /**
     * @dev 计算阶梯式释放数量
     */
    function _calculateSteppedVesting(uint256 scheduleId) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];
        VestingStep[] memory steps = vestingSteps[scheduleId];
        
        uint256 vestedAmount = 0;
        for (uint256 i = 0; i < steps.length; i++) {
            if (block.timestamp >= steps[i].timestamp) {
                vestedAmount += (schedule.totalAmount * steps[i].percentage) / BASIS_POINTS;
            }
        }
        
        return vestedAmount;
    }
    
    /**
     * @dev 计算里程碑释放数量
     */
    function _calculateMilestoneVesting(uint256 scheduleId) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];
        Milestone[] memory milestoneList = milestones[scheduleId];
        
        uint256 vestedAmount = 0;
        for (uint256 i = 0; i < milestoneList.length; i++) {
            if (milestoneList[i].achieved) {
                vestedAmount += (schedule.totalAmount * milestoneList[i].percentage) / BASIS_POINTS;
            }
        }
        
        return vestedAmount;
    }
    
    // ============ 管理功能 ============
    
    /**
     * @dev 添加里程碑
     */
    function addMilestone(
        uint256 scheduleId,
        string calldata description,
        uint256 percentage
    ) external override onlyRole(MILESTONE_MANAGER_ROLE) {
        require(vestingSchedules[scheduleId].beneficiary != address(0), "TokenVesting: schedule not found");
        require(percentage > 0 && percentage <= BASIS_POINTS, "TokenVesting: invalid percentage");
        
        milestones[scheduleId].push(Milestone({
            description: description,
            percentage: percentage,
            achieved: false,
            achievedTime: 0
        }));
    }
    
    /**
     * @dev 标记里程碑完成
     */
    function achieveMilestone(uint256 scheduleId, uint256 milestoneIndex) 
        external 
        override
        onlyRole(MILESTONE_MANAGER_ROLE) 
    {
        require(milestoneIndex < milestones[scheduleId].length, "TokenVesting: milestone not found");
        require(!milestones[scheduleId][milestoneIndex].achieved, "TokenVesting: already achieved");
        
        milestones[scheduleId][milestoneIndex].achieved = true;
        milestones[scheduleId][milestoneIndex].achievedTime = block.timestamp;
        
        uint256 releasedAmount = (vestingSchedules[scheduleId].totalAmount * 
                                 milestones[scheduleId][milestoneIndex].percentage) / BASIS_POINTS;
        
        emit MilestoneAchieved(scheduleId, milestoneIndex, releasedAmount, block.timestamp);
    }
    
    /**
     * @dev 获取里程碑信息
     */
    function getMilestone(uint256 scheduleId, uint256 milestoneIndex)
        external
        view
        override
        returns (
            string memory description,
            uint256 percentage,
            bool achieved,
            uint256 achievedTime
        )
    {
        require(milestoneIndex < milestones[scheduleId].length, "TokenVesting: milestone not found");
        Milestone memory milestone = milestones[scheduleId][milestoneIndex];
        return (milestone.description, milestone.percentage, milestone.achieved, milestone.achievedTime);
    }
    
    /**
     * @dev 获取阶梯式释放步骤
     */
    function getVestingStep(uint256 scheduleId, uint256 stepIndex)
        external
        view
        override
        returns (
            uint256 timestamp,
            uint256 percentage,
            bool released
        )
    {
        require(stepIndex < vestingSteps[scheduleId].length, "TokenVesting: step not found");
        VestingStep memory step = vestingSteps[scheduleId][stepIndex];
        return (step.timestamp, step.percentage, step.released);
    }
    
    /**
     * @dev 暂停合约
     */
    function pause() external onlyRole(VESTING_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external onlyRole(VESTING_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev 紧急提取代币
     */
    function emergencyWithdraw(address to, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(to != address(0), "TokenVesting: zero address");
        require(amount > 0, "TokenVesting: zero amount");
        
        token.safeTransfer(to, amount);
    }
}
