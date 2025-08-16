// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/CrowdsaleFactory.sol";

contract DeployFactory is Script {

    uint256 constant CREATION_FEE = 0.01 ether; // 0.01 ETH creation fee
    bool constant PUBLIC_CREATION_ALLOWED = true; // Allow public creation

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying CrowdsaleFactory...");
        console.log("Deployer address: %s", deployer);
        console.log("Creation fee: %s", CREATION_FEE);
        console.log("Public creation allowed: %s", PUBLIC_CREATION_ALLOWED);

        vm.startBroadcast(deployerPrivateKey);

        CrowdsaleFactory factory = new CrowdsaleFactory(
            CREATION_FEE,
            PUBLIC_CREATION_ALLOWED
        );

        vm.stopBroadcast();

        console.log("CrowdsaleFactory deployed at: %s", address(factory));
        console.log("Deployment completed successfully.");

        // 验证部署
        _verifyDeployment(factory, deployer);
    }

    function _verifyDeployment(CrowdsaleFactory factory, address admin) internal view {
        console.log("\n=== Deployment Verification ===");
        console.log("Contract Address:", address(factory));
        console.log("Creation Fee:", factory.creationFee());
        console.log("Public Creation Allowed:", factory.publicCreationAllowed());
        console.log("Is Paused:", factory.paused());
        
        console.log("\n=== Role Verification ===");
        console.log("Admin has DEFAULT_ADMIN_ROLE:", factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        console.log("Admin has FACTORY_ADMIN_ROLE:", factory.hasRole(factory.FACTORY_ADMIN_ROLE(), admin));
        console.log("Admin has FACTORY_OPERATOR_ROLE:", factory.hasRole(factory.FACTORY_OPERATOR_ROLE(), admin));
    }
}
