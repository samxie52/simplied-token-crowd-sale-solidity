// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/TokenVesting.sol";

contract DeployVesting is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying TokenVesting...");
        console.log("Deployer address: %s", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Get deployed token address from environment
        address tokenAddress = vm.envAddress("CROWDSALETOKEN_ADDRESS");
        require(tokenAddress != address(0), "Token address not found in environment");
        
        TokenVesting vesting = new TokenVesting(tokenAddress, deployer);

        vm.stopBroadcast();

        console.log("TokenVesting deployed at: %s", address(vesting));
        console.log("Deployment completed successfully.");

        // 验证部署
        _verifyDeployment(vesting, deployer);
    }

    function _verifyDeployment(TokenVesting vesting, address admin) internal view {
        console.log("\n=== Deployment Verification ===");
        console.log("Contract Address:", address(vesting));
        console.log("Is Paused:", vesting.paused());
        
        console.log("\n=== Role Verification ===");
        console.log("Admin has DEFAULT_ADMIN_ROLE:", vesting.hasRole(vesting.DEFAULT_ADMIN_ROLE(), admin));
        console.log("Admin has VESTING_ADMIN_ROLE:", vesting.hasRole(vesting.VESTING_ADMIN_ROLE(), admin));
        console.log("Admin has VESTING_OPERATOR_ROLE:", vesting.hasRole(vesting.VESTING_OPERATOR_ROLE(), admin));
        console.log("Admin has MILESTONE_MANAGER_ROLE:", vesting.hasRole(vesting.MILESTONE_MANAGER_ROLE(), admin));
    }
}
