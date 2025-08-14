// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPricingStrategy.sol";
import "../interfaces/IWhitelistManager.sol";
import "../interfaces/ICrowdsale.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title TieredPricingStrategy
 * @dev Tiered pricing strategy based on crowdsale progress with whitelist discounts
 * @author TokenCrowdsale Team
 */
contract TieredPricingStrategy is IPricingStrategy, AccessControl {
    
    // ============ Constants ============
    
    bytes32 public constant PRICING_ADMIN_ROLE = keccak256("PRICING_ADMIN_ROLE");
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant MAX_DISCOUNT = 5000;  // Maximum 50% discount
    uint256 public constant MAX_TIERS = 10;       // Maximum number of price tiers
    
    // ============ Structs ============
    
    /**
     * @dev Price tier structure
     */
    struct PriceTier {
        uint256 progressThreshold;  // Progress threshold in basis points (0-10000)
        uint256 pricePerToken;     // Price per token in wei for this tier
        bool isActive;             // Whether this tier is active
    }
    
    // ============ State Variables ============
    
    ICrowdsale public crowdsale;                 // Crowdsale contract reference
    IWhitelistManager public whitelistManager;   // Whitelist contract reference
    
    PriceTier[] public priceTiers;               // Array of price tiers
    uint256 public currentTierIndex;             // Current active tier index
    
    // Whitelist discounts in basis points (10000 = 100%)
    mapping(IWhitelistManager.WhitelistLevel => uint256) public whitelistDiscounts;
    
    // ============ Events ============
    
    event TierAdded(uint256 indexed tierIndex, uint256 threshold, uint256 price);
    event TierUpdated(uint256 indexed tierIndex, uint256 threshold, uint256 price);
    event TierActivated(uint256 indexed tierIndex, uint256 price);
    
    // ============ Constructor ============
    
    constructor(
        address _crowdsale,
        address _whitelistManager,
        address _admin
    ) {
        require(_crowdsale != address(0), "TieredPricing: invalid crowdsale");
        require(_whitelistManager != address(0), "TieredPricing: invalid whitelist manager");
        require(_admin != address(0), "TieredPricing: invalid admin");
        
        crowdsale = ICrowdsale(_crowdsale);
        whitelistManager = IWhitelistManager(_whitelistManager);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PRICING_ADMIN_ROLE, _admin);
        
        // Setup default whitelist discounts
        whitelistDiscounts[IWhitelistManager.WhitelistLevel.VIP] = 2000;        // 20% discount
        whitelistDiscounts[IWhitelistManager.WhitelistLevel.WHITELISTED] = 1000; // 10% discount
        
        // Initialize default tiers
        _initializeDefaultTiers();
    }
    
    // ============ IPricingStrategy Implementation ============
    
    /**
     * @dev Calculate token amount for given wei amount and buyer
     */
    function calculateTokenAmount(uint256 weiAmount, address buyer) 
        external view override returns (uint256) {
        require(weiAmount > 0, "TieredPricing: invalid wei amount");
        require(buyer != address(0), "TieredPricing: invalid buyer");
        
        uint256 priceForBuyer = getPriceForBuyer(buyer);
        return (weiAmount * 1e18) / priceForBuyer;
    }
    
    /**
     * @dev Get current price per token based on progress
     */
    function getCurrentPrice() external view override returns (uint256) {
        uint256 tierIndex = _getCurrentTierIndex();
        return priceTiers[tierIndex].pricePerToken;
    }
    
    /**
     * @dev Check if purchase is valid
     */
    function isValidPurchase(address buyer, uint256 weiAmount) 
        external view override returns (bool) {
        return buyer != address(0) && weiAmount > 0 && priceTiers.length > 0;
    }
    
    /**
     * @dev Get pricing strategy type
     */
    function getPricingType() external pure override returns (PricingType) {
        return PricingType.TIERED;
    }
    
    /**
     * @dev Get price for specific buyer (considering whitelist discounts)
     */
    function getPriceForBuyer(address buyer) public view override returns (uint256) {
        uint256 basePrice = this.getCurrentPrice();
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
        // Parameters: array of tier data
        PriceTier[] memory newTiers = abi.decode(parameters, (PriceTier[]));
        require(newTiers.length <= MAX_TIERS, "TieredPricing: too many tiers");
        
        // Clear existing tiers
        delete priceTiers;
        
        // Add new tiers
        for (uint256 i = 0; i < newTiers.length; i++) {
            require(newTiers[i].pricePerToken > 0, "TieredPricing: invalid price");
            require(newTiers[i].progressThreshold <= BASIS_POINTS, "TieredPricing: invalid threshold");
            
            if (i > 0) {
                require(
                    newTiers[i].progressThreshold > newTiers[i-1].progressThreshold,
                    "TieredPricing: thresholds must be ascending"
                );
            }
            
            priceTiers.push(newTiers[i]);
            emit TierAdded(i, newTiers[i].progressThreshold, newTiers[i].pricePerToken);
        }
        
        emit PricingParametersUpdated(PricingType.TIERED, parameters);
    }
    
    /**
     * @dev Set base price (updates all tiers proportionally)
     */
    function setBasePrice(uint256 newPrice) external override onlyRole(PRICING_ADMIN_ROLE) {
        require(newPrice > 0, "TieredPricing: invalid price");
        require(priceTiers.length > 0, "TieredPricing: no tiers configured");
        
        uint256 oldBasePrice = priceTiers[0].pricePerToken;
        uint256 priceRatio = (newPrice * BASIS_POINTS) / oldBasePrice;
        
        // Update all tier prices proportionally
        for (uint256 i = 0; i < priceTiers.length; i++) {
            uint256 oldPrice = priceTiers[i].pricePerToken;
            priceTiers[i].pricePerToken = (oldPrice * priceRatio) / BASIS_POINTS;
            
            emit TierUpdated(i, priceTiers[i].progressThreshold, priceTiers[i].pricePerToken);
        }
        
        emit PriceUpdated(oldBasePrice, newPrice, block.timestamp);
    }
    
    /**
     * @dev Add new price tier
     */
    function addTier(uint256 progressThreshold, uint256 pricePerToken) 
        external onlyRole(PRICING_ADMIN_ROLE) {
        require(priceTiers.length < MAX_TIERS, "TieredPricing: max tiers reached");
        require(pricePerToken > 0, "TieredPricing: invalid price");
        require(progressThreshold <= BASIS_POINTS, "TieredPricing: invalid threshold");
        
        if (priceTiers.length > 0) {
            require(
                progressThreshold > priceTiers[priceTiers.length - 1].progressThreshold,
                "TieredPricing: threshold must be higher than last tier"
            );
        }
        
        priceTiers.push(PriceTier({
            progressThreshold: progressThreshold,
            pricePerToken: pricePerToken,
            isActive: true
        }));
        
        emit TierAdded(priceTiers.length - 1, progressThreshold, pricePerToken);
    }
    
    /**
     * @dev Update specific tier
     */
    function updateTier(uint256 tierIndex, uint256 progressThreshold, uint256 pricePerToken) 
        external onlyRole(PRICING_ADMIN_ROLE) {
        require(tierIndex < priceTiers.length, "TieredPricing: tier not found");
        require(pricePerToken > 0, "TieredPricing: invalid price");
        require(progressThreshold <= BASIS_POINTS, "TieredPricing: invalid threshold");
        
        // Validate threshold ordering
        if (tierIndex > 0) {
            require(
                progressThreshold > priceTiers[tierIndex - 1].progressThreshold,
                "TieredPricing: threshold too low"
            );
        }
        if (tierIndex < priceTiers.length - 1) {
            require(
                progressThreshold < priceTiers[tierIndex + 1].progressThreshold,
                "TieredPricing: threshold too high"
            );
        }
        
        priceTiers[tierIndex].progressThreshold = progressThreshold;
        priceTiers[tierIndex].pricePerToken = pricePerToken;
        
        emit TierUpdated(tierIndex, progressThreshold, pricePerToken);
    }
    
    /**
     * @dev Set whitelist discount for specific level
     */
    function setWhitelistDiscount(IWhitelistManager.WhitelistLevel level, uint256 discount) 
        external onlyRole(PRICING_ADMIN_ROLE) {
        require(discount <= MAX_DISCOUNT, "TieredPricing: discount too high");
        
        whitelistDiscounts[level] = discount;
        
        emit PricingParametersUpdated(
            PricingType.TIERED, 
            abi.encode(level, discount)
        );
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev Initialize default price tiers
     */
    function _initializeDefaultTiers() internal {
        // Tier 1: 0-25% progress, 0.0001 ETH per token (75% discount from final price)
        priceTiers.push(PriceTier({
            progressThreshold: 2500,  // 25%
            pricePerToken: 0.0001 ether,
            isActive: true
        }));
        
        // Tier 2: 25-50% progress, 0.0002 ETH per token (50% discount from final price)
        priceTiers.push(PriceTier({
            progressThreshold: 5000,  // 50%
            pricePerToken: 0.0002 ether,
            isActive: true
        }));
        
        // Tier 3: 50-75% progress, 0.0003 ETH per token (25% discount from final price)
        priceTiers.push(PriceTier({
            progressThreshold: 7500,  // 75%
            pricePerToken: 0.0003 ether,
            isActive: true
        }));
        
        // Tier 4: 75-100% progress, 0.0004 ETH per token (standard price)
        priceTiers.push(PriceTier({
            progressThreshold: 10000, // 100%
            pricePerToken: 0.0004 ether,
            isActive: true
        }));
        
        emit TierAdded(0, 2500, 0.0001 ether);
        emit TierAdded(1, 5000, 0.0002 ether);
        emit TierAdded(2, 7500, 0.0003 ether);
        emit TierAdded(3, 10000, 0.0004 ether);
    }
    
    /**
     * @dev Get current tier index based on crowdsale progress
     */
    function _getCurrentTierIndex() internal view returns (uint256) {
        if (priceTiers.length == 0) {
            return 0;
        }
        
        uint256 progress = _getCrowdsaleProgress();
        
        for (uint256 i = 0; i < priceTiers.length; i++) {
            if (progress <= priceTiers[i].progressThreshold) {
                return i;
            }
        }
        
        // If progress exceeds all thresholds, return last tier
        return priceTiers.length - 1;
    }
    
    /**
     * @dev Calculate crowdsale progress in basis points
     */
    function _getCrowdsaleProgress() internal view returns (uint256) {
        ICrowdsale.CrowdsaleStats memory stats = crowdsale.getCrowdsaleStats();
        ICrowdsale.CrowdsaleConfig memory config = crowdsale.getCrowdsaleConfig();
        
        if (config.hardCap == 0) {
            return 0;
        }
        
        return (stats.totalRaised * BASIS_POINTS) / config.hardCap;
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Get all price tiers
     */
    function getAllTiers() external view returns (PriceTier[] memory) {
        return priceTiers;
    }
    
    /**
     * @dev Get current tier information
     */
    function getCurrentTierInfo() external view returns (
        uint256 tierIndex,
        uint256 progressThreshold,
        uint256 pricePerToken,
        uint256 currentProgress
    ) {
        tierIndex = _getCurrentTierIndex();
        if (tierIndex < priceTiers.length) {
            progressThreshold = priceTiers[tierIndex].progressThreshold;
            pricePerToken = priceTiers[tierIndex].pricePerToken;
        }
        currentProgress = _getCrowdsaleProgress();
    }
    
    /**
     * @dev Get pricing information for buyer
     */
    function getPricingInfo(address buyer) external view returns (
        uint256 currentTierIndex_,
        uint256 basePrice,
        uint256 finalPrice,
        uint256 discount,
        uint256 progress,
        bool isWhitelisted
    ) {
        currentTierIndex_ = _getCurrentTierIndex();
        basePrice = this.getCurrentPrice();
        finalPrice = getPriceForBuyer(buyer);
        discount = getDiscountForBuyer(buyer);
        progress = _getCrowdsaleProgress();
        isWhitelisted = whitelistManager.isWhitelisted(buyer);
    }
    
    /**
     * @dev Get number of tiers
     */
    function getTierCount() external view returns (uint256) {
        return priceTiers.length;
    }
}
