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

contract MultiUserScenariosTest is Test {
    
    // ============ 测试合约实例 ============
    
    CrowdsaleFactory public factory;
    TokenCrowdsale public crowdsale;
    CrowdsaleToken public token;
    TokenVesting public vesting;
    WhitelistManager public whitelist;
    RefundVault public vault;
    
    // ============ 多用户地址池 ============
    
    address public admin = makeAddr("admin");
    address public creator = makeAddr("creator");
    address public fundingWallet = makeAddr("fundingWallet");
    
    // 大量投资者地址
    address[] public investors;
    address[] public whitelistUsers;
    address[] public vipUsers;
    
    uint256 public constant NUM_INVESTORS = 50;
    uint256 public constant NUM_WHITELIST = 20;
    uint256 public constant NUM_VIP = 10;
    
    // ============ 测试常量 ============
    
    uint256 public constant CREATION_FEE = 0.1 ether;
    uint256 public constant TOTAL_SUPPLY = 50_000_000 * 1e18;
    uint256 public constant SOFT_CAP = 500 ether;
    uint256 public constant HARD_CAP = 2000 ether;
    uint256 public constant TOKEN_PRICE = 0.001 ether;
    
    // ============ 设置函数 ============
    
    function setUp() public {
        vm.startPrank(admin);
        
        // 部署工厂合约
        factory = new CrowdsaleFactory(CREATION_FEE, true);
        
        // 创建投资者地址池
        _createInvestorPool();
        
        // 给所有用户分配ETH
        _fundUsers();
        
        vm.stopPrank();
    }
    
    function _createInvestorPool() internal {
        // 创建普通投资者
        for (uint256 i = 0; i < NUM_INVESTORS; i++) {
            investors.push(makeAddr(string(abi.encodePacked("investor", i))));
        }
        
        // 创建白名单用户
        for (uint256 i = 0; i < NUM_WHITELIST; i++) {
            whitelistUsers.push(makeAddr(string(abi.encodePacked("whitelist", i))));
        }
        
        // 创建VIP用户
        for (uint256 i = 0; i < NUM_VIP; i++) {
            vipUsers.push(makeAddr(string(abi.encodePacked("vip", i))));
        }
    }
    
    function _fundUsers() internal {
        vm.deal(creator, 1000 ether);
        vm.deal(fundingWallet, 1 ether);
        
        // 给投资者分配ETH
        for (uint256 i = 0; i < investors.length; i++) {
            vm.deal(investors[i], 100 ether);
        }
        
        for (uint256 i = 0; i < whitelistUsers.length; i++) {
            vm.deal(whitelistUsers[i], 150 ether);
        }
        
        for (uint256 i = 0; i < vipUsers.length; i++) {
            vm.deal(vipUsers[i], 200 ether);
        }
    }
    
    function _createCrowdsale() internal {
        vm.startPrank(creator);
        
        ICrowdsaleFactory.VestingParams memory vestingParams = ICrowdsaleFactory.VestingParams({
            enabled: true,
            cliffDuration: 90 days,
            vestingDuration: 730 days, // 2年
            vestingType: ITokenVesting.VestingType.LINEAR,
            immediateReleasePercentage: 2000 // 20%
        });
        
        ICrowdsaleFactory.CrowdsaleParams memory params = ICrowdsaleFactory.CrowdsaleParams({
            tokenName: "MultiUser Token",
            tokenSymbol: "MUT",
            totalSupply: TOTAL_SUPPLY,
            softCap: SOFT_CAP,
            hardCap: HARD_CAP,
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 60 days,
            fundingWallet: fundingWallet,
            tokenPrice: TOKEN_PRICE,
            vestingParams: vestingParams
        });
        
        (address crowdsaleAddr, address tokenAddr, address vestingAddr) = 
            factory.createCrowdsale{value: CREATION_FEE}(params);
        
        crowdsale = TokenCrowdsale(crowdsaleAddr);
        token = CrowdsaleToken(tokenAddr);
        vesting = TokenVesting(vestingAddr);
        
        whitelist = WhitelistManager(address(crowdsale.whitelistManager()));
        vault = RefundVault(payable(address(crowdsale.refundVault())));
        
        vm.stopPrank();
    }
    
    function _setupWhitelist() internal {
        vm.startPrank(creator);
        
        // 批量添加白名单用户
        IWhitelistManager.WhitelistLevel[] memory whitelistLevels = new IWhitelistManager.WhitelistLevel[](whitelistUsers.length);
        for (uint256 i = 0; i < whitelistUsers.length; i++) {
            whitelistLevels[i] = IWhitelistManager.WhitelistLevel.WHITELISTED;
        }
        whitelist.batchAddToWhitelist(whitelistUsers, whitelistLevels);
        
        // 设置VIP用户
        IWhitelistManager.WhitelistLevel[] memory vipLevels = new IWhitelistManager.WhitelistLevel[](vipUsers.length);
        for (uint256 i = 0; i < vipUsers.length; i++) {
            vipLevels[i] = IWhitelistManager.WhitelistLevel.VIP;
        }
        whitelist.batchAddToWhitelist(vipUsers, vipLevels);
        
        vm.stopPrank();
    }
    
    // ============ 大规模并发测试 ============
    
    function test_MassiveConcurrentPurchases() public {
        _createCrowdsale();
        _setupWhitelist();
        
        // 启动众筹
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPresale();
        
        // 记录开始时间
        uint256 startGas = gasleft();
        
        // 白名单用户预售购买
        for (uint256 i = 0; i < whitelistUsers.length; i++) {
            vm.prank(whitelistUsers[i]);
            crowdsale.purchaseTokens{value: 5 ether}();
        }
        
        // VIP用户预售购买
        for (uint256 i = 0; i < vipUsers.length; i++) {
            vm.prank(vipUsers[i]);
            crowdsale.purchaseTokens{value: 10 ether}();
        }
        
        // 启动公售
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 大量普通投资者购买
        for (uint256 i = 0; i < investors.length; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 8 ether}();
        }
        
        uint256 gasUsed = startGas - gasleft();
        console.log("Total gas used for", NUM_INVESTORS + NUM_WHITELIST + NUM_VIP, "purchases:", gasUsed);
        
        // 验证购买结果
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        assertEq(stats.totalParticipants, NUM_INVESTORS + NUM_WHITELIST + NUM_VIP);
        assertGt(stats.totalRaised, SOFT_CAP);
        
        // 验证每个用户都有购买记录
        for (uint256 i = 0; i < investors.length; i++) {
            assertTrue(crowdsale.hasParticipated(investors[i]));
        }
    }
    
    function test_StaggeredPurchasePattern() public {
        _createCrowdsale();
        _setupWhitelist();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPresale();
        
        // 阶段1：VIP用户大额购买
        for (uint256 i = 0; i < vipUsers.length; i++) {
            vm.prank(vipUsers[i]);
            crowdsale.purchaseTokens{value: 20 ether}();
            
            // 模拟时间间隔
            vm.warp(block.timestamp + 1 hours);
        }
        
        // 阶段2：白名单用户中等购买
        for (uint256 i = 0; i < whitelistUsers.length; i++) {
            vm.prank(whitelistUsers[i]);
            crowdsale.purchaseTokens{value: 10 ether}();
            
            vm.warp(block.timestamp + 30 minutes);
        }
        
        // 启动公售
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 阶段3：普通投资者小额购买
        for (uint256 i = 0; i < investors.length; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 5 ether}();
            
            if (i % 10 == 0) {
                vm.warp(block.timestamp + 15 minutes);
            }
        }
        
        // 验证不同用户群体的购买模式
        _verifyPurchasePatterns();
    }
    
    function test_RandomizedPurchaseBehavior() public {
        _createCrowdsale();
        _setupWhitelist();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 使用伪随机数模拟真实购买行为
        uint256 seed = 12345;
        
        for (uint256 round = 0; round < 5; round++) {
            // 随机选择用户进行购买
            for (uint256 i = 0; i < 20; i++) {
                seed = uint256(keccak256(abi.encode(seed, block.timestamp, i)));
                
                // 随机选择用户类型
                uint256 userType = seed % 3;
                address buyer;
                uint256 amount;
                
                if (userType == 0 && investors.length > 0) {
                    buyer = investors[seed % investors.length];
                    amount = (seed % 10 + 1) * 1 ether; // 1-10 ETH
                } else if (userType == 1 && whitelistUsers.length > 0) {
                    buyer = whitelistUsers[seed % whitelistUsers.length];
                    amount = (seed % 15 + 5) * 1 ether; // 5-20 ETH
                } else if (vipUsers.length > 0) {
                    buyer = vipUsers[seed % vipUsers.length];
                    amount = (seed % 25 + 10) * 1 ether; // 10-35 ETH
                } else {
                    continue;
                }
                
                // 检查是否已经购买过（避免重复）
                if (!crowdsale.hasParticipated(buyer)) {
                    vm.prank(buyer);
                    crowdsale.purchaseTokens{value: amount}();
                }
                
                // 随机时间间隔
                vm.warp(block.timestamp + (seed % 3600)); // 0-1小时
            }
            
            // 每轮之间的较长间隔
            vm.warp(block.timestamp + 1 days);
        }
        
        // 验证随机购买结果
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        assertGt(stats.totalParticipants, 0);
        console.log("Random purchase participants:", stats.totalParticipants);
        console.log("Total raised:", stats.totalRaised);
    }
    
    // ============ 压力测试 ============
    
    function test_HighVolumeTransactions() public {
        _createCrowdsale();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        uint256 startTime = block.timestamp;
        
        // 短时间内大量交易
        for (uint256 i = 0; i < investors.length && i < 30; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 15 ether}();
            
            // 每10笔交易推进1分钟
            if (i % 10 == 9) {
                vm.warp(block.timestamp + 1 minutes);
            }
        }
        
        uint256 endTime = block.timestamp;
        uint256 duration = endTime - startTime;
        
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        uint256 tps = stats.totalPurchases * 60 / duration; // 每分钟交易数
        
        console.log("Transactions per minute:", tps);
        console.log("Total duration (seconds):", duration);
        
        // 验证高频交易不影响数据一致性
        assertEq(stats.totalPurchases, stats.totalParticipants);
    }
    
    function test_MemoryAndStorageEfficiency() public {
        _createCrowdsale();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 测试大量用户数据存储
        uint256 initialGas = gasleft();
        
        for (uint256 i = 0; i < 100 && i < investors.length; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 5 ether}();
        }
        
        uint256 gasPerPurchase = (initialGas - gasleft()) / 100;
        console.log("Average gas per purchase:", gasPerPurchase);
        
        // 验证Gas效率
        assertTrue(gasPerPurchase < 150_000, "Gas per purchase too high");
        
        // 测试查询效率
        uint256 queryGas = gasleft();
        for (uint256 i = 0; i < 50; i++) {
            crowdsale.hasParticipated(investors[i]);
            crowdsale.totalPurchased(investors[i]);
        }
        uint256 queryGasUsed = queryGas - gasleft();
        
        console.log("Query gas for 50 users:", queryGasUsed);
        assertTrue(queryGasUsed < 50_000, "Query gas too high");
    }
    
    // ============ 复杂场景测试 ============
    
    function test_MixedSuccessFailureScenario() public {
        _createCrowdsale();
        _setupWhitelist();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 部分用户成功购买
        for (uint256 i = 0; i < 20; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 10 ether}();
        }
        
        // 部分用户尝试购买但失败（余额不足等）
        for (uint256 i = 20; i < 30; i++) {
            vm.deal(investors[i], 0.5 ether); // 设置余额不足
            
            vm.expectRevert();
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 10 ether}();
        }
        
        // 紧急暂停
        vm.prank(creator);
        crowdsale.emergencyPause("Test emergency pause");
        
        // 暂停期间所有购买都失败
        for (uint256 i = 30; i < 35; i++) {
            vm.expectRevert();
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 5 ether}();
        }
        
        // 恢复并继续
        vm.prank(creator);
        crowdsale.emergencyResume("Test emergency resume");
        
        // 剩余用户继续购买
        for (uint256 i = 30; i < 40; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 8 ether}();
        }
        
        // 验证最终状态
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        assertEq(stats.totalParticipants, 30); // 20 + 10成功购买
        
        // 验证失败的用户没有购买记录
        for (uint256 i = 20; i < 30; i++) {
            assertFalse(crowdsale.hasParticipated(investors[i]));
        }
    }
    
    function test_VestingWithManyBeneficiaries() public {
        _createCrowdsale();
        _setupWhitelist();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 大量用户购买
        for (uint256 i = 0; i < 30; i++) {
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: 10 ether}();
        }
        
        // 完成众筹
        vm.warp(block.timestamp + 60 days);
        vm.prank(creator);
        crowdsale.finalizeCrowdsale();
        
        // 验证所有用户都有释放计划
        uint256 totalSchedules = 0;
        for (uint256 i = 0; i < 30; i++) {
            uint256[] memory schedules = vesting.getBeneficiarySchedules(investors[i]);
            assertGt(schedules.length, 0);
            totalSchedules += schedules.length;
        }
        
        console.log("Total vesting schedules created:", totalSchedules);
        
        // 时间推进测试批量释放
        vm.warp(block.timestamp + 200 days);
        
        uint256 releaseGas = gasleft();
        
        // 模拟用户释放代币
        for (uint256 i = 0; i < 10; i++) {
            uint256[] memory schedules = vesting.getBeneficiarySchedules(investors[i]);
            if (schedules.length > 0) {
                uint256 releasable = vesting.getReleasableAmount(schedules[0]);
                if (releasable > 0) {
                    vm.prank(investors[i]);
                    vesting.release(schedules[0]);
                }
            }
        }
        
        uint256 releaseGasUsed = releaseGas - gasleft();
        console.log("Gas used for 10 releases:", releaseGasUsed);
    }
    
    // ============ 辅助验证函数 ============
    
    function _verifyPurchasePatterns() internal {
        // 验证VIP用户平均购买额最高
        uint256 vipAverage = 0;
        for (uint256 i = 0; i < vipUsers.length; i++) {
            vipAverage += crowdsale.totalPurchased(vipUsers[i]);
        }
        vipAverage /= vipUsers.length;
        
        // 验证白名单用户平均购买额中等
        uint256 whitelistAverage = 0;
        for (uint256 i = 0; i < whitelistUsers.length; i++) {
            whitelistAverage += crowdsale.totalPurchased(whitelistUsers[i]);
        }
        whitelistAverage /= whitelistUsers.length;
        
        // 验证普通用户平均购买额最低
        uint256 investorAverage = 0;
        uint256 participantCount = 0;
        for (uint256 i = 0; i < investors.length; i++) {
            if (crowdsale.hasParticipated(investors[i])) {
                investorAverage += crowdsale.totalPurchased(investors[i]);
                participantCount++;
            }
        }
        if (participantCount > 0) {
            investorAverage /= participantCount;
        }
        
        console.log("VIP average purchase:", vipAverage);
        console.log("Whitelist average purchase:", whitelistAverage);
        console.log("Investor average purchase:", investorAverage);
        
        // 验证购买模式符合预期
        assertGt(vipAverage, whitelistAverage);
        assertGt(whitelistAverage, investorAverage);
    }
    
    // ============ 边界和异常测试 ============
    
    function test_EdgeCaseHandling() public {
        _createCrowdsale();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 测试最小购买金额
        vm.prank(investors[0]);
        crowdsale.purchaseTokens{value: 1 wei}();
        
        // 测试接近硬顶的购买
        uint256 nearHardCap = HARD_CAP - 1 ether;
        
        // 先购买到接近硬顶
        for (uint256 i = 1; i < investors.length; i++) {
            uint256 amount = 30 ether;
            if (crowdsale.getCrowdsaleStats().totalRaised + amount >= nearHardCap) {
                break;
            }
            
            vm.prank(investors[i]);
            crowdsale.purchaseTokens{value: amount}();
        }
        
        // 最后一笔购买刚好达到硬顶
        uint256 remaining = HARD_CAP - crowdsale.getCrowdsaleStats().totalRaised;
        if (remaining > 0) {
            vm.prank(investors[investors.length - 1]);
            crowdsale.purchaseTokens{value: remaining}();
        }
        
        // 验证达到硬顶后自动完成
        assertEq(uint256(crowdsale.currentPhase()), uint256(ICrowdsale.CrowdsalePhase.FINALIZED));
    }
    
    function test_ConcurrentAccessControl() public {
        _createCrowdsale();
        
        vm.warp(block.timestamp + 1 days);
        vm.prank(creator);
        crowdsale.startPublicSale();
        
        // 模拟多个用户同时尝试管理操作
        address[] memory unauthorizedUsers = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            unauthorizedUsers[i] = investors[i];
        }
        
        // 所有未授权用户尝试管理操作都应失败
        for (uint256 i = 0; i < unauthorizedUsers.length; i++) {
            vm.expectRevert();
            vm.prank(unauthorizedUsers[i]);
            crowdsale.finalizeCrowdsale();
            
            vm.expectRevert();
            vm.prank(unauthorizedUsers[i]);
            crowdsale.emergencyPause("Unauthorized pause attempt");
        }
        
        // 只有授权用户可以执行管理操作
        vm.prank(creator);
        crowdsale.emergencyPause("Test authorized pause");
        
        vm.prank(creator);
        crowdsale.emergencyResume("Test authorized resume");
    }
}
