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
     * @param beneficiary 受益人地址
     * @param totalAmount 总释放代币数量
     * @param startTime 释放开始时间
     * @param cliffDuration 悬崖期时长（秒）
     * @param vestingDuration 总释放期时长（秒）
     * @param vestingType 释放类型（线性、悬崖、阶梯、里程碑）
     * @param revocable 是否可撤销
     * @return scheduleId 释放计划ID
     * 
     * 功能概述：
     * 为指定受益人创建代币释放计划，支持多种释放策略
     * 
     * 实现步骤：
     * 1. 验证输入参数的有效性
     * 2. 检查受益人释放计划数量限制
     * 3. 验证合约代币余额充足
     * 4. 创建释放计划并分配唯一ID
     * 5. 更新相关统计数据
     * 6. 根据释放类型初始化特殊数据
     * 7. 发出VestingScheduleCreated事件
     * 
     * 权限要求：只允许VESTING_ADMIN_ROLE角色调用
     * 用途说明：为众筹参与者或团队成员创建代币锁定释放计划
     * 安全考虑：限制每个受益人的计划数量，验证代币余额，严格参数校验
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
     * @param scheduleId 释放计划ID
     * 
     * 功能概述：
     * 根据释放计划释放已到期的代币给受益人
     * 
     * 实现步骤：
     * 1. 验证释放计划存在且未被撤销
     * 2. 检查调用者权限（受益人或操作员）
     * 3. 计算当前可释放的代币数量
     * 4. 更新释放记录和统计数据
     * 5. 转移代币给受益人
     * 6. 发出TokensReleased事件
     * 
     * 权限要求：受益人本人或VESTING_OPERATOR_ROLE角色可调用
     * 用途说明：受益人主动释放到期代币或操作员代为释放
     * 安全考虑：使用ReentrancyGuard防重入，严格权限控制，安全代币转移
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
     * @param scheduleIds 释放计划ID数组
     * 
     * 功能概述：
     * 批量处理多个释放计划的代币释放，提高操作效率
     * 
     * 实现步骤：
     * 1. 验证批量大小限制
     * 2. 遍历释放计划ID数组
     * 3. 对每个有效计划执行释放操作
     * 4. 跳过无效或无可释放代币的计划
     * 5. 累计批量释放统计数据
     * 6. 发出BatchReleaseProcessed事件
     * 
     * 权限要求：受益人本人或VESTING_OPERATOR_ROLE角色可调用
     * 用途说明：批量处理多个到期的释放计划，节省Gas成本
     * 安全考虑：限制批量大小防止Gas耗尽，跳过失败项防止整体回滚
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
     * @param scheduleId 释放计划ID
     * 
     * 功能概述：
     * 撤销可撤销的释放计划，回收未释放的代币
     * 
     * 实现步骤：
     * 1. 验证释放计划存在且可撤销
     * 2. 检查计划未曾被撤销
     * 3. 计算已释放和未释放的代币数量
     * 4. 标记计划为已撤销状态
     * 5. 更新相关统计数据
     * 6. 发出VestingRevoked事件
     * 
     * 权限要求：只允许VESTING_ADMIN_ROLE角色调用
     * 用途说明：在特殊情况下撤销员工或合作伙伴的释放计划
     * 安全考虑：只能撤销标记为可撤销的计划，保护已释放的代币
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
     * @param scheduleId 释放计划ID
     * @return beneficiary 受益人地址
     * @return totalAmount 总释放数量
     * @return startTime 开始时间
     * @return cliffDuration 悬崖期时长
     * @return vestingDuration 总释放期时长
     * @return releasedAmount 已释放数量
     * @return vestingType 释放类型
     * @return revocable 是否可撤销
     * @return revoked 是否已撤销
     * 
     * 功能概述：
     * 查询指定释放计划的完整详细信息
     * 
     * 实现步骤：
     * 1. 从存储中获取释放计划数据
     * 2. 返回计划的所有关键信息
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询释放计划的配置和状态信息
     * 安全考虑：只读操作，无安全风险
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
     * @param scheduleId 释放计划ID
     * @return 当前可释放的代币数量
     * 
     * 功能概述：
     * 计算指定释放计划当前可释放的代币数量
     * 
     * 实现步骤：
     * 1. 验证释放计划存在且未被撤销
     * 2. 调用内部计算函数获取可释放数量
     * 3. 返回计算结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询当前时间点可释放的代币数量
     * 安全考虑：只读操作，无安全风险
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
     * @param scheduleId 释放计划ID
     * @return 已释放的代币数量
     * 
     * 功能概述：
     * 计算指定释放计划已经释放的代币数量
     * 
     * 实现步骤：
     * 1. 调用内部计算函数获取已释放数量
     * 2. 返回计算结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询累计已释放的代币数量
     * 安全考虑：只读操作，无安全风险
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
     * @param beneficiary 受益人地址
     * @return 受益人的所有释放计划ID数组
     * 
     * 功能概述：
     * 查询指定受益人的所有释放计划ID列表
     * 
     * 实现步骤：
     * 1. 从存储中获取受益人的计划ID数组
     * 2. 返回完整的ID列表
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询受益人的所有释放计划，用于前端展示
     * 安全考虑：只读操作，无安全风险
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
     * @return 合约中总的代币释放数量
     * 
     * 功能概述：
     * 查询合约管理的所有释放计划的代币总数量
     * 
     * 实现步骤：
     * 1. 返回全局统计的总释放数量
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询合约管理的代币总量
     * 安全考虑：只读操作，无安全风险
     */
    function getTotalVestingAmount() external view override returns (uint256) {
        return totalVestingAmount;
    }
    
    /**
     * @dev 获取总已释放数量
     * @return 合约中总的已释放代币数量
     * 
     * 功能概述：
     * 查询合约中所有释放计划累计已释放的代币总数量
     * 
     * 实现步骤：
     * 1. 返回全局统计的总已释放数量
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询合约累计释放的代币总量
     * 安全考虑：只读操作，无安全风险
     */
    function getTotalReleasedAmount() external view override returns (uint256) {
        return totalReleasedAmount;
    }
    
    /**
     * @dev 获取受益人总释放数量
     * @param beneficiary 受益人地址
     * @return 受益人的总释放代币数量
     * 
     * 功能概述：
     * 查询指定受益人所有释放计划的代币总数量
     * 
     * 实现步骤：
     * 1. 从存储中获取受益人的总释放数量
     * 2. 返回统计结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询受益人的代币总量统计
     * 安全考虑：只读操作，无安全风险
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
     * @param beneficiary 受益人地址
     * @return 受益人的已释放代币数量
     * 
     * 功能概述：
     * 查询指定受益人所有释放计划累计已释放的代币数量
     * 
     * 实现步骤：
     * 1. 从存储中获取受益人的已释放数量
     * 2. 返回统计结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询受益人的累计已释放代币数量
     * 安全考虑：只读操作，无安全风险
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
     * @param scheduleId 释放计划ID
     * @param description 里程碑描述
     * @param percentage 释放百分比（基点表示，10000=100%）
     * 
     * 功能概述：
     * 为里程碑类型的释放计划添加新的释放里程碑
     * 
     * 实现步骤：
     * 1. 验证释放计划存在且为里程碑类型
     * 2. 验证里程碑参数的有效性
     * 3. 检查里程碑数量限制
     * 4. 添加里程碑到计划中
     * 5. 发出MilestoneAdded事件
     * 
     * 权限要求：只允许MILESTONE_MANAGER_ROLE角色调用
     * 用途说明：为项目里程碑型释放计划设置关键节点
     * 安全考虑：验证里程碑时间合理性，限制里程碑数量
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
     * @param scheduleId 释放计划ID
     * @param milestoneIndex 里程碑索引
     * 
     * 功能概述：
     * 标记指定里程碑为已完成，触发相应的代币释放
     * 
     * 实现步骤：
     * 1. 验证释放计划存在且为里程碑类型
     * 2. 验证里程碑索引有效
     * 3. 检查里程碑未曾被完成
     * 4. 标记里程碑为已完成状态
     * 5. 记录完成时间
     * 6. 计算释放数量并发出MilestoneAchieved事件
     * 
     * 权限要求：只允许MILESTONE_MANAGER_ROLE角色调用
     * 用途说明：项目达到特定里程碑时触发代币释放
     * 安全考虑：防止重复完成，严格权限控制
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
     * @param scheduleId 释放计划ID
     * @param milestoneIndex 里程碑索引
     * @return description 里程碑描述
     * @return percentage 释放百分比
     * @return achieved 是否已完成
     * @return achievedTime 完成时间
     * 
     * 功能概述：
     * 查询指定释放计划中特定里程碑的详细信息
     * 
     * 实现步骤：
     * 1. 验证里程碑索引有效
     * 2. 从存储中获取里程碑数据
     * 3. 返回里程碑的完整信息
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询里程碑的设置和完成状态
     * 安全考虑：只读操作，无安全风险
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
     * @param scheduleId 释放计划ID
     * @param stepIndex 步骤索引
     * @return timestamp 释放时间戳
     * @return percentage 释放百分比
     * @return released 是否已释放
     * 
     * 功能概述：
     * 查询指定释放计划中特定阶梯步骤的详细信息
     * 
     * 实现步骤：
     * 1. 验证步骤索引有效
     * 2. 从存储中获取步骤数据
     * 3. 返回步骤的完整信息
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：查询阶梯式释放的步骤配置和状态
     * 安全考虑：只读操作，无安全风险
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
     * 
     * 功能概述：
     * 暂停合约的所有释放操作，用于紧急情况处理
     * 
     * 实现步骤：
     * 1. 调用OpenZeppelin的_pause()函数
     * 2. 触发Paused事件
     * 
     * 权限要求：只允许VESTING_ADMIN_ROLE角色调用
     * 用途说明：紧急情况下暂停所有代币释放操作
     * 安全考虑：严格权限控制，防止滥用暂停功能
     */
    function pause() external onlyRole(VESTING_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     * 
     * 功能概述：
     * 恢复合约的正常运行，解除暂停状态
     * 
     * 实现步骤：
     * 1. 调用OpenZeppelin的_unpause()函数
     * 2. 触发Unpaused事件
     * 
     * 权限要求：只允许VESTING_ADMIN_ROLE角色调用
     * 用途说明：紧急情况处理完毕后恢复正常运行
     * 安全考虑：严格权限控制，确保只有管理员可以恢复
     */
    function unpause() external onlyRole(VESTING_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev 紧急提取代币
     * @param to 接收地址
     * @param amount 提取数量
     * 
     * 功能概述：
     * 在紧急情况下提取合约中的代币到指定地址
     * 
     * 实现步骤：
     * 1. 验证接收地址和提取数量的有效性
     * 2. 安全转移代币到指定地址
     * 
     * 权限要求：只允许DEFAULT_ADMIN_ROLE角色调用
     * 用途说明：合约升级或紧急情况下的资金救援
     * 安全考虑：最高权限控制，严格参数验证，安全代币转移
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
