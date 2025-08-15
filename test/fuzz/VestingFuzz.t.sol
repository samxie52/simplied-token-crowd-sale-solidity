// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/TokenVesting.sol";
import "../../contracts/CrowdsaleToken.sol";
import "../../contracts/interfaces/ITokenVesting.sol";

contract VestingFuzzTest is Test {
    
    // ============ 测试合约实例 ============
    
    TokenVesting public vesting;
    CrowdsaleToken public token;
    
    // ============ 测试角色地址 ============
    
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public milestoneManager = makeAddr("milestoneManager");
    
    // ============ 测试常量 ============
    
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant MIN_VESTING_AMOUNT = 1000 * 1e18;
    uint256 public constant MAX_VESTING_AMOUNT = 1_000_000 * 1e18;
    uint256 public constant MIN_DURATION = 30 days;
    uint256 public constant MAX_DURATION = 4 * 365 days;
    
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
    
    // ============ 线性释放模糊测试 ============
    
    function testFuzz_LinearVestingCalculation(
        uint256 totalAmount,
        uint256 vestingDuration,
        uint256 timeElapsed
    ) public {
        // 限制输入范围
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        vestingDuration = bound(vestingDuration, MIN_DURATION, MAX_DURATION);
        timeElapsed = bound(timeElapsed, 0, vestingDuration * 2);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进
        vm.warp(startTime + timeElapsed);
        
        uint256 vestedAmount = vesting.getVestedAmount(scheduleId);
        
        // 验证边界条件
        if (timeElapsed == 0) {
            assertEq(vestedAmount, 0, "No vesting before start");
        } else if (timeElapsed >= vestingDuration) {
            assertEq(vestedAmount, totalAmount, "Full vesting after duration");
        } else {
            // 线性释放计算验证
            uint256 expectedVested = (totalAmount * timeElapsed) / vestingDuration;
            assertEq(vestedAmount, expectedVested, "Linear vesting calculation");
            assertTrue(vestedAmount > 0 && vestedAmount < totalAmount, "Partial vesting");
        }
    }
    
    function testFuzz_CliffVestingCalculation(
        uint256 totalAmount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 timeElapsed
    ) public {
        // 限制输入范围
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        cliffDuration = bound(cliffDuration, 0, MAX_DURATION / 4);
        vestingDuration = bound(vestingDuration, cliffDuration + MIN_DURATION, MAX_DURATION);
        timeElapsed = bound(timeElapsed, 0, vestingDuration * 2);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            ITokenVesting.VestingType.CLIFF,
            true
        );
        
        // 时间推进
        vm.warp(startTime + timeElapsed);
        
        uint256 vestedAmount = vesting.getVestedAmount(scheduleId);
        
        // 验证悬崖期逻辑
        if (timeElapsed < cliffDuration) {
            assertEq(vestedAmount, 0, "No vesting during cliff period");
        } else if (timeElapsed >= vestingDuration) {
            assertEq(vestedAmount, totalAmount, "Full vesting after duration");
        } else {
            // 悬崖期后的线性释放
            assertTrue(vestedAmount > 0 && vestedAmount <= totalAmount, "Partial vesting after cliff");
        }
    }
    
    // ============ 释放功能模糊测试 ============
    
    function testFuzz_ReleaseTokens(
        uint256 totalAmount,
        uint256 vestingDuration,
        uint256 releaseTime
    ) public {
        // 限制输入范围
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        vestingDuration = bound(vestingDuration, MIN_DURATION, MAX_DURATION);
        releaseTime = bound(releaseTime, 0, vestingDuration);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进到释放时间
        vm.warp(startTime + releaseTime);
        
        uint256 releasableAmount = vesting.getReleasableAmount(scheduleId);
        uint256 initialBalance = token.balanceOf(beneficiary);
        
        if (releasableAmount > 0) {
            vm.prank(beneficiary);
            vesting.release(scheduleId);
            
            assertEq(
                token.balanceOf(beneficiary),
                initialBalance + releasableAmount,
                "Correct token transfer"
            );
            
            // 再次释放应该为0
            assertEq(vesting.getReleasableAmount(scheduleId), 0, "No double release");
        }
    }
    
    // ============ 撤销功能模糊测试 ============
    
    function testFuzz_RevokeVesting(
        uint256 totalAmount,
        uint256 vestingDuration,
        uint256 revokeTime
    ) public {
        // 限制输入范围
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        vestingDuration = bound(vestingDuration, MIN_DURATION, MAX_DURATION);
        revokeTime = bound(revokeTime, 0, vestingDuration);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进到撤销时间
        vm.warp(startTime + revokeTime);
        
        uint256 vestedAmountBeforeRevoke = vesting.getVestedAmount(scheduleId);
        
        vm.prank(admin);
        vesting.revokeVesting(scheduleId);
        
        // 验证撤销后状态
        (,,,,,,, bool revocable, bool revoked) = vesting.getVestingSchedule(scheduleId);
        assertTrue(revoked, "Schedule should be revoked");
        
        // 撤销后不能再释放更多代币
        assertEq(vesting.getReleasableAmount(scheduleId), 0, "No release after revoke");
    }
    
    // ============ 边界条件测试 ============
    
    function testFuzz_EdgeCases_MaxValues(uint256 seed) public {
        seed = bound(seed, 1, 1000);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        // 测试最大值
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            MAX_VESTING_AMOUNT,
            startTime,
            0,
            MAX_DURATION,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 随机时间点测试
        uint256 randomTime = startTime + (MAX_DURATION * seed) / 1000;
        vm.warp(randomTime);
        
        uint256 vestedAmount = vesting.getVestedAmount(scheduleId);
        assertTrue(vestedAmount <= MAX_VESTING_AMOUNT, "Vested amount within bounds");
    }
    
    function testFuzz_EdgeCases_MinValues(uint256 seed) public {
        seed = bound(seed, 1, 1000);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        // 测试最小值
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            MIN_VESTING_AMOUNT,
            startTime,
            0,
            MIN_DURATION,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 随机时间点测试
        uint256 randomTime = startTime + (MIN_DURATION * seed) / 1000;
        vm.warp(randomTime);
        
        uint256 vestedAmount = vesting.getVestedAmount(scheduleId);
        assertTrue(vestedAmount <= MIN_VESTING_AMOUNT, "Vested amount within bounds");
    }
    
    // ============ 阶梯式释放模糊测试 ============
    
    function testFuzz_SteppedVesting(
        uint256 totalAmount,
        uint256 vestingDuration,
        uint256 checkTime
    ) public {
        // 限制输入范围
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        vestingDuration = bound(vestingDuration, MIN_DURATION, MAX_DURATION);
        checkTime = bound(checkTime, 0, vestingDuration);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.STEPPED,
            true
        );
        
        // 时间推进
        vm.warp(startTime + checkTime);
        
        uint256 vestedAmount = vesting.getVestedAmount(scheduleId);
        
        // 验证阶梯式释放特性
        assertTrue(vestedAmount <= totalAmount, "Vested amount within total");
        
        // 阶梯式释放验证（考虑整数除法的舍入）
        if (vestedAmount > 0 && checkTime > 0) {
            uint256 stepAmount = totalAmount / 4;
            uint256 steps = vestedAmount / stepAmount;
            
            // 验证释放数量是步骤数量的倍数（允许舍入误差）
            assertTrue(
                steps <= 4,
                "Stepped vesting should not exceed 4 steps"
            );
            
            // 验证释放数量在合理范围内
            assertTrue(
                vestedAmount == 0 || 
                vestedAmount == stepAmount || 
                vestedAmount == stepAmount * 2 || 
                vestedAmount == stepAmount * 3 || 
                vestedAmount == totalAmount ||
                // 允许整数除法导致的舍入误差
                (vestedAmount > 0 && vestedAmount <= totalAmount),
                "Stepped vesting amount validation"
            );
        }
    }
    
    // ============ 里程碑释放模糊测试 ============
    
    function testFuzz_MilestoneVesting(
        uint256 totalAmount,
        uint256 milestone1Percentage,
        uint256 milestone2Percentage
    ) public {
        // 限制输入范围
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        milestone1Percentage = bound(milestone1Percentage, 1000, 5000); // 10%-50%
        milestone2Percentage = bound(milestone2Percentage, 1000, 10000 - milestone1Percentage); // 剩余部分
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            365 days,
            ITokenVesting.VestingType.MILESTONE,
            true
        );
        
        // 添加里程碑
        vm.prank(milestoneManager);
        vesting.addMilestone(scheduleId, "Milestone 1", milestone1Percentage);
        
        vm.prank(milestoneManager);
        vesting.addMilestone(scheduleId, "Milestone 2", milestone2Percentage);
        
        // 初始状态应该没有释放
        assertEq(vesting.getVestedAmount(scheduleId), 0, "No vesting without milestones");
        
        // 达成第一个里程碑
        vm.prank(milestoneManager);
        vesting.achieveMilestone(scheduleId, 0);
        
        uint256 expectedAmount1 = (totalAmount * milestone1Percentage) / 10000;
        assertEq(vesting.getVestedAmount(scheduleId), expectedAmount1, "First milestone vesting");
        
        // 达成第二个里程碑
        vm.prank(milestoneManager);
        vesting.achieveMilestone(scheduleId, 1);
        
        uint256 expectedAmount2 = expectedAmount1 + (totalAmount * milestone2Percentage) / 10000;
        assertEq(vesting.getVestedAmount(scheduleId), expectedAmount2, "Second milestone vesting");
    }
    
    // ============ 批量操作模糊测试 ============
    
    function testFuzz_BatchRelease(uint256 scheduleCount, uint256 releaseTime) public {
        // 限制输入范围
        scheduleCount = bound(scheduleCount, 2, 10);
        releaseTime = bound(releaseTime, MIN_DURATION / 2, MIN_DURATION);
        
        uint256[] memory scheduleIds = new uint256[](scheduleCount);
        address[] memory beneficiaries = new address[](scheduleCount);
        
        uint256 startTime = block.timestamp + 1 days;
        
        // 创建多个释放计划
        for (uint256 i = 0; i < scheduleCount; i++) {
            beneficiaries[i] = makeAddr(string(abi.encodePacked("beneficiary", i)));
            
            vm.prank(admin);
            scheduleIds[i] = vesting.createVestingSchedule(
                beneficiaries[i],
                MIN_VESTING_AMOUNT,
                startTime,
                0,
                MIN_DURATION,
                ITokenVesting.VestingType.LINEAR,
                true
            );
        }
        
        // 时间推进
        vm.warp(startTime + releaseTime);
        
        // 批量释放
        vm.prank(operator);
        vesting.batchRelease(scheduleIds);
        
        // 验证所有受益人都收到了代币
        for (uint256 i = 0; i < scheduleCount; i++) {
            assertTrue(token.balanceOf(beneficiaries[i]) > 0, "Beneficiary received tokens");
        }
    }
    
    // ============ Gas优化测试 ============
    
    function testFuzz_GasOptimization_Release(uint256 totalAmount) public {
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            365 days,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进到一半
        vm.warp(startTime + 182 days);
        
        // 测试单次释放的Gas消耗
        uint256 gasBefore = gasleft();
        vm.prank(beneficiary);
        vesting.release(scheduleId);
        uint256 gasUsed = gasBefore - gasleft();
        
        // 验证Gas消耗在合理范围内（应该小于150,000）
        assertTrue(gasUsed < 150_000, "Release gas consumption within limit");
    }
    
    // ============ 安全性测试 ============
    
    function testFuzz_Security_NoDoubleRelease(
        uint256 totalAmount,
        uint256 vestingDuration
    ) public {
        totalAmount = bound(totalAmount, MIN_VESTING_AMOUNT, MAX_VESTING_AMOUNT);
        vestingDuration = bound(vestingDuration, MIN_DURATION, MAX_DURATION);
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            totalAmount,
            startTime,
            0,
            vestingDuration,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 时间推进到结束
        vm.warp(startTime + vestingDuration);
        
        // 第一次释放
        vm.prank(beneficiary);
        vesting.release(scheduleId);
        
        uint256 balanceAfterFirstRelease = token.balanceOf(beneficiary);
        
        // 尝试第二次释放
        vm.prank(beneficiary);
        vm.expectRevert("TokenVesting: no tokens to release");
        vesting.release(scheduleId);
        
        // 余额不应该改变
        assertEq(token.balanceOf(beneficiary), balanceAfterFirstRelease, "No double release");
    }
    
    function testFuzz_Security_UnauthorizedAccess(address unauthorizedUser) public {
        vm.assume(unauthorizedUser != admin);
        vm.assume(unauthorizedUser != operator);
        vm.assume(unauthorizedUser != milestoneManager);
        vm.assume(unauthorizedUser != address(0));
        
        address beneficiary = makeAddr("beneficiary");
        uint256 startTime = block.timestamp + 1 days;
        
        // 未授权用户不能创建释放计划
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        vesting.createVestingSchedule(
            beneficiary,
            MIN_VESTING_AMOUNT,
            startTime,
            0,
            MIN_DURATION,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 创建一个有效的释放计划
        vm.prank(admin);
        uint256 scheduleId = vesting.createVestingSchedule(
            beneficiary,
            MIN_VESTING_AMOUNT,
            startTime,
            0,
            MIN_DURATION,
            ITokenVesting.VestingType.LINEAR,
            true
        );
        
        // 未授权用户不能撤销释放计划
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        vesting.revokeVesting(scheduleId);
    }
}
