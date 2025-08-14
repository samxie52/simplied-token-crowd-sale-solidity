// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/CrowdsaleToken.sol";


contract CrowdsaleTokenTest is Test {
    CrowdsaleToken public token;

    address public admin = address(0x1);
    address public minter = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public attacker = address(0x5);


    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TST";
    uint256 constant MAX_SUPPLY = 1000000 * 10**18;  // 1M tokens

    event TokenMinted(address indexed to, uint256 amount, address indexed minter);
    event TokenBurned(address indexed from, uint256 amount, address indexed burner);

    function setUp() public {
        // 使用 startPrank 来持续模拟 admin 身份
        vm.startPrank(admin);
        
        // 创建合约，admin 将自动获得所有角色
        token = new CrowdsaleToken(TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, admin);
        
        // 授予 minter 角色
        token.grantRole(token.MINTER_ROLE(), minter);
        
        // 授予 minter 燃烧权限（用于测试）
        token.grantRole(token.BURNER_ROLE(), minter);
        
        // 停止模拟
        vm.stopPrank();
    }

    // ============================================
    // 基础功能测试
    // ============================================

    function testInitialState() public {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertFalse(token.paused());
    }

    function testRoleAssignment() public {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), admin));
        assertTrue(token.hasRole(token.BURNER_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }


        // ============================================
    // 铸币功能测试
    // ============================================

    function testMint() public {
        uint256 amount = 1000 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit TokenMinted(user1, amount, minter);
        
        vm.prank(minter);
        token.mint(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
        assertEq(token.totalMinted(), amount);
        assertEq(token.mintedBy(minter), amount);
    }

    function testMintFailsWithoutRole() public {
        vm.expectRevert();
        vm.prank(attacker);
        token.mint(user1, 1000 * 10**18);
    }

    function testMintFailsZeroAddress() public {
        vm.expectRevert("CrowdsaleToken: Mint to the zero address");
        vm.prank(minter);
        token.mint(address(0), 1000 * 10**18);
    }

    function testMintFailsZeroAmount() public {
        vm.expectRevert("CrowdsaleToken: Mint amount must be greater than 0");
        vm.prank(minter);
        token.mint(user1, 0);
    }

    function testMintFailsExceedsMaxSupply() public {
        vm.expectRevert("CrowdsaleToken: mint amount exceeds max supply");
        vm.prank(minter);
        token.mint(user1, MAX_SUPPLY + 1);
    }


        function testBatchMint() public {
        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = address(0x6);
        
        amounts[0] = 1000 * 10**18;
        amounts[1] = 2000 * 10**18;
        amounts[2] = 3000 * 10**18;
        
        vm.prank(minter);
        token.batchMint(recipients, amounts);
        
        assertEq(token.balanceOf(user1), amounts[0]);
        assertEq(token.balanceOf(user2), amounts[1]);
        assertEq(token.balanceOf(address(0x6)), amounts[2]);
        assertEq(token.totalSupply(), 6000 * 10**18);
    }

    function testBatchMintFailsArrayMismatch() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](3);
        
        vm.expectRevert("CrowdsaleToken: arrays length mismatch");
        vm.prank(minter);
        token.batchMint(recipients, amounts);
    }

    // ============================================
    // 燃烧功能测试
    // ============================================

    function testBurnFrom() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 burnAmount = 300 * 10**18;
        
        // 先铸币
        vm.prank(minter);
        token.mint(user1, mintAmount);
        
        // 用户授权燃烧
        vm.prank(user1);
        token.approve(admin, burnAmount);
        
        vm.expectEmit(true, true, false, true);
        emit TokenBurned(user1, burnAmount, admin);
        
        // 燃烧代币
        vm.prank(admin);
        token.burnFrom(user1, burnAmount);
        
        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.totalBurned(), burnAmount);
        assertEq(token.burnedFrom(user1), burnAmount);
    }

    function testBurnFromFailsWithoutRole() public {
        vm.expectRevert();
        vm.prank(attacker);
        token.burnFrom(user1, 100 * 10**18);
    }

    // ============================================
    // 暂停功能测试
    // ============================================

    function testPause() public {
        vm.prank(admin);
        token.pause();
        
        assertTrue(token.paused());
    }

    function testUnpause() public {
        vm.prank(admin);
        token.pause();
        
        vm.prank(admin);
        token.unpause();
        
        assertFalse(token.paused());
    }

    function testTransferFailsWhenPaused() public {
        // 先铸币
        vm.prank(minter);
        token.mint(user1, 1000 * 10**18);
        
        // 暂停合约
        vm.prank(admin);
        token.pause();
        
        // 转账应该失败
        vm.expectRevert();
        vm.prank(user1);
        token.transfer(user2, 100 * 10**18);
    }

    function testPauseFailsWithoutRole() public {
        vm.expectRevert();
        vm.prank(attacker);
        token.pause();
    }

    // ============================================
    // 最大供应量管理测试
    // ============================================

    function testUpdateMaxSupply() public {
        uint256 newMaxSupply = MAX_SUPPLY / 2;
        
        vm.expectEmit(false, false, false, true);
        emit IERC20Extended.MaxSupplyUpdated(MAX_SUPPLY, newMaxSupply);
        
        vm.prank(admin);
        token.updateMaxSupply(newMaxSupply);
        
        assertEq(token.maxSupply(), newMaxSupply);
    }

    function testUpdateMaxSupplyFailsIncrease() public {
        vm.expectRevert("CrowdsaleToken: can only decrease max supply");
        vm.prank(admin);
        token.updateMaxSupply(MAX_SUPPLY + 1);
    }

    function testUpdateMaxSupplyFailsBelowCurrentSupply() public {
        // 先铸币
        vm.prank(minter);
        token.mint(user1, 1000 * 10**18);
        
        vm.expectRevert("CrowdsaleToken: new max supply less than current supply");
        vm.prank(admin);
        token.updateMaxSupply(500 * 10**18);
    }

    // ============================================
    // 查询功能测试
    // ============================================

    function testCanMint() public {
        assertTrue(token.canMint(1000 * 10**18));
        assertFalse(token.canMint(MAX_SUPPLY + 1));
    }

    function testRemainingMintable() public {
        assertEq(token.remainingMintable(), MAX_SUPPLY);
        
        uint256 mintAmount = 1000 * 10**18;
        vm.prank(minter);
        token.mint(user1, mintAmount);
        
        assertEq(token.remainingMintable(), MAX_SUPPLY - mintAmount);
    }

    function testGetTokenStats() public {
        uint256 mintAmount = 1000 * 10**18;
        vm.prank(minter);
        token.mint(user1, mintAmount);
        
        (
            uint256 currentSupply,
            uint256 maxSupply_,
            uint256 totalMinted_,
            uint256 totalBurned_,
            uint256 remainingMintable,
            bool isPaused
        ) = token.getTokenStats();
        
        assertEq(currentSupply, mintAmount);
        assertEq(maxSupply_, MAX_SUPPLY);
        assertEq(totalMinted_, mintAmount);
        assertEq(totalBurned_, 0);
        assertEq(remainingMintable, MAX_SUPPLY - mintAmount);
        assertFalse(isPaused);
    }

    // ============================================
    // Fuzz测试
    // ============================================

    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount <= MAX_SUPPLY);
        
        vm.prank(minter);
        token.mint(to, amount);
        
        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

}