// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/WhitelistManager.sol";
import "../../contracts/interfaces/IWhitelistManager.sol";

/**
 * @title WhitelistManagerTest
 * @dev 白名单管理合约完整测试套件
 */
contract WhitelistManagerTest is Test {
    
    // 测试合约实例
    WhitelistManager public whitelistManager;
    
    // 测试地址
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public blacklistedUser = makeAddr("blacklistedUser");
    address public vipUser = makeAddr("vipUser");
    
    // 测试事件
    event WhitelistAdded(
        address indexed user,
        IWhitelistManager.WhitelistLevel indexed level,
        uint256 expirationTime,
        address indexed addedBy
    );
    
    event WhitelistRemoved(
        address indexed user,
        IWhitelistManager.WhitelistLevel previousLevel,
        address indexed removedBy
    );
    
    event BatchWhitelistAdded(
        address[] users,
        IWhitelistManager.WhitelistLevel[] levels,
        uint256 expirationTime,
        address indexed addedBy
    );
    
    event WhitelistTransferred(
        address indexed from,
        address indexed to,
        IWhitelistManager.WhitelistLevel level,
        address indexed transferredBy
    );
    
    function setUp() public {
        // 部署白名单管理合约
        vm.startPrank(admin);
        whitelistManager = new WhitelistManager(admin);
        
        // 授予操作员权限
        whitelistManager.grantRole(whitelistManager.WHITELIST_OPERATOR_ROLE(), operator);
        vm.stopPrank();
    }
    
    // ============ 基础功能测试 ============
    
    function testInitialState() public {
        // 验证初始状态
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(vipCount, 0);
        assertEq(whitelistedCount, 0);
        assertEq(blacklistedCount, 0);
        assertEq(totalCount, 0);
        assertFalse(whitelistManager.paused());
        
        // 验证角色权限
        assertTrue(whitelistManager.hasRole(whitelistManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(whitelistManager.hasRole(whitelistManager.WHITELIST_ADMIN_ROLE(), admin));
        assertTrue(whitelistManager.hasRole(whitelistManager.WHITELIST_OPERATOR_ROLE(), admin));
        assertTrue(whitelistManager.hasRole(whitelistManager.WHITELIST_OPERATOR_ROLE(), operator));
    }
    
    function testAddToWhitelist() public {
        vm.startPrank(operator);
        
        // 测试添加白名单用户
        vm.expectEmit(true, true, false, true);
        emit WhitelistAdded(user1, IWhitelistManager.WhitelistLevel.WHITELISTED, 0, operator);
        
        whitelistManager.addToWhitelist(user1, IWhitelistManager.WhitelistLevel.WHITELISTED);
        
        // 验证状态
        assertEq(uint8(whitelistManager.getWhitelistStatus(user1)), uint8(IWhitelistManager.WhitelistLevel.WHITELISTED));
        assertTrue(whitelistManager.isWhitelisted(user1));
        assertFalse(whitelistManager.isVIP(user1));
        assertFalse(whitelistManager.isBlacklisted(user1));
        
        vm.stopPrank();
    }
    
    function testAddVIPUser() public {
        vm.startPrank(operator);
        
        // 测试添加VIP用户
        whitelistManager.addToWhitelist(vipUser, IWhitelistManager.WhitelistLevel.VIP);
        
        // 验证状态
        assertEq(uint8(whitelistManager.getWhitelistStatus(vipUser)), uint8(IWhitelistManager.WhitelistLevel.VIP));
        assertTrue(whitelistManager.isWhitelisted(vipUser));
        assertTrue(whitelistManager.isVIP(vipUser));
        assertFalse(whitelistManager.isBlacklisted(vipUser));
        
        vm.stopPrank();
    }
    
    function testAddBlacklistedUser() public {
        vm.startPrank(operator);
        
        // 测试添加黑名单用户
        whitelistManager.addToWhitelist(blacklistedUser, IWhitelistManager.WhitelistLevel.BLACKLISTED);
        
        // 验证状态
        assertEq(uint8(whitelistManager.getWhitelistStatus(blacklistedUser)), uint8(IWhitelistManager.WhitelistLevel.BLACKLISTED));
        assertFalse(whitelistManager.isWhitelisted(blacklistedUser));
        assertFalse(whitelistManager.isVIP(blacklistedUser));
        assertTrue(whitelistManager.isBlacklisted(blacklistedUser));
        
        vm.stopPrank();
    }
    
    function testRemoveFromWhitelist() public {
        vm.startPrank(operator);
        
        // 先添加用户
        whitelistManager.addToWhitelist(user1, IWhitelistManager.WhitelistLevel.WHITELISTED);
        assertTrue(whitelistManager.isWhitelisted(user1));
        
        // 测试移除用户
        vm.expectEmit(true, false, false, true);
        emit WhitelistRemoved(user1, IWhitelistManager.WhitelistLevel.WHITELISTED, operator);
        
        whitelistManager.removeFromWhitelist(user1);
        
        // 验证状态
        assertEq(uint8(whitelistManager.getWhitelistStatus(user1)), uint8(IWhitelistManager.WhitelistLevel.NONE));
        assertFalse(whitelistManager.isWhitelisted(user1));
        
        vm.stopPrank();
    }
    
    // ============ 批量操作测试 ============
    
    function testBatchAddToWhitelist() public {
        vm.startPrank(operator);
        
        // 准备批量数据
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](3);
        levels[0] = IWhitelistManager.WhitelistLevel.WHITELISTED;
        levels[1] = IWhitelistManager.WhitelistLevel.VIP;
        levels[2] = IWhitelistManager.WhitelistLevel.BLACKLISTED;
        
        // 测试批量添加
        vm.expectEmit(false, false, false, true);
        emit BatchWhitelistAdded(users, levels, 0, operator);
        
        whitelistManager.batchAddToWhitelist(users, levels);
        
        // 验证状态
        assertTrue(whitelistManager.isWhitelisted(user1));
        assertTrue(whitelistManager.isVIP(user2));
        assertTrue(whitelistManager.isBlacklisted(user3));
        
        // 验证统计
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(vipCount, 1);
        assertEq(whitelistedCount, 1);
        assertEq(blacklistedCount, 1);
        assertEq(totalCount, 3);
        
        vm.stopPrank();
    }
    
    function testBatchRemoveFromWhitelist() public {
        vm.startPrank(operator);
        
        // 先批量添加用户
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](2);
        levels[0] = IWhitelistManager.WhitelistLevel.WHITELISTED;
        levels[1] = IWhitelistManager.WhitelistLevel.VIP;
        
        whitelistManager.batchAddToWhitelist(users, levels);
        
        // 测试批量移除
        whitelistManager.batchRemoveFromWhitelist(users);
        
        // 验证状态
        assertFalse(whitelistManager.isWhitelisted(user1));
        assertFalse(whitelistManager.isVIP(user2));
        
        // 验证统计
        (,, uint256 blacklistedCount, uint256 totalCount) = whitelistManager.getWhitelistStats();
        assertEq(totalCount, 0);
        
        vm.stopPrank();
    }
    
    // ============ 时间控制测试 ============
    
    function testAddWithExpiration() public {
        vm.startPrank(operator);
        
        uint256 expirationTime = block.timestamp + 1 hours;
        
        // 测试添加带过期时间的白名单
        whitelistManager.addToWhitelistWithExpiration(
            user1, 
            IWhitelistManager.WhitelistLevel.WHITELISTED, 
            expirationTime
        );
        
        // 验证状态
        assertTrue(whitelistManager.isWhitelisted(user1));
        assertFalse(whitelistManager.isExpired(user1));
        
        // 获取完整信息
        IWhitelistManager.WhitelistInfo memory info = whitelistManager.getWhitelistInfo(user1);
        assertEq(info.expirationTime, expirationTime);
        assertEq(uint8(info.level), uint8(IWhitelistManager.WhitelistLevel.WHITELISTED));
        
        vm.stopPrank();
    }
    
    function testExpiredWhitelist() public {
        vm.startPrank(operator);
        
        uint256 expirationTime = block.timestamp + 1 hours;
        
        // 添加带过期时间的白名单
        whitelistManager.addToWhitelistWithExpiration(
            user1, 
            IWhitelistManager.WhitelistLevel.WHITELISTED, 
            expirationTime
        );
        
        // 时间推进到过期后
        vm.warp(expirationTime + 1);
        
        // 验证过期状态
        assertTrue(whitelistManager.isExpired(user1));
        assertEq(uint8(whitelistManager.getWhitelistStatus(user1)), uint8(IWhitelistManager.WhitelistLevel.NONE));
        assertFalse(whitelistManager.isWhitelisted(user1));
        
        vm.stopPrank();
    }
    
    function testCleanupExpiredWhitelists() public {
        vm.startPrank(operator);
        
        uint256 expirationTime = block.timestamp + 1 hours;
        
        // 添加过期白名单
        whitelistManager.addToWhitelistWithExpiration(
            user1, 
            IWhitelistManager.WhitelistLevel.WHITELISTED, 
            expirationTime
        );
        
        // 时间推进到过期后
        vm.warp(expirationTime + 1);
        
        // 清理过期白名单
        address[] memory users = new address[](1);
        users[0] = user1;
        
        whitelistManager.cleanupExpiredWhitelists(users);
        
        // 验证清理结果
        IWhitelistManager.WhitelistInfo memory info = whitelistManager.getWhitelistInfo(user1);
        assertEq(uint8(info.level), uint8(IWhitelistManager.WhitelistLevel.NONE));
        
        vm.stopPrank();
    }
    
    // ============ 转移功能测试 ============
    
    function testTransferWhitelistStatus() public {
        vm.startPrank(operator);
        
        // 先给user1添加VIP状态
        whitelistManager.addToWhitelist(user1, IWhitelistManager.WhitelistLevel.VIP);
        assertTrue(whitelistManager.isVIP(user1));
        
        // 测试转移状态
        vm.expectEmit(true, true, false, true);
        emit WhitelistTransferred(user1, user2, IWhitelistManager.WhitelistLevel.VIP, operator);
        
        whitelistManager.transferWhitelistStatus(user1, user2);
        
        // 验证转移结果
        assertFalse(whitelistManager.isVIP(user1));
        assertTrue(whitelistManager.isVIP(user2));
        
        // 验证统计不变
        (uint256 vipCount,,,) = whitelistManager.getWhitelistStats();
        assertEq(vipCount, 1);
        
        vm.stopPrank();
    }
    
    // ============ 权限控制测试 ============
    
    function testOnlyOperatorCanAdd() public {
        // 非操作员尝试添加白名单应该失败
        vm.startPrank(user1);
        vm.expectRevert("WhitelistManager: caller is not whitelist operator");
        whitelistManager.addToWhitelist(user2, IWhitelistManager.WhitelistLevel.WHITELISTED);
        vm.stopPrank();
    }
    
    function testOnlyAdminCanPause() public {
        // 非管理员尝试暂停应该失败
        vm.startPrank(operator);
        vm.expectRevert("WhitelistManager: caller is not whitelist admin");
        whitelistManager.pause();
        vm.stopPrank();
        
        // 管理员可以暂停
        vm.startPrank(admin);
        whitelistManager.pause();
        assertTrue(whitelistManager.paused());
        vm.stopPrank();
    }
    
    function testPausedFunctionality() public {
        vm.startPrank(admin);
        whitelistManager.pause();
        vm.stopPrank();
        
        // 暂停状态下操作应该失败
        vm.startPrank(operator);
        vm.expectRevert(); // 使用通用的 expectRevert，因为新版本使用自定义错误
        whitelistManager.addToWhitelist(user1, IWhitelistManager.WhitelistLevel.WHITELISTED);
        vm.stopPrank();
    }
    
    // ============ 边界条件测试 ============
    
    function testInvalidAddress() public {
        vm.startPrank(operator);
        
        // 零地址应该失败
        vm.expectRevert("WhitelistManager: invalid address");
        whitelistManager.addToWhitelist(address(0), IWhitelistManager.WhitelistLevel.WHITELISTED);
        
        vm.stopPrank();
    }
    
    function testInvalidExpirationTime() public {
        vm.startPrank(operator);
        
        // 设置当前时间为一个具体值
        vm.warp(1000);
        
        // 过去的时间应该失败
        vm.expectRevert("WhitelistManager: invalid expiration time");
        whitelistManager.addToWhitelistWithExpiration(
            user1, 
            IWhitelistManager.WhitelistLevel.WHITELISTED, 
            999  // 明确的过去时间
        );
        
        vm.stopPrank();
    }
    
    function testBatchSizeLimits() public {
        vm.startPrank(operator);
        
        // 超过最大批量大小应该失败
        address[] memory users = new address[](101); // MAX_BATCH_SIZE = 100
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](101);
        
        vm.expectRevert("WhitelistManager: invalid batch size");
        whitelistManager.batchAddToWhitelist(users, levels);
        
        vm.stopPrank();
    }
    
    function testArrayLengthMismatch() public {
        vm.startPrank(operator);
        
        // 数组长度不匹配应该失败
        address[] memory users = new address[](2);
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](3);
        
        vm.expectRevert("WhitelistManager: arrays length mismatch");
        whitelistManager.batchAddToWhitelist(users, levels);
        
        vm.stopPrank();
    }
    
    // ============ 统计功能测试 ============
    
    function testStatisticsAccuracy() public {
        vm.startPrank(operator);
        
        // 添加不同类型的用户
        whitelistManager.addToWhitelist(user1, IWhitelistManager.WhitelistLevel.VIP);
        whitelistManager.addToWhitelist(user2, IWhitelistManager.WhitelistLevel.WHITELISTED);
        whitelistManager.addToWhitelist(user3, IWhitelistManager.WhitelistLevel.BLACKLISTED);
        
        // 验证统计
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(vipCount, 1);
        assertEq(whitelistedCount, 1);
        assertEq(blacklistedCount, 1);
        assertEq(totalCount, 3);
        
        // 移除一个用户
        whitelistManager.removeFromWhitelist(user1);
        
        // 重新验证统计
        (vipCount, whitelistedCount, blacklistedCount, totalCount) = 
            whitelistManager.getWhitelistStats();
        
        assertEq(vipCount, 0);
        assertEq(whitelistedCount, 1);
        assertEq(blacklistedCount, 1);
        assertEq(totalCount, 2);
        
        vm.stopPrank();
    }
    
    // ============ Gas优化测试 ============
    
    function testBatchOperationGasEfficiency() public {
        vm.startPrank(operator);
        
        // 测试单个操作的Gas消耗
        uint256 gasBefore = gasleft();
        whitelistManager.addToWhitelist(user1, IWhitelistManager.WhitelistLevel.WHITELISTED);
        uint256 singleOpGas = gasBefore - gasleft();
        
        // 重置状态
        whitelistManager.removeFromWhitelist(user1);
        
        // 测试批量操作的Gas消耗
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](2);
        levels[0] = IWhitelistManager.WhitelistLevel.WHITELISTED;
        levels[1] = IWhitelistManager.WhitelistLevel.WHITELISTED;
        
        gasBefore = gasleft();
        whitelistManager.batchAddToWhitelist(users, levels);
        uint256 batchOpGas = gasBefore - gasleft();
        
        // 批量操作应该比两次单个操作更高效
        console.log("Single operation gas:", singleOpGas);
        console.log("Batch operation gas:", batchOpGas);
        console.log("Expected single ops gas:", singleOpGas * 2);
        
        // 批量操作应该节省至少10%的Gas
        assertTrue(batchOpGas < (singleOpGas * 2 * 90) / 100);
        
        vm.stopPrank();
    }
}
