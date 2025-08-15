// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../contracts/interfaces/ICrowdsale.sol";

/**
 * @title MockCrowdsale
 * @dev Minimal mock implementation for testing RefundVault
 */
contract MockCrowdsale {
    ICrowdsale.CrowdsaleStats private _stats;
    ICrowdsale.CrowdsaleConfig private _config;
    
    constructor() {
        // Set default config for testing - use safe timestamps
        uint256 currentTime = block.timestamp;
        if (currentTime < 2000) {
            currentTime = 2000; // Ensure we have enough buffer for subtraction
        }
        
        _config = ICrowdsale.CrowdsaleConfig({
            presaleStartTime: currentTime - 1000,
            presaleEndTime: currentTime - 500,
            publicSaleStartTime: currentTime - 500,
            publicSaleEndTime: currentTime + 1000, // Future end time
            softCap: 10 ether,
            hardCap: 100 ether,
            minPurchase: 0.1 ether,
            maxPurchase: 10 ether
        });
        
        // Set default stats
        _stats = ICrowdsale.CrowdsaleStats({
            totalRaised: 5 ether, // Below soft cap
            totalTokensSold: 5000 * 10**18,
            totalPurchases: 3,
            totalParticipants: 2,
            participantCount: 2,
            presaleRaised: 2 ether,
            publicSaleRaised: 3 ether
        });
    }
    
    function getCrowdsaleStats() external view returns (ICrowdsale.CrowdsaleStats memory) {
        return _stats;
    }
    
    function getCrowdsaleConfig() external view returns (ICrowdsale.CrowdsaleConfig memory) {
        return _config;
    }
    
    // Helper functions for testing
    function setTotalRaised(uint256 amount) external {
        _stats.totalRaised = amount;
    }
    
    function setSoftCap(uint256 softCap) external {
        _config.softCap = softCap;
    }
    
    function setPublicSaleEndTime(uint256 endTime) external {
        _config.publicSaleEndTime = endTime;
    }
    
    // Allow receiving ETH
    receive() external payable {}
}
