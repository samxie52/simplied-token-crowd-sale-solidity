// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/TokenCrowdsale.sol";
import "../../contracts/CrowdsaleToken.sol";
import "../../contracts/WhitelistManager.sol";
import "../../contracts/interfaces/ICrowdsale.sol";
import "../../contracts/utils/CrowdsaleConstants.sol";

/**
 * @title TokenCrowdsaleTest
 * @dev TokenCrowdsale合约的单元测试
 */
contract TokenCrowdsaleTest is Test {
    
    // 合约实例
    TokenCrowdsale public crowdsale;
    CrowdsaleToken public token;
    WhitelistManager public whitelistManager;
    
    // 测试地址
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address payable public fundingWallet = payable(makeAddr("fundingWallet"));
    
    // 测试常量
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant SOFT_CAP = 10 ether;
    uint256 public constant HARD_CAP = 100 ether;
    uint256 public constant MIN_PURCHASE = 0.1 ether;
    uint256 public constant MAX_PURCHASE = 10 ether;
    
    // 时间常量
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public publicSaleStartTime;
    uint256 public publicSaleEndTime;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // 设置时间
        presaleStartTime = block.timestamp + 1 hours;
        presaleEndTime = presaleStartTime + 7 days;
        publicSaleStartTime = presaleEndTime + 1 hours;
        publicSaleEndTime = publicSaleStartTime + 14 days;
        
        // 部署代币合约
        token = new CrowdsaleToken(
            "Test Token",
            "TEST",
            INITIAL_SUPPLY,
            admin
        );
        
        // 部署白名单管理合约
        whitelistManager = new WhitelistManager(admin);
        
        // 部署众筹合约
        crowdsale = new TokenCrowdsale(
            address(token),
            address(whitelistManager),
            fundingWallet,
            admin
        );
        
        // 配置众筹参数
        ICrowdsale.CrowdsaleConfig memory config = ICrowdsale.CrowdsaleConfig({
            presaleStartTime: presaleStartTime,
            presaleEndTime: presaleEndTime,
            publicSaleStartTime: publicSaleStartTime,
            publicSaleEndTime: publicSaleEndTime,
            softCap: SOFT_CAP,
            hardCap: HARD_CAP,
            minPurchase: MIN_PURCHASE,
            maxPurchase: MAX_PURCHASE
        });
        
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        crowdsale.updateConfig(config);
        
        vm.stopPrank();
    }
    
    // ============ 初始状态测试 ============
    
    function testInitialState() public {
        // 检查初始阶段
        assertEq(uint256(crowdsale.getCurrentPhase()), uint256(ICrowdsale.CrowdsalePhase.PENDING));
        
        // 检查合约地址
        assertEq(address(crowdsale.token()), address(token));
        assertEq(address(crowdsale.whitelistManager()), address(whitelistManager));
        assertEq(crowdsale.fundingWallet(), fundingWallet);
        
        // 检查权限
        assertTrue(crowdsale.hasRole(crowdsale.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(crowdsale.hasRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE, admin));
        assertTrue(crowdsale.hasRole(CrowdsaleConstants.CROWDSALE_OPERATOR_ROLE, admin));
        assertTrue(crowdsale.hasRole(CrowdsaleConstants.EMERGENCY_ROLE, admin));
        
        // 检查初始统计
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        assertEq(stats.totalRaised, 0);
        assertEq(stats.totalTokensSold, 0);
        assertEq(stats.participantCount, 0);
        assertEq(stats.presaleRaised, 0);
        assertEq(stats.publicSaleRaised, 0);
    }
    
    function testConfigurationRetrieval() public {
        ICrowdsale.CrowdsaleConfig memory config = crowdsale.getCrowdsaleConfig();
        
        assertEq(config.presaleStartTime, presaleStartTime);
        assertEq(config.presaleEndTime, presaleEndTime);
        assertEq(config.publicSaleStartTime, publicSaleStartTime);
        assertEq(config.publicSaleEndTime, publicSaleEndTime);
        assertEq(config.softCap, SOFT_CAP);
        assertEq(config.hardCap, HARD_CAP);
        assertEq(config.minPurchase, MIN_PURCHASE);
        assertEq(config.maxPurchase, MAX_PURCHASE);
    }
    
    // ============ 状态管理测试 ============
    
    function testStartPresale() public {
        // 时间推进到预售开始时间
        vm.warp(presaleStartTime);
        
        vm.prank(admin);
        crowdsale.startPresale();
        
        assertEq(uint256(crowdsale.getCurrentPhase()), uint256(ICrowdsale.CrowdsalePhase.PRESALE));
    }
    
    function testStartPresaleTooEarly() public {
        // 在预售开始时间之前尝试开始
        vm.warp(presaleStartTime - 1);
        
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: time window not open");
        crowdsale.startPresale();
    }
    
    function testStartPresaleTooLate() public {
        // 在预售结束时间之后尝试开始
        vm.warp(presaleEndTime + 1);
        
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: time window closed");
        crowdsale.startPresale();
    }
    
    function testStartPublicSale() public {
        // 先开始预售
        vm.warp(presaleStartTime);
        vm.prank(admin);
        crowdsale.startPresale();
        
        // 时间推进到公售开始时间
        vm.warp(publicSaleStartTime);
        
        vm.prank(admin);
        crowdsale.startPublicSale();
        
        assertEq(uint256(crowdsale.getCurrentPhase()), uint256(ICrowdsale.CrowdsalePhase.PUBLIC_SALE));
    }
    
    function testStartPublicSaleFromWrongPhase() public {
        // 直接从PENDING阶段尝试开始公售
        vm.warp(publicSaleStartTime);
        
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: invalid state transition");
        crowdsale.startPublicSale();
    }
    
    function testFinalizeCrowdsale() public {
        // 开始预售
        vm.warp(presaleStartTime);
        vm.prank(admin);
        crowdsale.startPresale();
        
        // 时间推进到预售结束后
        vm.warp(presaleEndTime + 1);
        
        vm.prank(admin);
        crowdsale.finalizeCrowdsale();
        
        assertEq(uint256(crowdsale.getCurrentPhase()), uint256(ICrowdsale.CrowdsalePhase.FINALIZED));
    }
    
    function testFinalizeCrowdsaleFromPendingFails() public {
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: invalid phase");
        crowdsale.finalizeCrowdsale();
    }
    
    // ============ 时间窗口测试 ============
    
    function testTimeWindowValidation() public {
        // 在预售期间
        vm.warp(presaleStartTime);
        vm.prank(admin);
        crowdsale.startPresale();
        
        assertTrue(crowdsale.isInValidTimeWindow());
        
        // 在预售结束后，公售开始前
        vm.warp(presaleEndTime + 30 minutes);
        assertFalse(crowdsale.isInValidTimeWindow());
        
        // 开始公售
        vm.warp(publicSaleStartTime);
        vm.prank(admin);
        crowdsale.startPublicSale();
        
        assertTrue(crowdsale.isInValidTimeWindow());
        
        // 公售结束后
        vm.warp(publicSaleEndTime + 1);
        assertFalse(crowdsale.isInValidTimeWindow());
    }
    
    // ============ 资金目标测试 ============
    
    function testCapReachedChecks() public {
        // 初始状态
        assertFalse(crowdsale.isSoftCapReached());
        assertFalse(crowdsale.isHardCapReached());
        
        // 模拟筹资进度（需要在实际购买功能实现后完善）
        assertEq(crowdsale.getFundingProgress(), 0);
        assertEq(crowdsale.getRemainingFunding(), HARD_CAP);
    }
    
    // ============ 配置更新测试 ============
    
    function testUpdateTimeConfig() public {
        uint256 newPresaleStart = block.timestamp + 2 hours;
        uint256 newPresaleEnd = newPresaleStart + 5 days;
        uint256 newPublicSaleStart = newPresaleEnd + 2 hours;
        uint256 newPublicSaleEnd = newPublicSaleStart + 10 days;
        
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.prank(admin);
        crowdsale.updateTimeConfig(
            newPresaleStart,
            newPresaleEnd,
            newPublicSaleStart,
            newPublicSaleEnd
        );
        
        ICrowdsale.CrowdsaleConfig memory config = crowdsale.getCrowdsaleConfig();
        assertEq(config.presaleStartTime, newPresaleStart);
        assertEq(config.presaleEndTime, newPresaleEnd);
        assertEq(config.publicSaleStartTime, newPublicSaleStart);
        assertEq(config.publicSaleEndTime, newPublicSaleEnd);
    }
    
    function testUpdateTimeConfigInvalidSequence() public {
        // 预售结束时间早于开始时间
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: invalid time sequence");
        crowdsale.updateTimeConfig(
            block.timestamp + 2 hours,
            block.timestamp + 1 hours, // 结束时间早于开始时间
            block.timestamp + 3 hours,
            block.timestamp + 4 hours
        );
    }
    
    function testUpdateFundingTargets() public {
        uint256 newSoftCap = 5 ether;
        uint256 newHardCap = 50 ether;
        
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.prank(admin);
        crowdsale.updateFundingTargets(newSoftCap, newHardCap);
        
        ICrowdsale.CrowdsaleConfig memory config = crowdsale.getCrowdsaleConfig();
        assertEq(config.softCap, newSoftCap);
        assertEq(config.hardCap, newHardCap);
    }
    
    function testUpdateFundingTargetsInvalidRatio() public {
        // 软顶超过硬顶（无效）
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.prank(admin);
        vm.expectRevert("TokenCrowdsale: invalid funding targets");
        crowdsale.updateFundingTargets(100 ether, 50 ether); // 软顶大于硬顶
    }
    
    function testUpdatePurchaseLimits() public {
        uint256 newMinPurchase = 0.05 ether;
        uint256 newMaxPurchase = 20 ether;
        
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.prank(admin);
        crowdsale.updatePurchaseLimits(newMinPurchase, newMaxPurchase);
        
        ICrowdsale.CrowdsaleConfig memory config = crowdsale.getCrowdsaleConfig();
        assertEq(config.minPurchase, newMinPurchase);
        assertEq(config.maxPurchase, newMaxPurchase);
    }
    
    function testUpdateFundingWallet() public {
        address payable newWallet = payable(makeAddr("newWallet"));
        
        vm.prank(admin);
        crowdsale.updateFundingWallet(newWallet);
        
        assertEq(crowdsale.fundingWallet(), newWallet);
    }
    
    // ============ 权限控制测试 ============
    
    function testOnlyAdminCanStartPresale() public {
        vm.warp(presaleStartTime);
        
        vm.prank(user1);
        vm.expectRevert();
        crowdsale.startPresale();
    }
    
    function testOnlyAdminCanUpdateConfig() public {
        ICrowdsale.CrowdsaleConfig memory config = crowdsale.getCrowdsaleConfig();
        
        vm.prank(user1);
        vm.expectRevert();
        crowdsale.updateConfig(config);
    }
    
    function testOnlyEmergencyRoleCanPause() public {
        vm.prank(user1);
        vm.expectRevert();
        crowdsale.emergencyPause("test");
    }
    
    // ============ 紧急控制测试 ============
    
    function testEmergencyPause() public {
        assertFalse(crowdsale.paused());
        
        vm.prank(admin);
        crowdsale.emergencyPause("Emergency test");
        
        assertTrue(crowdsale.paused());
        assertGt(crowdsale.emergencyPauseStartTime(), 0);
    }
    
    function testEmergencyResume() public {
        // 先暂停
        vm.prank(admin);
        crowdsale.emergencyPause("Emergency test");
        
        assertTrue(crowdsale.paused());
        
        // 恢复
        vm.prank(admin);
        crowdsale.emergencyResume("Emergency resolved");
        
        assertFalse(crowdsale.paused());
        assertEq(crowdsale.emergencyPauseStartTime(), 0);
    }
    
    function testEmergencyPauseDurationLimit() public {
        // 暂停
        vm.prank(admin);
        crowdsale.emergencyPause("Long emergency");
        
        // 时间推进超过最大暂停时间
        vm.warp(block.timestamp + CrowdsaleConstants.MAX_EMERGENCY_PAUSE_DURATION + 1);
        
        // 尝试恢复应该失败
        vm.prank(admin);
        vm.expectRevert("TokenCrowdsale: emergency pause duration exceeded");
        crowdsale.emergencyResume("Too late");
    }
    
    // ============ 配置更新冷却时间测试 ============
    
    function testConfigUpdateCooldown() public {
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        // 第一次更新
        vm.prank(admin);
        crowdsale.updateFundingTargets(5 ether, 50 ether);
        
        // 立即尝试第二次更新应该失败
        vm.prank(admin);
        vm.expectRevert("TokenCrowdsale: config update cooldown not passed");
        crowdsale.updateFundingTargets(6 ether, 60 ether);
        
        // 等待冷却时间后应该成功
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.prank(admin);
        crowdsale.updateFundingTargets(6 ether, 60 ether);
    }
    
    // ============ 事件测试 ============
    
    function testPhaseChangeEvent() public {
        vm.warp(presaleStartTime);
        
        vm.expectEmit(true, true, false, true);
        emit ICrowdsale.PhaseChanged(
            ICrowdsale.CrowdsalePhase.PENDING,
            ICrowdsale.CrowdsalePhase.PRESALE,
            block.timestamp,
            admin
        );
        
        vm.prank(admin);
        crowdsale.startPresale();
    }
    
    function testConfigUpdateEvent() public {
        ICrowdsale.CrowdsaleConfig memory newConfig = ICrowdsale.CrowdsaleConfig({
            presaleStartTime: block.timestamp + 2 hours,
            presaleEndTime: block.timestamp + 9 days,
            publicSaleStartTime: block.timestamp + 10 days,
            publicSaleEndTime: block.timestamp + 24 days,
            softCap: 5 ether,
            hardCap: 50 ether,
            minPurchase: 0.05 ether,
            maxPurchase: 20 ether
        });
        
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        
        vm.expectEmit(false, false, false, true);
        emit ICrowdsale.ConfigUpdated(newConfig, admin);
        
        vm.prank(admin);
        crowdsale.updateConfig(newConfig);
    }
    
    // ============ 边界条件测试 ============
    
    function testZeroAddressValidation() public {
        vm.expectRevert("CrowdsaleConstants: invalid address");
        new TokenCrowdsale(
            address(0), // 无效地址
            address(whitelistManager),
            fundingWallet,
            admin
        );
    }
    
    function testInvalidPhaseTransitions() public {
        // 尝试从PENDING直接到FINALIZED
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: invalid phase");
        crowdsale.finalizeCrowdsale();
        
        // 尝试从PENDING直接到PUBLIC_SALE
        vm.warp(publicSaleStartTime);
        vm.prank(admin);
        vm.expectRevert("CrowdsaleConstants: invalid state transition");
        crowdsale.startPublicSale();
    }
    
    // ============ 辅助函数测试 ============
    
    function testHasUserParticipated() public {
        assertFalse(crowdsale.hasUserParticipated(user1));
        // 注意：实际参与逻辑将在购买功能中实现
    }
}
