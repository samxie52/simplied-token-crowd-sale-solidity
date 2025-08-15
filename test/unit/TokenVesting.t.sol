// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/TokenVesting.sol";
import "../../contracts/CrowdsaleToken.sol";
import "../../contracts/interfaces/ITokenVesting.sol";

contract TokenVestingTest is Test {
    
    // ============ 测试合约实例 ============
    
    TokenVesting public vesting;
    CrowdsaleToken public token;
    
    // ============ 测试角色地址 ============
    
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public milestoneManager = makeAddr("milestoneManager");
    address public beneficiary1 = makeAddr("beneficiary1");
    address public beneficiary2 = makeAddr("beneficiary2");
    address public beneficiary3 = makeAddr("beneficiary3");
    
    // ============ 测试常量 ============
    
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 1e18;
    uint256 public constant VESTING_AMOUNT = 100_000 * 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    
    // ============ 测试事件 ============
    
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 totalAmount,
        ITokenVesting.VestingType vestingType,
        uint256 startTime
    );
    
    event TokensReleased(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 amount,
        uint256 timestamp
    );
    
    event VestingRevoked(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 unvestedAmount,
        uint256 timestamp
    );
    
    // ============ 设置函数 ============
    
    function setUp() public {
        vm.startPrank(admin);
        
        // 部署代币合约
        token = new CrowdsaleToken(
            "Test Token",
            "TEST",
            TOTAL_SUPPLY,
            admin
        );
        
        // 铸造代币到admin
        token.mint(admin, TOTAL_SUPPLY);
        
        // 部署释放合约
        vesting = new TokenVesting(address(token), admin);
        
        // 设置角色权限
        vesting.grantRole(vesting.VESTING_OPERATOR_ROLE(), operator);
        vesting.grantRole(vesting.MILESTONE_MANAGER_ROLE(), milestoneManager);
        
        // 转移代币到释放合约
        token.transfer(address(vesting), TOTAL_SUPPLY / 2);
        
        vm.stopPrank();
    }
    
    // ============ 基础功能测试 ============
    
    function test_InitialState() public {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.nextScheduleId(), 0);
        assertEq(vesting.getTotalVestingAmount(), 0);
        assertEq(vesting.getTotalReleasedAmount(), 0);
        assertTrue(vesting.hasRole(vesting.VESTING_ADMIN_ROLE(), admin));
    }
    
    function test_CreateLinearVestingSchedule() public {
        uint256 startTime = block.timestamp + 1 days;
        uint256 vestingDuration = 365 days;
        
        vm.expectEmit(true, true, false, true);
        emit VestingScheduleCreated(
            beneficiary1,
            0,
            VESTING_AMOUNT,
            ITokenVesting.VestingType.LINEAR,
            startTime
        );
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        assertEq(scheduleId, 0);
        assertEq(vesting.getTotalVestingAmount(), VESTING_AMOUNT);
        
        (
            address beneficiary,
            uint256 totalAmount,
            uint256 scheduleStartTime,
            uint256 cliffDuration,
            uint256 scheduleDuration,
            uint256 releasedAmount,
            ITokenVesting.VestingType vestingType,
            bool revocable,
            bool revoked
        ) = vesting.getVestingSchedule(scheduleId);
        
        assertEq(beneficiary, beneficiary1);
        assertEq(totalAmount, VESTING_AMOUNT);
        assertEq(scheduleStartTime, startTime);
        assertEq(cliffDuration, 0);
        assertEq(scheduleDuration, vestingDuration);
        assertEq(releasedAmount, 0);
        assertTrue(vestingType == ITokenVesting.VestingType.LINEAR);
        assertTrue(revocable);
        assertFalse(revoked);
    }
    
    function test_CreateCliffVestingSchedule() public {
        uint256 startTime = block.timestamp + 1 days;
        uint256 cliffDuration = 90 days;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            cliffDuration,
            vestingDuration,
            ITokenVesting.VestingType.CLIFF,
            true
        );
        
        (,, uint256 scheduleStartTime, uint256 scheduleCliffDuration,,,,, bool revoked) = vesting.getVestingSchedule(scheduleId);
        
        assertEq(scheduleStartTime, startTime);
        assertEq(scheduleCliffDuration, cliffDuration);
        assertFalse(revoked);
    }
    
    function test_CreateSteppedVestingSchedule() public {
        uint256 startTime = block.timestamp + 1 days;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.STEPPED,
            false
        );
        
        // 检查阶梯式释放步骤
        (uint256 timestamp1, uint256 percentage1,) = vesting.getVestingStep(scheduleId, 0);
        (uint256 timestamp2, uint256 percentage2,) = vesting.getVestingStep(scheduleId, 1);
        
        assertEq(percentage1, 2500); // 25%
        assertEq(percentage2, 2500); // 25%
        assertEq(timestamp2, timestamp1 + vestingDuration / 4);
    }
    
    // ============ 释放功能测试 ============
    
    function test_LinearVestingRelease() public {
        uint256 startTime = block.timestamp;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进到一半
        vm.warp(startTime + vestingDuration / 2);
        
        uint256 expectedAmount = VESTING_AMOUNT / 2;
        assertEq(vesting.getReleasableAmount(scheduleId), expectedAmount);
        
        uint256 initialBalance = token.balanceOf(beneficiary1);
        
        vm.expectEmit(true, true, false, true);
        emit TokensReleased(beneficiary1, scheduleId, expectedAmount, block.timestamp);
        
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        assertEq(token.balanceOf(beneficiary1), initialBalance + expectedAmount);
        assertEq(vesting.getReleasableAmount(scheduleId), 0);
        assertEq(vesting.getBeneficiaryReleasedAmount(beneficiary1), expectedAmount);
    }
    
    function test_CliffVestingRelease() public {
        uint256 startTime = block.timestamp;
        uint256 cliffDuration = 90 days;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            cliffDuration,
            vestingDuration,
            ITokenVesting.VestingType.CLIFF,
            true
        );
        
        // 悬崖期内不能释放
        vm.warp(startTime + cliffDuration - 1);
        assertEq(vesting.getReleasableAmount(scheduleId), 0);
        
        // 悬崖期后开始释放
        vm.warp(startTime + cliffDuration + (vestingDuration - cliffDuration) / 2);
        uint256 expectedAmount = VESTING_AMOUNT / 2;
        assertApproxEqAbs(vesting.getReleasableAmount(scheduleId), expectedAmount, 1e15);
        
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        assertApproxEqAbs(token.balanceOf(beneficiary1), expectedAmount, 1e15);
    }
    
    function test_SteppedVestingRelease() public {
        uint256 startTime = block.timestamp;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.STEPPED,
            true
        );
        
        // 第一个阶段后
        vm.warp(startTime + vestingDuration / 4 + 1);
        uint256 expectedAmount = VESTING_AMOUNT / 4; // 25%
        assertEq(vesting.getReleasableAmount(scheduleId), expectedAmount);
        
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        assertEq(token.balanceOf(beneficiary1), expectedAmount);
        
        // 第二个阶段后
        vm.warp(startTime + vestingDuration / 2 + 1);
        expectedAmount = VESTING_AMOUNT / 4; // 另外25%
        assertEq(vesting.getReleasableAmount(scheduleId), expectedAmount);
    }
    
    function test_BatchRelease() public {
        uint256 startTime = block.timestamp;
        uint256 vestingDuration = 365 days;
        
        // 创建多个释放计划
        vm.startPrank(admin);
        uint256 scheduleId1 = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        uint256 scheduleId2 = vesting.createVestingSchedule(
            beneficiary2,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        vm.stopPrank();
        
        // 时间推进
        vm.warp(startTime + vestingDuration / 2);
        
        uint256[] memory scheduleIds = new uint256[](2);
        scheduleIds[0] = scheduleId1;
        scheduleIds[1] = scheduleId2;
        
        vm.prank(operator);
        vesting.batchRelease(scheduleIds);
        
        uint256 expectedAmount = VESTING_AMOUNT / 2;
        assertEq(token.balanceOf(beneficiary1), expectedAmount);
        assertEq(token.balanceOf(beneficiary2), expectedAmount);
    }
    
    // ============ 撤销功能测试 ============
    
    function test_RevokeVesting() public {
        uint256 startTime = block.timestamp + 1 days; // 开始时间设为未来
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进到释放开始后的一半
        uint256 halfwayTime = startTime + vestingDuration / 2;
        vm.warp(halfwayTime);
        
        // 调试信息
        console.log("Start time:", startTime);
        console.log("Current time:", block.timestamp);
        console.log("Vesting duration:", vestingDuration);
        console.log("Expected vested amount:", VESTING_AMOUNT / 2);
        
        uint256 vestedAmount = vesting.getVestedAmount(scheduleId);
        console.log("Actual vested amount:", vestedAmount);
        
        uint256 unvestedAmount = VESTING_AMOUNT - vestedAmount;
        
        // 确保有已释放的代币
        assertTrue(vestedAmount > 0, "Vested amount should be greater than 0");
        assertTrue(unvestedAmount > 0, "Unvested amount should be greater than 0");
        
        vm.expectEmit(true, true, false, true);
        emit VestingRevoked(beneficiary1, scheduleId, unvestedAmount, block.timestamp);
        
        vm.prank(admin);
        vesting.revokeVesting(scheduleId);
        
        (,,,,,,, bool revocable, bool revoked) = vesting.getVestingSchedule(scheduleId);
        assertTrue(revoked);
        
        // 撤销后，可释放数量应该等于已释放数量（因为没有实际释放过代币）
        // 由于撤销时已释放数量为0，所以可释放数量也应该为0
        assertEq(vesting.getReleasableAmount(scheduleId), 0);
    }
    
    function test_CannotRevokeNonRevocableVesting() public {
        uint256 startTime = block.timestamp + 1 days;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            false // 不可撤销
        );
        
        vm.expectRevert("TokenVesting: not revocable");
        vm.prank(admin);
        vesting.revokeVesting(scheduleId);
    }
    
    // ============ 里程碑功能测试 ============
    
    function test_MilestoneVesting() public {
        uint256 startTime = block.timestamp;
        uint256 vestingDuration = 365 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.MILESTONE,
            true
        );
        
        // 添加里程碑
        vm.prank(milestoneManager);
        vesting.addMilestone(scheduleId, "First milestone", 5000); // 50%
        
        vm.prank(milestoneManager);
        vesting.addMilestone(scheduleId, "Second milestone", 5000); // 50%
        
        // 检查里程碑信息
        (string memory description, uint256 percentage, bool achieved,) = vesting.getMilestone(scheduleId, 0);
        assertEq(description, "First milestone");
        assertEq(percentage, 5000);
        assertFalse(achieved);
        
        // 达成第一个里程碑
        vm.prank(milestoneManager);
        vesting.achieveMilestone(scheduleId, 0);
        
        uint256 expectedAmount = VESTING_AMOUNT / 2;
        assertEq(vesting.getReleasableAmount(scheduleId), expectedAmount);
        
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        assertEq(token.balanceOf(beneficiary1), expectedAmount);
    }
    
    // ============ 权限控制测试 ============
    
    function test_OnlyAdminCanCreateSchedule() public {
        vm.expectRevert();
        vm.prank(beneficiary1);
        vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp + 1 days,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
    }
    
    function test_OnlyBeneficiaryOrOperatorCanRelease() public {
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        vm.warp(block.timestamp + 100 days);
        
        // 受益人可以释放
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        // 时间再推进一些，确保有更多代币可释放
        vm.warp(block.timestamp + 100 days);
        
        // 操作员也可以释放
        vm.prank(operator);
        vesting.release(scheduleId);
        
        // 其他人不能释放
        vm.expectRevert("TokenVesting: not authorized");
        vm.prank(beneficiary2);
        vesting.release(scheduleId);
    }
    
    // ============ 边界条件测试 ============
    
    function test_CannotCreateScheduleWithZeroAmount() public {
        vm.expectRevert("TokenVesting: zero amount");
        vm.prank(admin);
        vesting.createVestingSchedule(
            beneficiary1,
            0,
            block.timestamp + 1 days,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
    }
    
    function test_CannotCreateScheduleWithZeroBeneficiary() public {
        vm.expectRevert("TokenVesting: zero beneficiary");
        vm.prank(admin);
        vesting.createVestingSchedule(
            address(0),
            VESTING_AMOUNT,
            block.timestamp + 1 days,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
    }
    
    function test_CannotReleaseNonExistentSchedule() public {
        vm.expectRevert("TokenVesting: schedule not found");
        vm.prank(beneficiary1);
        vesting.release(999);
    }
    
    function test_CannotReleaseWhenNoTokensAvailable() public {
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp + 1 days,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间还没开始，不能释放
        vm.expectRevert("TokenVesting: no tokens to release");
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
    }
    
    // ============ 暂停功能测试 ============
    
    function test_PauseAndUnpause() public {
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        vm.warp(block.timestamp + 100 days);
        
        // 暂停合约
        vm.prank(admin);
        vesting.pause();
        
        // 暂停时不能释放
        vm.expectRevert();
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        // 恢复合约
        vm.prank(admin);
        vesting.unpause();
        
        // 恢复后可以释放
        vm.prank(beneficiary1);
        vesting.release(scheduleId);
        
        assertTrue(token.balanceOf(beneficiary1) > 0);
    }
    
    // ============ 查询功能测试 ============
    
    function test_GetBeneficiarySchedules() public {
        vm.startPrank(admin);
        
        uint256 scheduleId1 = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp + 1 days,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        uint256 scheduleId2 = vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp + 2 days,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        vm.stopPrank();
        
        uint256[] memory schedules = vesting.getBeneficiarySchedules(beneficiary1);
        assertEq(schedules.length, 2);
        assertEq(schedules[0], scheduleId1);
        assertEq(schedules[1], scheduleId2);
        
        assertEq(vesting.getBeneficiaryTotalAmount(beneficiary1), VESTING_AMOUNT * 2);
    }
    
    function test_GetTotalAmounts() public {
        vm.startPrank(admin);
        
        vesting.createVestingSchedule(
            beneficiary1,
            VESTING_AMOUNT,
            block.timestamp,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        vesting.createVestingSchedule(
            beneficiary2,
            VESTING_AMOUNT,
            block.timestamp,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        vm.stopPrank();
        
        assertEq(vesting.getTotalVestingAmount(), VESTING_AMOUNT * 2);
        assertEq(vesting.getTotalReleasedAmount(), 0);
        
        // 释放一些代币
        vm.warp(block.timestamp + 100 days);
        
        vm.prank(beneficiary1);
        vesting.release(0);
        
        assertTrue(vesting.getTotalReleasedAmount() > 0);
    }
}
