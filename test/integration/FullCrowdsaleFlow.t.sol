// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/CrowdsaleFactory.sol";
import "../../contracts/TokenCrowdsale.sol";
import "../../contracts/CrowdsaleToken.sol";
import "../../contracts/TokenVesting.sol";
import "../../contracts/WhitelistManager.sol";
import "../../contracts/RefundVault.sol";
import "../../contracts/interfaces/ICrowdsaleFactory.sol";
import "../../contracts/interfaces/ITokenVesting.sol";

contract FullCrowdsaleFlowTest is Test {
    
    // ============ 测试合约实例 ============
    
    CrowdsaleFactory public factory;
    TokenCrowdsale public crowdsale;
    CrowdsaleToken public token;
    TokenVesting public vesting;
    WhitelistManager public whitelist;
    RefundVault public vault;
    
    // ============ 测试角色地址 ============
    
    address public admin = makeAddr("admin");
    address public creator = makeAddr("creator");
    address public fundingWallet = makeAddr("fundingWallet");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public investor3 = makeAddr("investor3");
    address public whitelistUser = makeAddr("whitelistUser");
    
    // ============ 测试常量 ============
    
    uint256 public constant CREATION_FEE = 0.1 ether;
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant SOFT_CAP = 100 ether;
    uint256 public constant HARD_CAP = 500 ether;
    uint256 public constant TOKEN_PRICE = 0.001 ether; // 1 ETH = 1000 tokens
    
    // ============ 设置函数 ============
    
    function setUp() public {
        vm.startPrank(admin);
        
        // 部署工厂合约
        factory = new CrowdsaleFactory(CREATION_FEE, true);
        
        // 给创建者和投资者分配ETH
        vm.deal(creator, 1000 ether);
        vm.deal(investor1, 100 ether);
        vm.deal(investor2, 100 ether);
        vm.deal(investor3, 100 ether);
        vm.deal(whitelistUser, 100 ether);
        vm.deal(fundingWallet, 1 ether);
        
        vm.stopPrank();
    }
    
    // ============ 完整流程测试 ============
    
    function test_SuccessfulCrowdsaleFlow() public {
        // 1. 创建众筹
        _createCrowdsale();
        
        // 2. 配置白名单
        _setupWhitelist();
        
        // 3. 启动众筹
        _startCrowdsale();
        
        // 4. 预售阶段购买
        _presalePurchases();
        
        // 5. 公售阶段购买
        _publicSalePurchases();
        
        // 6. 完成众筹
        _finalizeCrowdsale();
        
        // 7. 验证代币释放
        _verifyVesting();
        
        // 8. 验证最终状态
        _verifyFinalState();
    }
    
    function test_FailedCrowdsaleFlow() public {
        // 1. 创建众筹
        _createCrowdsale();
        
        // 2. 启动众筹但购买不足
        _startCrowdsale();
        _insufficientPurchases();
        
        // 3. 众筹失败，启用退款
        _failCrowdsale();
        
        // 4. 用户申请退款
        _processRefunds();
        
        // 5. 验证退款状态
        _verifyRefundState();
    }
    
    function test_MixedScenarioFlow() public {
        // 1. 创建众筹
        _createCrowdsale();
        
        // 2. 启动众筹
        _startCrowdsale();
        
        // 3. 部分用户购买
        _partialPurchases();
        
        // 4. 紧急暂停
        _emergencyPause();
        
        // 5. 恢复并继续
        _resumeAndComplete();
        
        // 6. 验证混合状态
        _verifyMixedState();
    }
    
    // ============ 内部辅助函数 ============
    
    function _createCrowdsale() internal {
        vm.startPrank(creator);
        
        ICrowdsaleFactory.VestingParams memory vestingParams = ICrowdsaleFactory.VestingParams({
            enabled: true,
            cliffDuration: 30 days,
            vestingDuration: 365 days,
            vestingType: ITokenVesting.VestingType.LINEAR,
            immediateReleasePercentage: 1000 // 10%
        });
        
        ICrowdsaleFactory.CrowdsaleParams memory params = ICrowdsaleFactory.CrowdsaleParams({
            tokenName: "Test Token",
            tokenSymbol: "TEST",
            totalSupply: TOTAL_SUPPLY,
            softCap: SOFT_CAP,
            hardCap: HARD_CAP,
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 30 days,
            fundingWallet: fundingWallet,
            tokenPrice: TOKEN_PRICE,
            vestingParams: vestingParams
        });
        
        (address crowdsaleAddr, address tokenAddr, address vestingAddr) = 
            factory.createCrowdsale{value: CREATION_FEE}(params);
        
        crowdsale = TokenCrowdsale(crowdsaleAddr);
        token = CrowdsaleToken(tokenAddr);
        vesting = TokenVesting(vestingAddr);
        
        // 获取其他合约地址
        whitelist = WhitelistManager(address(crowdsale.whitelistManager()));
        vault = RefundVault(payable(address(crowdsale.refundVault())));
        
        vm.stopPrank();
        
        // 验证创建成功
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }
    
    function _setupWhitelist() internal {
        vm.startPrank(creator);
        
        // 添加白名单用户
        address[] memory users = new address[](1);
        users[0] = whitelistUser;
        
        IWhitelistManager.WhitelistLevel[] memory levels = new IWhitelistManager.WhitelistLevel[](1);
        levels[0] = IWhitelistManager.WhitelistLevel.VIP;
        
        whitelist.batchAddToWhitelist(users, levels);
        
        vm.stopPrank();
        
        // 验证白名单设置
        assertTrue(whitelist.isWhitelisted(whitelistUser));
        assertTrue(whitelist.isVIP(whitelistUser));
    }
    
    function _startCrowdsale() internal {
        // 时间推进到开始时间
        vm.warp(block.timestamp + 1 days);
        
        vm.prank(creator);
        crowdsale.startPresale();
        
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.PRESALE));
    }
    
    function _presalePurchases() internal {
        // 白名单用户购买（享受折扣）
        vm.prank(whitelistUser);
        crowdsale.purchaseTokens{value: 10 ether}();
        
        // 验证购买记录
        assertTrue(crowdsale.hasParticipated(whitelistUser));
        assertGt(crowdsale.totalPurchased(whitelistUser), 0);
    }
    
    function _publicSalePurchases() internal {
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.PUBLIC_SALE));
        
        // 多个投资者购买
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: 30 ether}();
        
        vm.prank(investor2);
        crowdsale.purchaseTokens{value: 40 ether}();
        
        vm.prank(investor3);
        crowdsale.purchaseTokens{value: 50 ether}();
        
        // 验证购买记录
        assertTrue(crowdsale.hasParticipated(investor1));
        assertTrue(crowdsale.hasParticipated(investor2));
        assertTrue(crowdsale.hasParticipated(investor3));
    }
    
    function _finalizeCrowdsale() internal {
        // 时间推进到结束时间
        vm.warp(block.timestamp + 30 days);
        
        vm.prank(creator);
        crowdsale.finalizeCrowdsale();
        
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.FINALIZED));
        
        // 验证资金已释放
        assertGt(fundingWallet.balance, 0);
    }
    
    function _verifyVesting() internal {
        // 验证释放计划已创建
        uint256[] memory schedules = vesting.getBeneficiarySchedules(whitelistUser);
        assertGt(schedules.length, 0);
        
        // 验证立即释放的代币
        uint256 immediateTokens = token.balanceOf(whitelistUser);
        assertGt(immediateTokens, 0);
        
        // 时间推进测试释放
        vm.warp(block.timestamp + 100 days);
        
        uint256 releasableAmount = vesting.getReleasableAmount(schedules[0]);
        if (releasableAmount > 0) {
            vm.prank(whitelistUser);
            vesting.release(schedules[0]);
            
            assertGt(token.balanceOf(whitelistUser), immediateTokens);
        }
    }
    
    function _verifyFinalState() internal {
        // 验证众筹统计
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        assertGt(stats.totalRaised, SOFT_CAP);
        assertGt(stats.totalParticipants, 0);
        assertGt(stats.totalTokensSold, 0);
        
        // 验证代币分发
        uint256 totalDistributed = token.balanceOf(whitelistUser) + 
                                  token.balanceOf(investor1) + 
                                  token.balanceOf(investor2) + 
                                  token.balanceOf(investor3);
        assertGt(totalDistributed, 0);
    }
    
    function _insufficientPurchases() internal {
        // 只有少量购买，不足软顶
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: 10 ether}();
        
        vm.prank(investor2);
        crowdsale.purchaseTokens{value: 15 ether}();
        
        // 验证未达软顶
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        assertLt(stats.totalRaised, SOFT_CAP);
    }
    
    function _failCrowdsale() internal {
        // 时间推进到结束时间
        vm.warp(block.timestamp + 30 days);
        
        vm.prank(creator);
        crowdsale.finalizeCrowdsale();
        
        // 验证众筹失败，退款已启用
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.FINALIZED));
        // 验证退款状态
        // 注意：这里需要根据实际的RefundVault实现来验证
    }
    
    function _processRefunds() internal {
        // 用户申请退款
        uint256 investor1BalanceBefore = investor1.balance;
        uint256 investor2BalanceBefore = investor2.balance;
        
        vm.prank(investor1);
        vault.refund(investor1);
        
        vm.prank(investor2);
        vault.refund(investor2);
        
        // 验证退款成功
        assertGt(investor1.balance, investor1BalanceBefore);
        assertGt(investor2.balance, investor2BalanceBefore);
    }
    
    function _verifyRefundState() internal {
        // 验证用户已收到退款
        // 验证代币未分发
        assertEq(token.balanceOf(investor1), 0);
        assertEq(token.balanceOf(investor2), 0);
    }
    
    function _partialPurchases() internal {
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: 20 ether}();
        
        vm.prank(investor2);
        crowdsale.purchaseTokens{value: 30 ether}();
    }
    
    function _emergencyPause() internal {
        vm.prank(creator);
        crowdsale.emergencyPause("Test emergency pause");
        
        assertTrue(crowdsale.paused());
        
        // 验证暂停期间无法购买
        vm.expectRevert();
        vm.prank(investor3);
        crowdsale.purchaseTokens{value: 10 ether}();
    }
    
    function _resumeAndComplete() internal {
        vm.prank(creator);
        crowdsale.emergencyResume("Test emergency resume");
        
        assertFalse(crowdsale.paused());
        
        // 继续购买达到软顶
        vm.prank(investor3);
        crowdsale.purchaseTokens{value: 60 ether}();
        
        // 完成众筹
        vm.warp(block.timestamp + 30 days);
        vm.prank(creator);
        crowdsale.finalizeCrowdsale();
    }
    
    function _verifyMixedState() internal {
        // 验证部分用户有代币，部分用户可能需要退款
        assertGt(token.balanceOf(investor1), 0);
        assertGt(token.balanceOf(investor2), 0);
        assertGt(token.balanceOf(investor3), 0);
    }
    
    // ============ 边界条件测试 ============
    
    function test_HardCapReached() public {
        _createCrowdsale();
        _startCrowdsale();
        
        // 购买达到硬顶
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: HARD_CAP}();
        
        // 验证无法继续购买
        vm.expectRevert();
        vm.prank(investor2);
        crowdsale.purchaseTokens{value: 1 ether}();
        
        // 验证自动完成
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.FINALIZED));
    }
    
    function test_TimeBasedCompletion() public {
        _createCrowdsale();
        _startCrowdsale();
        
        // 购买超过软顶但未达硬顶
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: SOFT_CAP + 10 ether}();
        
        // 时间到期
        vm.warp(block.timestamp + 30 days);
        
        vm.prank(creator);
        crowdsale.finalizeCrowdsale();
        
        // 验证成功完成
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.FINALIZED));
    }
    
    function test_BatchOperations() public {
        _createCrowdsale();
        _setupWhitelist();
        _startCrowdsale();
        
        // 批量购买
        address[] memory buyers = new address[](3);
        buyers[0] = investor1;
        buyers[1] = investor2;
        buyers[2] = investor3;
        
        for (uint256 i = 0; i < buyers.length; i++) {
            vm.prank(buyers[i]);
            crowdsale.purchaseTokens{value: 30 ether}();
        }
        
        _finalizeCrowdsale();
        
        // 批量释放
        uint256[] memory scheduleIds = new uint256[](3);
        for (uint256 i = 0; i < buyers.length; i++) {
            uint256[] memory userSchedules = vesting.getBeneficiarySchedules(buyers[i]);
            if (userSchedules.length > 0) {
                scheduleIds[i] = userSchedules[0];
            }
        }
        
        vm.warp(block.timestamp + 100 days);
        
        // 这里需要实现批量释放功能
        // vm.prank(creator);
        // vesting.batchRelease(scheduleIds);
    }
    
    // ============ Gas优化测试 ============
    
    function test_GasOptimization() public {
        _createCrowdsale();
        _startCrowdsale();
        
        // 测试单次购买Gas消耗
        uint256 gasBefore = gasleft();
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: 10 ether}();
        uint256 gasUsed = gasBefore - gasleft();
        
        // 验证Gas消耗在合理范围内
        assertTrue(gasUsed < 200_000, "Purchase gas too high");
        
        // 测试完成众筹Gas消耗
        vm.warp(block.timestamp + 30 days);
        
        gasBefore = gasleft();
        vm.prank(creator);
        crowdsale.finalizeCrowdsale();
        gasUsed = gasBefore - gasleft();
        
        assertTrue(gasUsed < 500_000, "Finalization gas too high");
    }
    
    // ============ 安全测试 ============
    
    function test_SecurityMeasures() public {
        _createCrowdsale();
        _startCrowdsale();
        
        // 测试重入攻击防护
        // 这里需要创建恶意合约来测试
        
        // 测试权限控制
        vm.expectRevert();
        vm.prank(investor1);
        crowdsale.finalizeCrowdsale();
        
        // 测试参数验证
        vm.expectRevert();
        vm.prank(investor1);
        crowdsale.purchaseTokens{value: 0}();
    }
    
    // ============ 工厂功能测试 ============
    
    function test_FactoryManagement() public {
        // 测试工厂统计
        (uint256 totalCrowdsales, uint256 activeCrowdsales, uint256 totalFees) = 
            factory.getFactoryStats();
        
        assertEq(totalCrowdsales, 0);
        assertEq(activeCrowdsales, 0);
        assertEq(totalFees, 0);
        
        // 创建众筹后重新检查
        _createCrowdsale();
        
        (totalCrowdsales, activeCrowdsales, totalFees) = factory.getFactoryStats();
        assertEq(totalCrowdsales, 1);
        assertEq(activeCrowdsales, 1);
        assertEq(totalFees, CREATION_FEE);
        
        // 测试众筹查询
        ICrowdsaleFactory.CrowdsaleInstance memory instance = 
            factory.getCrowdsaleInstance(address(crowdsale));
        
        assertEq(instance.creator, creator);
        assertTrue(instance.isActive);
        assertEq(instance.tokenAddress, address(token));
    }
}
