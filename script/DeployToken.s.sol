// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/CrowdsaleToken.sol";

contract DeployToken is Script {

    string constant TOKEN_NAME = "Crowdsale Token";
    string constant TOKEN_SYMBOL = "CST";
    uint256 constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    function fun() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying CrowdsaleToken...");
        console.log("Deployer address: %s", deployer);
        console.log("Token name: %s", TOKEN_NAME);
        console.log("Token symbol: %s", TOKEN_SYMBOL);
        console.log("Max supply: %s", MAX_SUPPLY);

        vm.startBroadcast(deployerPrivateKey);

        CrowdsaleToken token = new CrowdsaleToken(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            MAX_SUPPLY,
            deployer
        );

        vm.stopBroadcast();

        console.log("CrowdsaleToken deployed at: %s", address(token));
        console.log("Deployment completed successfully.");


        // 验证部署
        _verifyDeployment(token, deployer);
    }

    function _verifyDeployment(CrowdsaleToken token, address admin) internal view {
        console.log("\n=== Deployment Verification ===");
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        console.log("Max Supply:", token.maxSupply());
        console.log("Current Supply:", token.totalSupply());
        console.log("Is Paused:", token.paused());
        
        console.log("\n=== Role Verification ===");
        console.log("Admin has DEFAULT_ADMIN_ROLE:", token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        console.log("Admin has MINTER_ROLE:", token.hasRole(token.MINTER_ROLE(), admin));
        console.log("Admin has PAUSER_ROLE:", token.hasRole(token.PAUSER_ROLE(), admin));
        console.log("Admin has BURNER_ROLE:", token.hasRole(token.BURNER_ROLE(), admin));
    
    }
}