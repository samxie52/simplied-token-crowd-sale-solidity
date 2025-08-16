// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/CrowdsaleFactoryLite.sol";

/**
 * @title DeployFactoryLite
 * @dev 部署精简版众筹工厂合约脚本
 */
contract DeployFactoryLite is Script {
    
    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署参数
        uint256 creationFee = 0.01 ether; // 创建费用
        bool publicCreationAllowed = true; // 允许公开创建
        
        console.log("Deploying CrowdsaleFactoryLite...");
        console.log("Creation Fee:", creationFee);
        console.log("Public Creation Allowed:", publicCreationAllowed);
        
        // 部署精简版工厂合约
        CrowdsaleFactoryLite factory = new CrowdsaleFactoryLite(
            creationFee,
            publicCreationAllowed
        );
        
        console.log("CrowdsaleFactoryLite deployed at:", address(factory));
        
        // 验证部署
        console.log("Verifying deployment...");
        console.log("Creation Fee:", factory.getCreationFee());
        console.log("Public Creation Allowed:", factory.isPublicCreationAllowed());
        console.log("Total Crowdsales:", factory.getTotalCrowdsales());
        
        vm.stopBroadcast();
        
        console.log("Deployment completed successfully!");
        console.log("Factory Address:", address(factory));
    }
}
