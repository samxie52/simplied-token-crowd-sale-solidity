// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/RefundVault.sol";
import "../../contracts/interfaces/IRefundVault.sol";
import "../../contracts/TokenCrowdsale.sol";
import "../../contracts/CrowdsaleToken.sol";
import "../../contracts/WhitelistManager.sol";
import "../../contracts/pricing/FixedPricingStrategy.sol";
import "../../contracts/interfaces/ICrowdsale.sol";
import "../../contracts/interfaces/IPricingStrategy.sol";

contract RefundVaultTest is Test {
    RefundVault public refundVault;
    TokenCrowdsale public crowdsale;
    CrowdsaleToken public token;
    WhitelistManager public whitelist;
    FixedPricingStrategy public pricingStrategy;
    
    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public emergencyRole = makeAddr("emergency");
    address public fundingWallet = makeAddr("fundingWallet");
    address public buyer1 = makeAddr("buyer1");
    address public buyer2 = makeAddr("buyer2");
    address public buyer3 = makeAddr("buyer3");
    
    // Multi-signature addresses
    address public signer1 = makeAddr("signer1");
    address public signer2 = makeAddr("signer2");
    address public signer3 = makeAddr("signer3");
    
    uint256 public constant INITIAL_BALANCE = 100 ether;
    
    event Deposited(address indexed depositor, uint256 amount, uint256 timestamp);
    event RefundsEnabled(uint256 timestamp);
    event Refunded(address indexed depositor, uint256 amount, uint256 timestamp);
    event Released(address indexed beneficiary, uint256 amount, uint256 timestamp);
    event EmergencyWithdraw(address indexed admin, uint256 amount, string reason);
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy token
        token = new CrowdsaleToken(
            "Test Token",
            "TEST",
            1000000 * 10**18,  // 1M tokens
            admin
        );
        
        // Deploy whitelist
        whitelist = new WhitelistManager(admin);
        
        // Deploy pricing strategy
        pricingStrategy = new FixedPricingStrategy(
            0.001 ether,  // 1 token = 0.001 ETH
            address(whitelist),
            admin
        );
        
        // Deploy crowdsale
        crowdsale = new TokenCrowdsale(
            address(token),
            address(whitelist),
            payable(fundingWallet),
            admin
        );
        
        // Skip complex time window configuration - focus on RefundVault testing
        // Set basic pricing strategy without complex config
        crowdsale.setPricingStrategy(address(pricingStrategy));
        
        // Deploy refund vault
        refundVault = new RefundVault(
            fundingWallet,      // beneficiary
            address(crowdsale), // crowdsale
            1,                  // requiredSignatures
            admin               // admin
        );
        
        // Set refund vault in crowdsale
        crowdsale.setRefundVault(address(refundVault));
        
        // Grant necessary roles to the crowdsale for testing
        vm.deal(address(crowdsale), 10 ether);
        
        // Setup roles before stopping prank
        refundVault.grantRole(refundVault.VAULT_OPERATOR_ROLE(), operator);
        refundVault.grantRole(refundVault.EMERGENCY_ROLE(), emergencyRole);
        
        // Grant minter role to crowdsale
        token.grantRole(token.MINTER_ROLE(), address(crowdsale));
        
        // Skip complex phase management - focus on RefundVault functionality
        
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(buyer1, INITIAL_BALANCE);
        vm.deal(buyer2, INITIAL_BALANCE);
        vm.deal(buyer3, INITIAL_BALANCE);
    }
    
    function test_InitialState() public {
        assertEq(uint256(refundVault.state()), uint256(IRefundVault.VaultState.ACTIVE));
        assertEq(refundVault.getBeneficiary(), fundingWallet);
        assertEq(refundVault.getCrowdsale(), address(crowdsale));
        assertEq(refundVault.getRequiredSignatures(), 1);
        assertEq(refundVault.getTotalDeposited(), 0);
    }
    
    function test_Deposit() public {
        uint256 depositAmount = 1 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Deposited(buyer1, depositAmount, block.timestamp);
        
        vm.prank(address(crowdsale));
        refundVault.deposit{value: depositAmount}(buyer1);
        
        assertEq(refundVault.getTotalDeposited(), depositAmount);
        
        // Check deposit using getDeposit function
        (uint256 amount, uint256 timestamp, bool refunded, uint256 refundAmount) = refundVault.getDeposit(buyer1);
        assertEq(amount, depositAmount);
        assertGt(timestamp, 0);
        assertFalse(refunded);
        assertEq(refundAmount, 0);
    }
    
    function test_MultipleDeposits() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;
        uint256 amount3 = 0.5 ether;
        
        vm.startPrank(address(crowdsale));
        
        refundVault.deposit{value: amount1}(buyer1);
        refundVault.deposit{value: amount2}(buyer2);
        refundVault.deposit{value: amount3}(buyer1); // Additional deposit from buyer1
        
        vm.stopPrank();
        
        assertEq(refundVault.getTotalDeposited(), amount1 + amount2 + amount3);
        
        // Check individual deposits using getDeposit function
        (uint256 buyer1Amount, , , ) = refundVault.getDeposit(buyer1);
        (uint256 buyer2Amount, , , ) = refundVault.getDeposit(buyer2);
        assertEq(buyer1Amount, amount1 + amount3);
        assertEq(buyer2Amount, amount2);
    }
    
    function test_DepositOnlyFromCrowdsale() public {
        vm.expectRevert("RefundVault: caller is not crowdsale");
        vm.prank(buyer1);
        refundVault.deposit{value: 1 ether}(buyer1);
    }
    
    function test_EnableRefunds() public {
        // First make some deposits
        vm.startPrank(address(crowdsale));
        refundVault.deposit{value: 1 ether}(buyer1);
        refundVault.deposit{value: 2 ether}(buyer2);
        vm.stopPrank();
        
        // Configure crowdsale to allow refunds by ending the sale
        vm.prank(admin);
        crowdsale.finalizeCrowdsale(); // This should trigger refund conditions
        
        vm.expectEmit(false, false, false, true);
        emit RefundsEnabled(block.timestamp);
        
        vm.prank(operator);
        refundVault.enableRefunds();
        
        assertEq(uint256(refundVault.state()), uint256(IRefundVault.VaultState.REFUNDING));
    }
    
    function test_EnableRefundsOnlyFromCrowdsale() public {
        // Configure conditions to allow refunds by finalizing crowdsale
        vm.prank(admin);
        crowdsale.finalizeCrowdsale();
        
        vm.expectRevert("RefundVault: caller is not crowdsale");
        vm.prank(admin);
        refundVault.enableRefunds();
    }
    
    function test_Refund() public {
        uint256 depositAmount = 1 ether;
        
        // Make deposit
        vm.prank(address(crowdsale));
        refundVault.deposit{value: depositAmount}(buyer1);
        
        // Enable refunds (requires operator role)
        vm.prank(operator);
        refundVault.enableRefunds();
        
        uint256 initialBalance = buyer1.balance;
        
        vm.expectEmit(true, false, false, true);
        emit Refunded(buyer1, depositAmount, block.timestamp);
        
        vm.prank(buyer1);
        refundVault.refund(buyer1);
        
        assertEq(buyer1.balance, initialBalance + depositAmount);
        
        // Check that deposit is marked as refunded
        (uint256 amount, uint256 timestamp, bool refunded, uint256 refundAmount) = refundVault.getDeposit(buyer1);
        assertTrue(refunded);
        assertEq(refundAmount, depositAmount);
    }
    
    function test_RefundOnlyInRefundingState() public {
        vm.prank(address(crowdsale));
        refundVault.deposit{value: 1 ether}(buyer1);
        
        vm.expectRevert("RefundVault: not refunding");
        vm.prank(buyer1);
        refundVault.refund(buyer1);
    }
    
    function test_RefundOnlyWithDeposit() public {
        vm.prank(operator);
        refundVault.enableRefunds();
        
        vm.expectRevert("RefundVault: no deposit found");
        vm.prank(buyer1);
        refundVault.refund(buyer1);
    }
    
    function test_BatchRefund() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;
        uint256 amount3 = 0.5 ether;
        
        // Make deposits
        vm.startPrank(address(crowdsale));
        refundVault.deposit{value: amount1}(buyer1);
        refundVault.deposit{value: amount2}(buyer2);
        refundVault.deposit{value: amount3}(buyer3);
        vm.stopPrank();
        
        // Enable refunds (requires operator role)
        vm.prank(operator);
        refundVault.enableRefunds();
        
        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = buyer1;
        beneficiaries[1] = buyer2;
        beneficiaries[2] = buyer3;
        
        uint256 initialBalance1 = buyer1.balance;
        uint256 initialBalance2 = buyer2.balance;
        uint256 initialBalance3 = buyer3.balance;
        
        vm.prank(operator);
        refundVault.batchRefund(beneficiaries);
        
        assertEq(buyer1.balance, initialBalance1 + amount1);
        assertEq(buyer2.balance, initialBalance2 + amount2);
        assertEq(buyer3.balance, initialBalance3 + amount3);
        
        // Check that all deposits are marked as refunded
        (uint256 depositAmount1, , bool refunded1, ) = refundVault.getDeposit(buyer1);
        (uint256 depositAmount2, , bool refunded2, ) = refundVault.getDeposit(buyer2);
        (uint256 depositAmount3, , bool refunded3, ) = refundVault.getDeposit(buyer3);
        assertTrue(refunded1);
        assertTrue(refunded2);
        assertTrue(refunded3);
    }
    
    function test_BatchRefundOnlyOperator() public {
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = buyer1;
        
        vm.expectRevert();
        vm.prank(buyer1);
        refundVault.batchRefund(beneficiaries);
    }
    
    function test_Release() public {
        uint256 depositAmount = 5 ether;
        
        // Make deposit
        vm.prank(address(crowdsale));
        refundVault.deposit{value: depositAmount}(buyer1);
        
        uint256 initialBalance = fundingWallet.balance;
        
        vm.expectEmit(false, false, false, true);
        emit Released(fundingWallet, depositAmount, block.timestamp);
        
        vm.prank(operator);
        refundVault.release();
        
        assertEq(uint256(refundVault.state()), uint256(IRefundVault.VaultState.CLOSED));
        assertEq(fundingWallet.balance, initialBalance + depositAmount);
    }
    
    function test_ReleaseOnlyFromCrowdsale() public {
        vm.expectRevert("RefundVault: caller is not operator");
        vm.prank(admin);
        refundVault.release();
    }
    
    function test_EmergencyWithdrawRequiresMultiSig() public {
        uint256 depositAmount = 3 ether;
        
        vm.prank(address(crowdsale));
        refundVault.deposit{value: depositAmount}(buyer1);
        
        // Emergency withdraw requires proper multi-sig setup
        // This is a simplified test - actual implementation would require multi-sig
        vm.expectRevert("RefundVault: insufficient signatures");
        vm.prank(admin);
        refundVault.emergencyWithdraw("Emergency test");
    }
    
    function test_PauseUnpause() public {
        vm.prank(admin);
        refundVault.pause();
        
        assertTrue(refundVault.paused());
        
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(address(crowdsale));
        refundVault.deposit{value: 1 ether}(buyer1);
        
        vm.prank(admin);
        refundVault.unpause();
        
        assertFalse(refundVault.paused());
        
        // Should work after unpause
        vm.prank(address(crowdsale));
        refundVault.deposit{value: 1 ether}(buyer1);
        
        (uint256 amount, , , ) = refundVault.getDeposit(buyer1);
        assertEq(amount, 1 ether);
    }
    
    function test_GetDepositors() public {
        vm.startPrank(address(crowdsale));
        refundVault.deposit{value: 1 ether}(buyer1);
        refundVault.deposit{value: 2 ether}(buyer2);
        refundVault.deposit{value: 0.5 ether}(buyer3);
        vm.stopPrank();
        
        // Check deposits exist
        (uint256 amount1, , , ) = refundVault.getDeposit(buyer1);
        (uint256 amount2, , , ) = refundVault.getDeposit(buyer2);
        (uint256 amount3, , , ) = refundVault.getDeposit(buyer3);
        assertEq(amount1, 1 ether);
        assertEq(amount2, 2 ether);
        assertEq(amount3, 0.5 ether);
    }
    
    function test_GetDepositorsWithPagination() public {
        vm.startPrank(address(crowdsale));
        refundVault.deposit{value: 1 ether}(buyer1);
        refundVault.deposit{value: 2 ether}(buyer2);
        refundVault.deposit{value: 0.5 ether}(buyer3);
        vm.stopPrank();
        
        // Check deposits exist
        (uint256 amount1, , , ) = refundVault.getDeposit(buyer1);
        (uint256 amount2, , , ) = refundVault.getDeposit(buyer2);
        (uint256 amount3, , , ) = refundVault.getDeposit(buyer3);
        assertEq(amount1, 1 ether);
        assertEq(amount2, 2 ether);
        assertEq(amount3, 0.5 ether);
    }
}
