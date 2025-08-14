// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPricingStrategy.sol";
import "../interfaces/IWhitelistManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title FixedPricingStrategy
 * @dev Fixed price strategy with whitelist discounts
 * @author TokenCrowdsale Team
 */
contract FixedPricingStrategy is IPricingStrategy, AccessControl {
    
    // ============ Constants ============
    
    bytes32 public constant PRICING_ADMIN_ROLE = keccak256("PRICING_ADMIN_ROLE");
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant MAX_DISCOUNT = 5000;  // Maximum 50% discount
    
    // ============ State Variables ============
    
    uint256 public basePrice;                    // Base price per token in wei
    IWhitelistManager public whitelistManager;   // Whitelist contract reference
    
    // Whitelist discounts in basis points (10000 = 100%)
    mapping(IWhitelistManager.WhitelistLevel => uint256) public whitelistDiscounts;
    
    // ============ Constructor ============
    
    constructor(
        uint256 _basePrice,
        address _whitelistManager,
        address _admin
    ) {
        require(_basePrice > 0, "FixedPricing: invalid base price");
        require(_whitelistManager != address(0), "FixedPricing: invalid whitelist manager");
        require(_admin != address(0), "FixedPricing: invalid admin");
        
        basePrice = _basePrice;
        whitelistManager = IWhitelistManager(_whitelistManager);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PRICING_ADMIN_ROLE, _admin);
        
        // Setup default whitelist discounts
        whitelistDiscounts[IWhitelistManager.WhitelistLevel.VIP] = 2000;        // 20% discount
        whitelistDiscounts[IWhitelistManager.WhitelistLevel.WHITELISTED] = 1000; // 10% discount
        
        emit PriceUpdated(0, _basePrice, block.timestamp);
    }
    
    // ============ IPricingStrategy Implementation ============
    
    /**
     * @dev Calculate token amount for given wei amount and buyer
     */
    function calculateTokenAmount(uint256 weiAmount, address buyer) 
        external view override returns (uint256) {
        require(weiAmount > 0, "FixedPricing: invalid wei amount");
        require(buyer != address(0), "FixedPricing: invalid buyer");
        
        uint256 priceForBuyer = getPriceForBuyer(buyer);
        return (weiAmount * 1e18) / priceForBuyer;
    }
    
    /**
     * @dev Get current base price per token
     */
    function getCurrentPrice() external view override returns (uint256) {
        return basePrice;
    }
    
    /**
     * @dev Check if purchase is valid
     */
    function isValidPurchase(address buyer, uint256 weiAmount) 
        external view override returns (bool) {
        return buyer != address(0) && weiAmount > 0;
    }
    
    /**
     * @dev Get pricing strategy type
     */
    function getPricingType() external pure override returns (PricingType) {
        return PricingType.FIXED;
    }
    
    /**
     * @dev Get price for specific buyer (considering whitelist discounts)
     */
    function getPriceForBuyer(address buyer) public view override returns (uint256) {
        uint256 discount = getDiscountForBuyer(buyer);
        if (discount == 0) {
            return basePrice;
        }
        
        return basePrice * (BASIS_POINTS - discount) / BASIS_POINTS;
    }
    
    /**
     * @dev Get discount percentage for buyer
     */
    function getDiscountForBuyer(address buyer) public view override returns (uint256) {
        if (!whitelistManager.isWhitelisted(buyer)) {
            return 0;
        }
        
        IWhitelistManager.WhitelistInfo memory info = whitelistManager.getWhitelistInfo(buyer);
        return whitelistDiscounts[info.level];
    }
    
    /**
     * @dev Check if buyer is eligible for special pricing
     */
    function isEligibleForSpecialPricing(address buyer) external view override returns (bool) {
        return whitelistManager.isWhitelisted(buyer);
    }
    
    // ============ Administrative Functions ============
    
    /**
     * @dev Update pricing parameters
     */
    function updatePricingParameters(bytes calldata parameters) 
        external override onlyRole(PRICING_ADMIN_ROLE) {
        // For fixed pricing, parameters could include new discounts
        (uint256 vipDiscount, uint256 whitelistedDiscount) = 
            abi.decode(parameters, (uint256, uint256));
        
        require(vipDiscount <= MAX_DISCOUNT, "FixedPricing: VIP discount too high");
        require(whitelistedDiscount <= MAX_DISCOUNT, "FixedPricing: whitelisted discount too high");
        
        whitelistDiscounts[IWhitelistManager.WhitelistLevel.VIP] = vipDiscount;
        whitelistDiscounts[IWhitelistManager.WhitelistLevel.WHITELISTED] = whitelistedDiscount;
        
        emit PricingParametersUpdated(PricingType.FIXED, parameters);
    }
    
    /**
     * @dev Set base price
     */
    function setBasePrice(uint256 newPrice) external override onlyRole(PRICING_ADMIN_ROLE) {
        require(newPrice > 0, "FixedPricing: invalid price");
        
        uint256 oldPrice = basePrice;
        basePrice = newPrice;
        
        emit PriceUpdated(oldPrice, newPrice, block.timestamp);
    }
    
    /**
     * @dev Set whitelist discount for specific level
     */
    function setWhitelistDiscount(IWhitelistManager.WhitelistLevel level, uint256 discount) 
        external onlyRole(PRICING_ADMIN_ROLE) {
        require(discount <= MAX_DISCOUNT, "FixedPricing: discount too high");
        
        whitelistDiscounts[level] = discount;
        
        emit PricingParametersUpdated(
            PricingType.FIXED, 
            abi.encode(level, discount)
        );
    }
    
    /**
     * @dev Update whitelist manager contract
     */
    function setWhitelistManager(address newWhitelistManager) 
        external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newWhitelistManager != address(0), "FixedPricing: invalid address");
        whitelistManager = IWhitelistManager(newWhitelistManager);
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Get whitelist discount for specific level
     */
    function getWhitelistDiscount(IWhitelistManager.WhitelistLevel level) 
        external view returns (uint256) {
        return whitelistDiscounts[level];
    }
    
    /**
     * @dev Get all pricing information for buyer
     */
    function getPricingInfo(address buyer) external view returns (
        uint256 basePrice_,
        uint256 finalPrice,
        uint256 discount,
        bool isWhitelisted,
        IWhitelistManager.WhitelistLevel level
    ) {
        basePrice_ = basePrice;
        finalPrice = getPriceForBuyer(buyer);
        discount = getDiscountForBuyer(buyer);
        isWhitelisted = whitelistManager.isWhitelisted(buyer);
        
        if (isWhitelisted) {
            IWhitelistManager.WhitelistInfo memory info = whitelistManager.getWhitelistInfo(buyer);
            level = info.level;
        }
    }
}
