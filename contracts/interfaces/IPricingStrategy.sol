// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPricingStrategy
 * @dev Interface for different pricing strategies in the crowdsale
 * @author TokenCrowdsale Team
 */
interface IPricingStrategy {
    
    // ============ Enums ============
    
    /**
     * @dev Pricing strategy types
     */
    enum PricingType {
        FIXED,      // Fixed price throughout the sale
        TIERED,     // Tiered pricing based on progress
        DYNAMIC,    // Dynamic pricing based on demand
        WHITELIST   // Special whitelist pricing
    }
    
    // ============ Events ============
    
    /**
     * @dev Emitted when price is updated
     */
    event PriceUpdated(uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    
    /**
     * @dev Emitted when pricing parameters are updated
     */
    event PricingParametersUpdated(PricingType pricingType, bytes parameters);
    
    // ============ Core Functions ============
    
    /**
     * @dev Calculate token amount for given wei amount and buyer
     * @param weiAmount Amount of wei being spent
     * @param buyer Address of the buyer
     * @return tokenAmount Amount of tokens to be received
     */
    function calculateTokenAmount(uint256 weiAmount, address buyer) 
        external view returns (uint256 tokenAmount);
    
    /**
     * @dev Get current price per token in wei
     * @return price Current price per token
     */
    function getCurrentPrice() external view returns (uint256 price);
    
    /**
     * @dev Check if purchase is valid for given buyer and amount
     * @param buyer Address of the buyer
     * @param weiAmount Amount of wei being spent
     * @return isValid Whether the purchase is valid
     */
    function isValidPurchase(address buyer, uint256 weiAmount) 
        external view returns (bool isValid);
    
    /**
     * @dev Get pricing strategy type
     * @return pricingType The type of this pricing strategy
     */
    function getPricingType() external view returns (PricingType pricingType);
    
    // ============ Query Functions ============
    
    /**
     * @dev Get price for specific buyer (considering whitelist discounts)
     * @param buyer Address of the buyer
     * @return price Price per token for this buyer
     */
    function getPriceForBuyer(address buyer) external view returns (uint256 price);
    
    /**
     * @dev Get discount percentage for buyer (in basis points, 10000 = 100%)
     * @param buyer Address of the buyer
     * @return discount Discount percentage in basis points
     */
    function getDiscountForBuyer(address buyer) external view returns (uint256 discount);
    
    /**
     * @dev Check if buyer is eligible for special pricing
     * @param buyer Address of the buyer
     * @return eligible Whether buyer is eligible for special pricing
     */
    function isEligibleForSpecialPricing(address buyer) external view returns (bool eligible);
    
    // ============ Administrative Functions ============
    
    /**
     * @dev Update pricing parameters (admin only)
     * @param parameters Encoded pricing parameters
     */
    function updatePricingParameters(bytes calldata parameters) external;
    
    /**
     * @dev Set base price (admin only)
     * @param newPrice New base price per token in wei
     */
    function setBasePrice(uint256 newPrice) external;
}
