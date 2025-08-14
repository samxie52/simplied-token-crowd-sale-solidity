// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/WhitelistManager.sol";
import "../../contracts/interfaces/IWhitelistManager.sol";

/**
 * @title WhitelistFuzzTest
 * @dev 白名单管理合约模糊测试套件
 */
contract WhitelistFuzzTest is Test {
    
    WhitelistManager public whitelistManager;
    
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    
    function setUp() public {
        vm.startPrank(admin);
        whitelistManager = new WhitelistManager(admin);
        whitelistManager.grantRole(whitelistManager.WHITELIST_OPERATOR_ROLE(), operator);
        vm.stopPrank();
    }
    
    // ============ 基础模糊测试 ============
    
    /**
     * @dev 模糊测试添加白名单功能
     */
    function testFuzz_AddToWhitelist(address user, uint8 levelInput) public {
        // 过滤无效输入
        vm.assume(user != address(0));
        vm.assume(levelInput <= 3); // 只测试有效的枚举值
        
        IWhitelistManager.WhitelistLevel level = IWhitelistManager.WhitelistLevel(levelInput);
        
        vm.startPrank(operator);
        
        // 添加用户到白名单
        whitelistManager.addToWhitelist(user, level);
        
        // 验证状态
        assertEq(uint8(whitelistManager.getWhitelistStatus(user)), levelInput);
        
        // 验证查询函数的一致性
        if (level == IWhitelistManager.WhitelistLevel.VIP) {
            assertTrue(whitelistManager.isVIP(user));
            assertTrue(whitelistManager.isWhitelisted(user));
            assertFalse(whitelistManager.isBlacklisted(user));
        } else if (level == IWhitelistManager.WhitelistLevel.WHITELISTED) {
            assertFalse(whitelistManager.isVIP(user));
            assertTrue(whitelistManager.isWhitelisted(user));
            assertFalse(whitelistManager.isBlacklisted(user));
        } else if (level == IWhitelistManager.WhitelistLevel.BLACKLISTED) {
            assertFalse(whitelistManager.isVIP(user));
            assertFalse(whitelistManager.isWhitelisted(user));
            assertTrue(whitelistManager.isBlacklisted(user));
        } else {
            assertFalse(whitelistManager.isVIP(user));
            assertFalse(whitelistManager.isWhitelisted(user));
            assertFalse(whitelistManager.isBlacklisted(user));
        }
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试带过期时间的白名单添加
     */
    function testFuzz_AddWithExpiration(
        address user, 
        uint8 levelInput, 
        uint256 timeOffset
    ) public {
        vm.assume(user != address(0));
        vm.assume(levelInput <= 3);
        vm.assume(timeOffset > 0 && timeOffset < 365 days); // 合理的时间范围
        
        IWhitelistManager.WhitelistLevel level = IWhitelistManager.WhitelistLevel(levelInput);
        uint256 expirationTime = block.timestamp + timeOffset;
        
        vm.startPrank(operator);
        
        // 添加带过期时间的白名单
        whitelistManager.addToWhitelistWithExpiration(user, level, expirationTime);
        
        // 验证状态
        assertEq(uint8(whitelistManager.getWhitelistStatus(user)), levelInput);
        assertFalse(whitelistManager.isExpired(user));
        
        // 获取完整信息验证
        IWhitelistManager.WhitelistInfo memory info = whitelistManager.getWhitelistInfo(user);
        assertEq(info.expirationTime, expirationTime);
        assertEq(uint8(info.level), levelInput);
        
        // 时间推进到过期后
        vm.warp(expirationTime + 1);
        
        // 验证过期状态
        assertTrue(whitelistManager.isExpired(user));
        assertEq(uint8(whitelistManager.getWhitelistStatus(user)), uint8(IWhitelistManager.WhitelistLevel.NONE));
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试批量操作
     */
    function testFuzz_BatchOperations(uint8 userCount, uint256 seed) public {
        vm.assume(userCount > 0 && userCount <= 50); // 限制在合理范围内
        
        // 生成随机用户地址和级别
        address[] memory users = new address[](userCount);
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](userCount);
        
        for (uint256 i = 0; i < userCount; i++) {
            users[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
            vm.assume(users[i] != address(0));
            levels[i] = IWhitelistManager.WhitelistLevel(uint8(uint256(keccak256(abi.encode(seed, i, "level"))) % 4));
        }
        
        vm.startPrank(operator);
        
        // 批量添加
        whitelistManager.batchAddToWhitelist(users, levels);
        
        // 验证每个用户的状态
        for (uint256 i = 0; i < userCount; i++) {
            assertEq(uint8(whitelistManager.getWhitelistStatus(users[i])), uint8(levels[i]));
        }
        
        // 验证统计信息
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(totalCount, userCount);
        
        // 计算预期统计
        uint256 expectedVip = 0;
        uint256 expectedWhitelisted = 0;
        uint256 expectedBlacklisted = 0;
        
        for (uint256 i = 0; i < userCount; i++) {
            if (levels[i] == IWhitelistManager.WhitelistLevel.VIP) {
                expectedVip++;
            } else if (levels[i] == IWhitelistManager.WhitelistLevel.WHITELISTED) {
                expectedWhitelisted++;
            } else if (levels[i] == IWhitelistManager.WhitelistLevel.BLACKLISTED) {
                expectedBlacklisted++;
            }
        }
        
        assertEq(vipCount, expectedVip);
        assertEq(whitelistedCount, expectedWhitelisted);
        assertEq(blacklistedCount, expectedBlacklisted);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试状态转移
     */
    function testFuzz_TransferWhitelistStatus(
        address from,
        address to,
        uint8 levelInput
    ) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(levelInput > 0 && levelInput <= 3); // 排除NONE级别
        
        IWhitelistManager.WhitelistLevel level = IWhitelistManager.WhitelistLevel(levelInput);
        
        vm.startPrank(operator);
        
        // 先给from地址添加白名单状态
        whitelistManager.addToWhitelist(from, level);
        assertEq(uint8(whitelistManager.getWhitelistStatus(from)), levelInput);
        
        // 转移状态
        whitelistManager.transferWhitelistStatus(from, to);
        
        // 验证转移结果
        assertEq(uint8(whitelistManager.getWhitelistStatus(from)), uint8(IWhitelistManager.WhitelistLevel.NONE));
        assertEq(uint8(whitelistManager.getWhitelistStatus(to)), levelInput);
        
        // 验证统计信息保持一致
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(totalCount, 1); // 总数应该保持为1
        
        if (level == IWhitelistManager.WhitelistLevel.VIP) {
            assertEq(vipCount, 1);
            assertEq(whitelistedCount, 0);
            assertEq(blacklistedCount, 0);
        } else if (level == IWhitelistManager.WhitelistLevel.WHITELISTED) {
            assertEq(vipCount, 0);
            assertEq(whitelistedCount, 1);
            assertEq(blacklistedCount, 0);
        } else if (level == IWhitelistManager.WhitelistLevel.BLACKLISTED) {
            assertEq(vipCount, 0);
            assertEq(whitelistedCount, 0);
            assertEq(blacklistedCount, 1);
        }
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试重复操作的幂等性
     */
    function testFuzz_IdempotentOperations(
        address user,
        uint8 levelInput,
        uint8 operationCount
    ) public {
        vm.assume(user != address(0));
        vm.assume(levelInput <= 3);
        vm.assume(operationCount > 0 && operationCount <= 10);
        
        IWhitelistManager.WhitelistLevel level = IWhitelistManager.WhitelistLevel(levelInput);
        
        vm.startPrank(operator);
        
        // 重复添加相同用户相同级别
        for (uint256 i = 0; i < operationCount; i++) {
            whitelistManager.addToWhitelist(user, level);
            
            // 每次操作后状态应该保持一致
            assertEq(uint8(whitelistManager.getWhitelistStatus(user)), levelInput);
        }
        
        // 验证统计信息正确（用户只应该被计算一次）
        (,, uint256 blacklistedCount, uint256 totalCount) = whitelistManager.getWhitelistStats();
        assertEq(totalCount, 1);
        
        // 重复移除操作
        for (uint256 i = 0; i < operationCount; i++) {
            whitelistManager.removeFromWhitelist(user);
            
            // 每次操作后状态应该保持一致
            assertEq(uint8(whitelistManager.getWhitelistStatus(user)), uint8(IWhitelistManager.WhitelistLevel.NONE));
        }
        
        // 验证统计信息正确
        (,, blacklistedCount, totalCount) = whitelistManager.getWhitelistStats();
        assertEq(totalCount, 0);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试级别更新
     */
    function testFuzz_LevelUpdates(
        address user,
        uint8 initialLevel,
        uint8 newLevel
    ) public {
        vm.assume(user != address(0));
        vm.assume(initialLevel <= 3 && newLevel <= 3);
        vm.assume(initialLevel != newLevel);
        
        IWhitelistManager.WhitelistLevel initial = IWhitelistManager.WhitelistLevel(initialLevel);
        IWhitelistManager.WhitelistLevel updated = IWhitelistManager.WhitelistLevel(newLevel);
        
        vm.startPrank(operator);
        
        // 添加初始级别
        whitelistManager.addToWhitelist(user, initial);
        assertEq(uint8(whitelistManager.getWhitelistStatus(user)), initialLevel);
        
        // 更新到新级别
        whitelistManager.addToWhitelist(user, updated);
        assertEq(uint8(whitelistManager.getWhitelistStatus(user)), newLevel);
        
        // 验证统计信息正确更新
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(totalCount, 1); // 总数应该保持为1
        
        // 验证新级别的统计
        if (updated == IWhitelistManager.WhitelistLevel.VIP) {
            assertEq(vipCount, 1);
        } else if (updated == IWhitelistManager.WhitelistLevel.WHITELISTED) {
            assertEq(whitelistedCount, 1);
        } else if (updated == IWhitelistManager.WhitelistLevel.BLACKLISTED) {
            assertEq(blacklistedCount, 1);
        }
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试时间边界条件
     */
    function testFuzz_TimeBoundaries(
        address user,
        uint256 timeOffset1,
        uint256 timeOffset2
    ) public {
        vm.assume(user != address(0));
        vm.assume(timeOffset1 > 0 && timeOffset1 < 365 days);
        vm.assume(timeOffset2 > timeOffset1 && timeOffset2 < 365 days);
        
        uint256 expirationTime = block.timestamp + timeOffset1;
        
        vm.startPrank(operator);
        
        // 添加带过期时间的白名单
        whitelistManager.addToWhitelistWithExpiration(
            user, 
            IWhitelistManager.WhitelistLevel.WHITELISTED, 
            expirationTime
        );
        
        // 在过期前的各个时间点验证状态
        for (uint256 i = 1; i < timeOffset1; i += timeOffset1 / 10) {
            vm.warp(block.timestamp + i);
            assertTrue(whitelistManager.isWhitelisted(user));
            assertFalse(whitelistManager.isExpired(user));
        }
        
        // 在过期时间点验证
        vm.warp(expirationTime);
        assertFalse(whitelistManager.isWhitelisted(user));
        assertTrue(whitelistManager.isExpired(user));
        
        // 在过期后验证
        vm.warp(expirationTime + timeOffset2 - timeOffset1);
        assertFalse(whitelistManager.isWhitelisted(user));
        assertTrue(whitelistManager.isExpired(user));
        
        vm.stopPrank();
    }
    
    /**
     * @dev 模糊测试统计信息的一致性
     */
    function testFuzz_StatisticsConsistency(uint256 seed, uint8 operationCount) public {
        vm.assume(operationCount > 0 && operationCount <= 20);
        
        vm.startPrank(operator);
        
        uint256 expectedVip = 0;
        uint256 expectedWhitelisted = 0;
        uint256 expectedBlacklisted = 0;
        uint256 expectedTotal = 0;
        
        // 执行随机操作序列
        for (uint256 i = 0; i < operationCount; i++) {
            address user = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
            vm.assume(user != address(0));
            
            uint8 operation = uint8(uint256(keccak256(abi.encode(seed, i, "op"))) % 2); // 0: add, 1: remove
            uint8 levelInput = uint8(uint256(keccak256(abi.encode(seed, i, "level"))) % 4);
            
            IWhitelistManager.WhitelistLevel currentLevel = whitelistManager.getWhitelistStatus(user);
            
            if (operation == 0) { // 添加操作
                IWhitelistManager.WhitelistLevel newLevel = IWhitelistManager.WhitelistLevel(levelInput);
                
                // 更新预期统计
                if (currentLevel == IWhitelistManager.WhitelistLevel.NONE) {
                    expectedTotal++;
                } else {
                    // 移除旧级别统计
                    if (currentLevel == IWhitelistManager.WhitelistLevel.VIP) expectedVip--;
                    else if (currentLevel == IWhitelistManager.WhitelistLevel.WHITELISTED) expectedWhitelisted--;
                    else if (currentLevel == IWhitelistManager.WhitelistLevel.BLACKLISTED) expectedBlacklisted--;
                }
                
                // 添加新级别统计
                if (newLevel == IWhitelistManager.WhitelistLevel.VIP) expectedVip++;
                else if (newLevel == IWhitelistManager.WhitelistLevel.WHITELISTED) expectedWhitelisted++;
                else if (newLevel == IWhitelistManager.WhitelistLevel.BLACKLISTED) expectedBlacklisted++;
                
                whitelistManager.addToWhitelist(user, newLevel);
                
            } else { // 移除操作
                if (currentLevel != IWhitelistManager.WhitelistLevel.NONE) {
                    expectedTotal--;
                    
                    // 移除统计
                    if (currentLevel == IWhitelistManager.WhitelistLevel.VIP) expectedVip--;
                    else if (currentLevel == IWhitelistManager.WhitelistLevel.WHITELISTED) expectedWhitelisted--;
                    else if (currentLevel == IWhitelistManager.WhitelistLevel.BLACKLISTED) expectedBlacklisted--;
                    
                    whitelistManager.removeFromWhitelist(user);
                }
            }
            
            // 验证统计信息一致性
            (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
                whitelistManager.getWhitelistStats();
            
            assertEq(vipCount, expectedVip, "VIP count mismatch");
            assertEq(whitelistedCount, expectedWhitelisted, "Whitelist count mismatch");
            assertEq(blacklistedCount, expectedBlacklisted, "Blacklist count mismatch");
            assertEq(totalCount, expectedTotal, "Total count mismatch");
        }
        
        vm.stopPrank();
    }
}
