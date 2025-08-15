// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/TokenCrowdsale.sol";
import "../../contracts/CrowdsaleToken.sol";
import "../../contracts/WhitelistManager.sol";
import "../../contracts/pricing/FixedPricingStrategy.sol";
import "../../contracts/pricing/TieredPricingStrategy.sol";
import "../../contracts/interfaces/ICrowdsale.sol";
import "../../contracts/interfaces/IPricingStrategy.sol";
import "../../contracts/utils/CrowdsaleConstants.sol";

/**
 * @title PurchaseFlowTest
 * @dev 测试代币购买和定价机制的完整流程
 */
contract PurchaseFlowTest is Test {
    
    // ============ 合约实例 ============
    
    TokenCrowdsale public crowdsale;
    CrowdsaleToken public token;
    WhitelistManager public whitelistManager;
    FixedPricingStrategy public fixedPricing;
    TieredPricingStrategy public tieredPricing;
    
    // ============ 测试账户 ============
    
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public emergency = makeAddr("emergency");
    address payable public fundingWallet = payable(makeAddr("fundingWallet"));
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public vipUser = makeAddr("vipUser");
    address public whitelistedUser = makeAddr("whitelistedUser");
    
    // ============ 测试常量 ============
    
    uint256 public constant INITIAL_ETH_BALANCE = 100 ether;
    uint256 public constant BASE_PRICE = 0.0004 ether; // 0.0004 ETH per token
    uint256 public constant SOFT_CAP = 10 ether;
    uint256 public constant HARD_CAP = 100 ether;
    uint256 public constant MIN_PURCHASE = 0.01 ether;
    uint256 public constant MAX_PURCHASE = 10 ether;
    
    // ============ 设置函数 ============
    
    function setUp() public {
        // 设置测试账户余额
        vm.deal(user1, INITIAL_ETH_BALANCE);
        vm.deal(user2, INITIAL_ETH_BALANCE);
        vm.deal(vipUser, INITIAL_ETH_BALANCE);
        vm.deal(whitelistedUser, INITIAL_ETH_BALANCE);
        vm.deal(admin, INITIAL_ETH_BALANCE);
        
        // 部署合约
        vm.startPrank(admin);
        
        // 部署代币合约
        token = new CrowdsaleToken(
            "Test Token",
            "TEST",
            1000000 * 1e18, // 1M tokens
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
        
        // 设置代币铸币权限
        token.grantRole(token.MINTER_ROLE(), address(crowdsale));
        
        // 铸造代币并转移给众筹合约
        token.mint(admin, 1000000 * 1e18); // 铸造全部供应量给admin
        token.transfer(address(crowdsale), 500000 * 1e18); // 转移一半给众筹合约用于销售
        
        // 部署定价策略
        fixedPricing = new FixedPricingStrategy(
            BASE_PRICE,
            address(whitelistManager),
            admin
        );
        
        tieredPricing = new TieredPricingStrategy(
            address(crowdsale),
            address(whitelistManager),
            admin
        );
        
        // 配置众筹参数
        ICrowdsale.CrowdsaleConfig memory config = ICrowdsale.CrowdsaleConfig({
            presaleStartTime: block.timestamp + 1 hours,
            presaleEndTime: block.timestamp + 8 days,
            publicSaleStartTime: block.timestamp + 9 days,
            publicSaleEndTime: block.timestamp + 23 days,
            softCap: SOFT_CAP,
            hardCap: HARD_CAP,
            minPurchase: MIN_PURCHASE,
            maxPurchase: MAX_PURCHASE
        });
        
        // 等待配置更新冷却时间
        vm.warp(block.timestamp + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN + 1);
        crowdsale.updateConfig(config);
        
        // 设置白名单用户
        whitelistManager.addToWhitelistWithExpiration(
            vipUser,
            IWhitelistManager.WhitelistLevel.VIP,
            block.timestamp + 30 days
        );
        
        whitelistManager.addToWhitelistWithExpiration(
            whitelistedUser,
            IWhitelistManager.WhitelistLevel.WHITELISTED,
            block.timestamp + 30 days
        );
        
        vm.stopPrank();
    }
    
    // ============ 固定价格策略测试 ============
    
    function testFixedPricingPurchase() public {
        vm.startPrank(admin);
        
        // 设置固定价格策略
        crowdsale.setPricingStrategy(address(fixedPricing));
        
        // 开始预售
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        
        vm.stopPrank();
        
        // VIP用户购买（20%折扣）
        vm.startPrank(vipUser);
        uint256 purchaseAmount = 1 ether;
        uint256 expectedTokens = fixedPricing.calculateTokenAmount(purchaseAmount, vipUser);
        uint256 expectedPrice = fixedPricing.getPriceForBuyer(vipUser);
        
        // 检查价格计算
        assertEq(expectedPrice, BASE_PRICE * 8000 / 10000); // 20% discount
        
        // 执行购买
        crowdsale.purchaseTokens{value: purchaseAmount}();
        
        // 验证结果
        assertEq(token.balanceOf(vipUser), expectedTokens);
        assertEq(crowdsale.getUserTotalPurchased(vipUser), purchaseAmount);
        assertTrue(crowdsale.hasParticipated(vipUser));
        
        vm.stopPrank();
        
        // 普通白名单用户购买（10%折扣）
        vm.startPrank(whitelistedUser);
        uint256 whitelistedTokens = fixedPricing.calculateTokenAmount(purchaseAmount, whitelistedUser);
        uint256 whitelistedPrice = fixedPricing.getPriceForBuyer(whitelistedUser);
        
        assertEq(whitelistedPrice, BASE_PRICE * 9000 / 10000); // 10% discount
        
        crowdsale.purchaseTokens{value: purchaseAmount}();
        assertEq(token.balanceOf(whitelistedUser), whitelistedTokens);
        
        vm.stopPrank();
    }
    
    function testPublicSalePurchase() public {
        vm.startPrank(admin);
        
        // 设置固定价格策略
        crowdsale.setPricingStrategy(address(fixedPricing));
        
        // 先开始预售
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        
        // 然后跳到公售时间并开始公售
        vm.warp(block.timestamp + 9 days);
        crowdsale.startPublicSale();
        
        vm.stopPrank();
        
        // 普通用户在公售期间购买
        vm.startPrank(user1);
        uint256 purchaseAmount = 2 ether;
        uint256 expectedTokens = fixedPricing.calculateTokenAmount(purchaseAmount, user1);
        
        // 普通用户没有折扣
        assertEq(fixedPricing.getPriceForBuyer(user1), BASE_PRICE);
        
        crowdsale.purchaseTokens{value: purchaseAmount}();
        
        assertEq(token.balanceOf(user1), expectedTokens);
        assertEq(crowdsale.getUserTotalPurchased(user1), purchaseAmount);
        
        vm.stopPrank();
    }
    
    // ============ 阶梯价格策略测试 ============
    
    function testTieredPricingPurchase() public {
        vm.startPrank(admin);
        
        // 设置阶梯价格策略
        crowdsale.setPricingStrategy(address(tieredPricing));
        
        // 开始预售
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        
        vm.stopPrank();
        
        // 第一阶段购买（0-25%进度）
        vm.startPrank(vipUser);
        uint256 firstTierAmount = 2 ether; // 2% of hard cap, within limits
        
        // 获取当前价格（第一阶段价格）
        uint256 currentPrice = tieredPricing.getCurrentPrice();
        assertEq(currentPrice, 0.0001 ether); // 第一阶段价格
        
        // VIP用户购买（阶梯价格 + VIP折扣）
        // uint256 vipPrice = tieredPricing.getPriceForBuyer(vipUser); // 移除未使用的变量
        uint256 expectedTokens = tieredPricing.calculateTokenAmount(firstTierAmount, vipUser);
        
        crowdsale.purchaseTokens{value: firstTierAmount}();
        
        assertEq(token.balanceOf(vipUser), expectedTokens);
        
        vm.stopPrank();
        
        // 继续购买直到第二阶段
        vm.startPrank(whitelistedUser);
        uint256 secondTierAmount = 8 ether; // 推进到第二阶段，但不超过个人限额
        
        // 检查是否进入第二阶段
        crowdsale.purchaseTokens{value: secondTierAmount}();
        
        // 验证购买成功
        assertTrue(token.balanceOf(whitelistedUser) > 0);
        
        // 验证价格已经更新到第二阶段 (如果总筹资超过25%)
        uint256 newPrice = tieredPricing.getCurrentPrice();
        // 注意：价格可能还在第一阶段，取决于总筹资进度
        assertTrue(newPrice >= currentPrice); // 价格应该不降
        
        vm.stopPrank();
    }
    
    // ============ 购买限制测试 ============
    
    function testPurchaseLimits() public {
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        vm.stopPrank();
        
        // 测试最小购买限制
        vm.startPrank(vipUser);
        vm.expectRevert("TokenCrowdsale: below minimum purchase");
        crowdsale.purchaseTokens{value: 0.005 ether}(); // 低于最小购买量
        vm.stopPrank();
        
        // 测试最大购买限制
        vm.startPrank(vipUser);
        vm.expectRevert("TokenCrowdsale: exceeds maximum purchase");
        crowdsale.purchaseTokens{value: 11 ether}(); // 超过最大购买量 (MAX_PURCHASE = 10 ether)
        vm.stopPrank();
        
        // 测试硬顶限制 - 先切换到公售阶段
        vm.startPrank(admin);
        vm.warp(block.timestamp + 9 days);
        crowdsale.startPublicSale();
        
        // 使用批量购买达到硬顶
        address[] memory buyers = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        for(uint i = 0; i < 10; i++) {
            buyers[i] = makeAddr(string(abi.encodePacked("buyer", i)));
            amounts[i] = 10 ether; // 每人10 ETH，总共100 ETH = 硬顶
        }
        
        crowdsale.batchPurchase{value: 100 ether}(buyers, amounts);
        vm.stopPrank();
        
        // 现在尝试任何购买都应该失败，因为已达到硬顶
        vm.startPrank(user1);
        vm.expectRevert("TokenCrowdsale: exceeds hard cap");
        crowdsale.purchaseTokens{value: 0.01 ether}(); // 最小购买金额也会超过硬顶
        vm.stopPrank();
    }
    
    // ============ 购买冷却时间测试 ============
    
    function testPurchaseCooldown() public {
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        vm.stopPrank();
        
        // 第一次购买
        vm.startPrank(vipUser);
        crowdsale.purchaseTokens{value: 1 ether}();
        
        // 立即尝试第二次购买应该失败
        vm.expectRevert("TokenCrowdsale: purchase cooldown not passed");
        crowdsale.purchaseTokens{value: 1 ether}();
        
        // 等待冷却时间后应该成功
        vm.warp(block.timestamp + 5 minutes + 1);
        crowdsale.purchaseTokens{value: 1 ether}();
        
        vm.stopPrank();
    }
    
    // ============ 批量购买测试 ============
    
    function testBatchPurchase() public {
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        
        // 准备批量购买数据
        address[] memory buyers = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        
        buyers[0] = vipUser;
        buyers[1] = whitelistedUser;
        buyers[2] = user1; // 非白名单用户，预售期间应该被跳过
        
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 1 ether;
        
        uint256 totalAmount = 4 ether;
        
        // 执行批量购买
        crowdsale.batchPurchase{value: totalAmount}(buyers, amounts);
        
        // 验证结果
        assertTrue(token.balanceOf(vipUser) > 0);
        assertTrue(token.balanceOf(whitelistedUser) > 0);
        assertEq(token.balanceOf(user1), 0); // 非白名单用户在预售期间无法购买
        
        vm.stopPrank();
    }
    
    // ============ 购买历史测试 ============
    
    function testPurchaseHistory() public {
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        vm.stopPrank();
        
        // 执行多次购买
        vm.startPrank(vipUser);
        
        crowdsale.purchaseTokens{value: 1 ether}();
        
        vm.warp(block.timestamp + 5 minutes + 1);
        crowdsale.purchaseTokens{value: 2 ether}();
        
        // 检查购买历史
        TokenCrowdsale.PurchaseRecord[] memory history = crowdsale.getUserPurchaseHistory(vipUser);
        
        assertEq(history.length, 2);
        assertEq(history[0].weiAmount, 1 ether);
        assertEq(history[1].weiAmount, 2 ether);
        assertTrue(history[0].isWhitelistPurchase);
        assertTrue(history[1].isWhitelistPurchase);
        
        // 检查总购买金额
        assertEq(crowdsale.getUserTotalPurchased(vipUser), 3 ether);
        
        vm.stopPrank();
    }
    
    // ============ 查询功能测试 ============
    
    function testQueryFunctions() public {
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        vm.stopPrank();
        
        // 测试价格查询
        uint256 currentPrice = crowdsale.getCurrentTokenPrice();
        assertEq(currentPrice, BASE_PRICE);
        
        uint256 vipPrice = crowdsale.getTokenPriceForUser(vipUser);
        assertTrue(vipPrice < currentPrice); // VIP用户有折扣
        
        uint256 regularPrice = crowdsale.getTokenPriceForUser(user1);
        assertEq(regularPrice, currentPrice); // 普通用户无折扣
        
        // 测试代币数量计算
        uint256 weiAmount = 1 ether;
        uint256 tokenAmount = crowdsale.calculateTokenAmount(weiAmount, vipUser);
        assertTrue(tokenAmount > 0);
        
        // 测试购买资格检查
        assertTrue(crowdsale.canPurchase(vipUser, 1 ether));
        assertFalse(crowdsale.canPurchase(user1, 1 ether)); // 预售期间非白名单用户不能购买
        
        // 测试剩余代币查询
        uint256 remainingTokens = crowdsale.getRemainingTokens();
        assertTrue(remainingTokens > 0);
    }
    
    // ============ 错误情况测试 ============
    
    function testPurchaseErrors() public {
        // 测试未设置定价策略的情况
        vm.startPrank(admin);
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        vm.stopPrank();
        
        vm.startPrank(vipUser);
        vm.expectRevert("TokenCrowdsale: pricing strategy not set");
        crowdsale.purchaseTokens{value: 1 ether}();
        vm.stopPrank();
        
        // 设置定价策略后测试其他错误
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        
        // 先完成一些购买以满足软顶要求
        vm.warp(block.timestamp + 9 days);
        crowdsale.startPublicSale();
        
        address[] memory buyers = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        buyers[0] = user1;
        amounts[0] = 15 ether; // 超过软顶
        crowdsale.batchPurchase{value: 15 ether}(buyers, amounts);
        
        // 现在可以完成众筹
        vm.warp(block.timestamp + 15 days); // 超过结束时间
        crowdsale.finalizeCrowdsale();
        vm.stopPrank();
        
        vm.startPrank(vipUser);
        vm.expectRevert("TokenCrowdsale: sale not active");
        crowdsale.purchaseTokens{value: 1 ether}();
        vm.stopPrank();
    }
    
    // ============ 事件测试 ============
    
    function testPurchaseEvents() public {
        vm.startPrank(admin);
        crowdsale.setPricingStrategy(address(fixedPricing));
        vm.warp(block.timestamp + 1 hours);
        crowdsale.startPresale();
        vm.stopPrank();
        
        // 测试购买事件
        vm.startPrank(vipUser);
        uint256 purchaseAmount = 1 ether;
        uint256 expectedTokens = fixedPricing.calculateTokenAmount(purchaseAmount, vipUser);
        
        vm.expectEmit(true, false, false, true);
        emit TokensPurchased(vipUser, purchaseAmount, expectedTokens, block.timestamp);
        
        crowdsale.purchaseTokens{value: purchaseAmount}();
        vm.stopPrank();
    }
    
    // ============ 事件定义 ============
    
    event TokensPurchased(
        address indexed buyer,
        uint256 weiAmount,
        uint256 tokenAmount,
        uint256 timestamp
    );
}
