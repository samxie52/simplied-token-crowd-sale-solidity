// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/TokenCrowdsale.sol";
import "../contracts/CrowdsaleToken.sol";
import "../contracts/WhitelistManager.sol";
import "../contracts/interfaces/ICrowdsale.sol";
import "../contracts/utils/CrowdsaleConstants.sol";

/**
 * @title DeployCrowdsale
 * @dev 部署TokenCrowdsale合约的脚本
 */
contract DeployCrowdsale is Script {
    
    // 部署配置
    struct DeploymentConfig {
        string tokenName;
        string tokenSymbol;
        uint256 tokenSupply;
        uint256 presaleStartTime;
        uint256 presaleEndTime;
        uint256 publicSaleStartTime;
        uint256 publicSaleEndTime;
        uint256 softCap;
        uint256 hardCap;
        uint256 minPurchase;
        uint256 maxPurchase;
        address payable fundingWallet;
    }
    
    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== TokenCrowdsale Deployment Script ===");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        // 获取部署配置
        DeploymentConfig memory config = _getDeploymentConfig();
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署ERC20代币合约
        console.log("\n1. Deploying CrowdsaleToken...");
        CrowdsaleToken token = new CrowdsaleToken(
            config.tokenName,
            config.tokenSymbol,
            config.tokenSupply,
            deployer
        );
        console.log("CrowdsaleToken deployed at:", address(token));
        
        // 2. 部署白名单管理合约
        console.log("\n2. Deploying WhitelistManager...");
        WhitelistManager whitelistManager = new WhitelistManager(deployer);
        console.log("WhitelistManager deployed at:", address(whitelistManager));
        
        // 3. 部署众筹合约
        console.log("\n3. Deploying TokenCrowdsale...");
        TokenCrowdsale crowdsale = new TokenCrowdsale(
            address(token),
            address(whitelistManager),
            config.fundingWallet,
            deployer
        );
        console.log("TokenCrowdsale deployed at:", address(crowdsale));
        
        // 4. 配置众筹参数
        console.log("\n4. Configuring crowdsale parameters...");
        ICrowdsale.CrowdsaleConfig memory crowdsaleConfig = ICrowdsale.CrowdsaleConfig({
            presaleStartTime: config.presaleStartTime,
            presaleEndTime: config.presaleEndTime,
            publicSaleStartTime: config.publicSaleStartTime,
            publicSaleEndTime: config.publicSaleEndTime,
            softCap: config.softCap,
            hardCap: config.hardCap,
            minPurchase: config.minPurchase,
            maxPurchase: config.maxPurchase
        });
        
        crowdsale.updateConfig(crowdsaleConfig);
        console.log("Crowdsale configuration updated successfully");
        
        // 5. 设置代币合约的众筹合约地址（如果需要）
        console.log("\n5. Setting up token permissions...");
        // 注意：这里可能需要给众筹合约铸币权限，具体取决于代币合约设计
        
        // 6. 验证部署
        console.log("\n6. Verifying deployment...");
        _verifyDeployment(token, whitelistManager, crowdsale, config);
        
        vm.stopBroadcast();
        
        // 7. 输出部署信息
        _outputDeploymentInfo(token, whitelistManager, crowdsale, config);
    }
    
    /**
     * @dev 获取部署配置
     */
    function _getDeploymentConfig() internal view returns (DeploymentConfig memory) {
        // 从环境变量获取配置，如果没有则使用默认值
        string memory tokenName = vm.envOr("TOKEN_NAME", string("CrowdsaleToken"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("CST"));
        uint256 tokenSupply = vm.envOr("TOKEN_SUPPLY", uint256(1_000_000 * 10**18));
        
        // 时间配置（默认：1小时后开始预售，持续7天，然后公售14天）
        uint256 presaleStartTime = vm.envOr("PRESALE_START_TIME", uint256(block.timestamp + 1 hours));
        uint256 presaleEndTime = vm.envOr("PRESALE_END_TIME", uint256(presaleStartTime + 7 days));
        uint256 publicSaleStartTime = vm.envOr("PUBLIC_SALE_START_TIME", uint256(presaleEndTime + 1 hours));
        uint256 publicSaleEndTime = vm.envOr("PUBLIC_SALE_END_TIME", uint256(publicSaleStartTime + 14 days));
        
        // 资金目标配置
        uint256 softCap = vm.envOr("SOFT_CAP", uint256(10 ether));
        uint256 hardCap = vm.envOr("HARD_CAP", uint256(100 ether));
        
        // 购买限额配置
        uint256 minPurchase = vm.envOr("MIN_PURCHASE", uint256(0.1 ether));
        uint256 maxPurchase = vm.envOr("MAX_PURCHASE", uint256(10 ether));
        
        // 资金接收钱包
        address payable fundingWallet = payable(vm.envOr("FUNDING_WALLET", vm.addr(vm.envUint("PRIVATE_KEY"))));
        
        return DeploymentConfig({
            tokenName: tokenName,
            tokenSymbol: tokenSymbol,
            tokenSupply: tokenSupply,
            presaleStartTime: presaleStartTime,
            presaleEndTime: presaleEndTime,
            publicSaleStartTime: publicSaleStartTime,
            publicSaleEndTime: publicSaleEndTime,
            softCap: softCap,
            hardCap: hardCap,
            minPurchase: minPurchase,
            maxPurchase: maxPurchase,
            fundingWallet: fundingWallet
        });
    }
    
    /**
     * @dev 验证部署结果
     */
    function _verifyDeployment(
        CrowdsaleToken token,
        WhitelistManager whitelistManager,
        TokenCrowdsale crowdsale,
        DeploymentConfig memory config
    ) internal view {
        // 验证代币合约
        require(
            keccak256(bytes(token.name())) == keccak256(bytes(config.tokenName)),
            "Token name mismatch"
        );
        require(
            keccak256(bytes(token.symbol())) == keccak256(bytes(config.tokenSymbol)),
            "Token symbol mismatch"
        );
        require(token.totalSupply() == config.tokenSupply, "Token supply mismatch");
        
        // 验证众筹合约
        require(address(crowdsale.token()) == address(token), "Token address mismatch");
        require(address(crowdsale.whitelistManager()) == address(whitelistManager), "WhitelistManager address mismatch");
        require(crowdsale.fundingWallet() == config.fundingWallet, "Funding wallet mismatch");
        
        // 验证众筹配置
        ICrowdsale.CrowdsaleConfig memory crowdsaleConfig = crowdsale.getCrowdsaleConfig();
        require(crowdsaleConfig.presaleStartTime == config.presaleStartTime, "Presale start time mismatch");
        require(crowdsaleConfig.presaleEndTime == config.presaleEndTime, "Presale end time mismatch");
        require(crowdsaleConfig.publicSaleStartTime == config.publicSaleStartTime, "Public sale start time mismatch");
        require(crowdsaleConfig.publicSaleEndTime == config.publicSaleEndTime, "Public sale end time mismatch");
        require(crowdsaleConfig.softCap == config.softCap, "Soft cap mismatch");
        require(crowdsaleConfig.hardCap == config.hardCap, "Hard cap mismatch");
        require(crowdsaleConfig.minPurchase == config.minPurchase, "Min purchase mismatch");
        require(crowdsaleConfig.maxPurchase == config.maxPurchase, "Max purchase mismatch");
        
        // 验证初始状态
        require(
            crowdsale.getCurrentPhase() == ICrowdsale.CrowdsalePhase.PENDING,
            "Initial phase should be PENDING"
        );
        
        // 验证权限设置
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        require(crowdsale.hasRole(crowdsale.DEFAULT_ADMIN_ROLE(), deployer), "Admin role not set");
        require(crowdsale.hasRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE, deployer), "Crowdsale admin role not set");
        require(crowdsale.hasRole(CrowdsaleConstants.EMERGENCY_ROLE, deployer), "Emergency role not set");
        
        console.log("All deployment verifications passed!");
    }
    
    /**
     * @dev 输出部署信息
     */
    function _outputDeploymentInfo(
        CrowdsaleToken token,
        WhitelistManager whitelistManager,
        TokenCrowdsale crowdsale,
        DeploymentConfig memory config
    ) internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("Block number:", block.number);
        console.log("Timestamp:", block.timestamp);
        
        console.log("\n=== Contract Addresses ===");
        console.log("CrowdsaleToken:", address(token));
        console.log("WhitelistManager:", address(whitelistManager));
        console.log("TokenCrowdsale:", address(crowdsale));
        
        console.log("\n=== Token Configuration ===");
        console.log("Name:", config.tokenName);
        console.log("Symbol:", config.tokenSymbol);
        console.log("Total Supply:", config.tokenSupply);
        console.log("Decimals:", token.decimals());
        
        console.log("\n=== Crowdsale Configuration ===");
        console.log("Presale Start:", config.presaleStartTime);
        console.log("Presale End:", config.presaleEndTime);
        console.log("Public Sale Start:", config.publicSaleStartTime);
        console.log("Public Sale End:", config.publicSaleEndTime);
        console.log("Soft Cap (ETH):", config.softCap / 1 ether);
        console.log("Hard Cap (ETH):", config.hardCap / 1 ether);
        console.log("Min Purchase (ETH):", config.minPurchase / 1 ether);
        console.log("Max Purchase (ETH):", config.maxPurchase / 1 ether);
        console.log("Funding Wallet:", config.fundingWallet);
        
        console.log("\n=== Current Status ===");
        console.log("Current Phase:", uint256(crowdsale.getCurrentPhase()));
        console.log("Is Paused:", crowdsale.paused());
        console.log("Time to Presale Start:", 
            config.presaleStartTime > block.timestamp ? 
            config.presaleStartTime - block.timestamp : 0
        );
        
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        console.log("Total Raised:", stats.totalRaised);
        console.log("Participant Count:", stats.participantCount);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Test crowdsale functionality");
        console.log("3. Configure frontend with contract addresses");
        console.log("4. Set up monitoring and alerts");
        
        console.log("\n=== Environment Variables Used ===");
        console.log("TOKEN_NAME:", config.tokenName);
        console.log("TOKEN_SYMBOL:", config.tokenSymbol);
        console.log("FUNDING_WALLET:", config.fundingWallet);
        
        console.log("\n=== Deployment Completed Successfully! ===");
    }
}
