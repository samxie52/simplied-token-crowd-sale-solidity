// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/WhitelistManager.sol";

/**
 * @title DeployWhitelist
 * @dev 白名单管理合约部署脚本
 */
contract DeployWhitelist is Script {
    
    // 部署参数
    address public deployer;
    address public admin;
    
    // 部署的合约实例
    WhitelistManager public whitelistManager;
    
    function run() external {
        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        // Set admin address (default to deployer)
        admin = vm.envOr("WHITELIST_ADMIN", deployer);
        
        console.log("=== Whitelist Manager Deployment Started ===");
        console.log("Deployer address:", deployer);
        console.log("Admin address:", admin);
        
        // Start deployment
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy whitelist manager contract
        whitelistManager = new WhitelistManager(admin);
        
        vm.stopBroadcast();
        
        // Verify deployment
        _verifyDeployment();
        
        // Log deployment info
        _logDeploymentInfo();
        
        console.log("=== Whitelist Manager Deployment Completed ===");
    }
    
    /**
     * @dev Verify deployment results
     */
    function _verifyDeployment() internal view {
        console.log("\n=== Deployment Verification ===");
        
        // Verify contract address
        require(address(whitelistManager) != address(0), "WhitelistManager deployment failed");
        console.log("WhitelistManager deployment success");
        
        // Verify admin role
        require(
            whitelistManager.hasRole(whitelistManager.DEFAULT_ADMIN_ROLE(), admin),
            "Admin role not granted"
        );
        console.log("Admin role granted");
        
        // Verify whitelist admin role
        require(
            whitelistManager.hasRole(whitelistManager.WHITELIST_ADMIN_ROLE(), admin),
            "Whitelist admin role not granted"
        );
        console.log("Whitelist admin role granted");
        
        // Verify whitelist operator role
        require(
            whitelistManager.hasRole(whitelistManager.WHITELIST_OPERATOR_ROLE(), admin),
            "Whitelist operator role not granted"
        );
        console.log("Whitelist operator role granted");
        
        // Verify initial state
        (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount) = 
            whitelistManager.getWhitelistStats();
        
        require(vipCount == 0, "Initial VIP count should be 0");
        require(whitelistedCount == 0, "Initial whitelist count should be 0");
        require(blacklistedCount == 0, "Initial blacklist count should be 0");
        require(totalCount == 0, "Initial total count should be 0");
        console.log("Initial state verification passed");
        
        // Verify contract is not paused
        require(!whitelistManager.paused(), "Contract should not be paused initially");
        console.log("Contract state normal (not paused)");
    }
    
    /**
     * @dev Log deployment information
     */
    function _logDeploymentInfo() internal view {
        console.log("\n=== Deployment Info ===");
        console.log("Whitelist Manager address:", address(whitelistManager));
        console.log("Admin address:", admin);
        console.log("Network:", block.chainid);
        console.log("Block number:", block.number);
        console.log("Timestamp:", block.timestamp);
        
        console.log("\n=== Role Information ===");
        console.log("DEFAULT_ADMIN_ROLE:", vm.toString(whitelistManager.DEFAULT_ADMIN_ROLE()));
        console.log("WHITELIST_ADMIN_ROLE:", vm.toString(whitelistManager.WHITELIST_ADMIN_ROLE()));
        console.log("WHITELIST_OPERATOR_ROLE:", vm.toString(whitelistManager.WHITELIST_OPERATOR_ROLE()));
        
        console.log("\n=== Usage Examples ===");
        console.log("Add whitelist user:");
        console.log("cast send", vm.toString(address(whitelistManager)));
        console.log("  \"addToWhitelist(address,uint8)\" <USER_ADDRESS> 2");
        console.log("  --rpc-url $RPC_URL --private-key $PRIVATE_KEY");
        
        console.log("\nQuery user status:");
        console.log("cast call", vm.toString(address(whitelistManager)));
        console.log("  \"getWhitelistStatus(address)\" <USER_ADDRESS>");
        console.log("  --rpc-url $RPC_URL");
        
        console.log("\nBatch add users:");
        console.log("cast send", vm.toString(address(whitelistManager)));
        console.log("  \"batchAddToWhitelist(address[],uint8[])\" \"[<ADDR1>,<ADDR2>]\" \"[2,3]\"");
        console.log("  --rpc-url $RPC_URL --private-key $PRIVATE_KEY");
    }
}
