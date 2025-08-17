// Contract configurations and ABIs based on analyzed interfaces

export const CONTRACT_ABIS = {
  TokenCrowdsale: [
    // View functions
    "function getCurrentPhase() external view returns (uint8)",
    "function getCrowdsaleConfig() external view returns (tuple(uint256 presaleStartTime, uint256 presaleEndTime, uint256 publicSaleStartTime, uint256 publicSaleEndTime, uint256 softCap, uint256 hardCap, uint256 minPurchase, uint256 maxPurchase))",
    "function getCrowdsaleStats() external view returns (tuple(uint256 totalRaised, uint256 totalTokensSold, uint256 totalPurchases, uint256 totalParticipants, uint256 participantCount, uint256 presaleRaised, uint256 publicSaleRaised))",
    "function isInValidTimeWindow() external view returns (bool)",
    "function isSoftCapReached() external view returns (bool)",
    "function isHardCapReached() external view returns (bool)",
    "function getFundingProgress() external view returns (uint256)",
    "function getRemainingFunding() external view returns (uint256)",
    "function paused() external view returns (bool)",
    "function token() external view returns (address)",
    "function whitelistManager() external view returns (address)",
    "function fundingWallet() external view returns (address)",
    
    // Role checking functions
    "function hasRole(bytes32 role, address account) external view returns (bool)",
    
    // Purchase and pricing functions
    "function getUserPurchaseHistory(address user) external view returns (tuple(uint256 weiAmount, uint256 tokenAmount, uint256 timestamp, bool isWhitelisted)[])",
    "function getUserTotalPurchased(address user) external view returns (uint256)",
    "function getCurrentTokenPrice() external view returns (uint256)",
    "function getTokenPriceForUser(address user) external view returns (uint256)",
    "function calculateTokenAmount(uint256 weiAmount, address buyer) external view returns (uint256)",
    "function canPurchase(address buyer, uint256 weiAmount) external view returns (bool)",
    "function getRemainingTokens() external view returns (uint256)",
    "function hasUserParticipated(address user) external view returns (bool)",
    
    // State management functions
    "function purchaseTokens() external payable",
    "function batchPurchase(address[] calldata buyers, uint256[] calldata weiAmounts) external payable",
    "function startPresale() external",
    "function startPublicSale() external",
    "function finalizeCrowdsale() external",
    "function emergencyPause(string calldata reason) external",
    "function emergencyResume(string calldata reason) external",
    
    // Configuration functions
    "function updateConfig(tuple(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)) external",
    "function updateTimeConfig(uint256,uint256,uint256,uint256) external",
    "function updateFundingTargets(uint256,uint256) external",
    "function updatePurchaseLimits(uint256,uint256) external",
    "function updateFundingWallet(address payable) external",
    "function setPricingStrategy(address) external",
    "function setRefundVault(address) external",
    "function setVestingContract(address) external",
    "function setVestingConfig(bool,uint256,uint256,uint8,uint256) external",
    
    // Events
    "event PhaseChanged(uint8 indexed previousPhase, uint8 indexed newPhase, uint256 timestamp, address indexed changedBy)",
    "event TokensPurchased(address indexed buyer, uint256 amount, uint256 tokenAmount, uint8 indexed phase)",
    "event ConfigUpdated(tuple(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) config, address indexed updatedBy)",
    "event CapReached(string indexed capType, uint256 amount, uint256 timestamp)",
    "event EmergencyAction(string action, address indexed executor, uint256 timestamp, string reason)"
  ],
  
  CrowdsaleFactory: [
    // Core functions - Updated to match interface struct definitions
    "function createCrowdsale(tuple(string tokenName, string tokenSymbol, uint256 totalSupply, uint256 softCap, uint256 hardCap, uint256 startTime, uint256 endTime, address fundingWallet, uint256 tokenPrice, tuple(bool enabled, uint256 cliffDuration, uint256 vestingDuration, uint8 vestingType, uint256 immediateReleasePercentage) vestingParams)) external payable returns (address crowdsaleAddress, address tokenAddress, address vestingAddress)",
    "function batchCreateCrowdsale(tuple(string tokenName, string tokenSymbol, uint256 totalSupply, uint256 softCap, uint256 hardCap, uint256 startTime, uint256 endTime, address fundingWallet, uint256 tokenPrice, tuple(bool enabled, uint256 cliffDuration, uint256 vestingDuration, uint8 vestingType, uint256 immediateReleasePercentage) vestingParams)[]) external payable returns (address[])",
    
    // Query functions - Updated to match CrowdsaleInstance struct
    "function getCrowdsaleInstance(address) external view returns (tuple(address crowdsaleAddress, address tokenAddress, address vestingAddress, address creator, uint256 createdAt, bool isActive))",
    "function getCreatorCrowdsales(address) external view returns (tuple(address crowdsaleAddress, address tokenAddress, address vestingAddress, address creator, uint256 createdAt, bool isActive)[])",
    "function getActiveCrowdsales() external view returns (tuple(address crowdsaleAddress, address tokenAddress, address vestingAddress, address creator, uint256 createdAt, bool isActive)[])",
    "function getTotalCrowdsales() external view returns (uint256)",
    "function validateCrowdsaleParams(tuple(string tokenName, string tokenSymbol, uint256 totalSupply, uint256 softCap, uint256 hardCap, uint256 startTime, uint256 endTime, address fundingWallet, uint256 tokenPrice, tuple(bool enabled, uint256 cliffDuration, uint256 vestingDuration, uint8 vestingType, uint256 immediateReleasePercentage) vestingParams)) external view returns (bool isValid, string memory errorMessage)",
    "function getFactoryStats() external view returns (uint256 totalCrowdsales, uint256 activeCrowdsales, uint256 totalFeesCollected)",
    
    // Management functions
    "function updateCrowdsaleStatus(address, bool) external",
    "function setCreationFee(uint256) external",
    "function setPublicCreationAllowed(bool) external",
    "function withdrawFees(address payable, uint256) external",
    "function getCreationFee() external view returns (uint256)",
    "function isPublicCreationAllowed() external view returns (bool)",
    
    // Events
    "event CrowdsaleCreated(address indexed creator, address indexed crowdsaleAddress, address indexed tokenAddress, address vestingAddress, string tokenName, string tokenSymbol)",
    "event CrowdsaleStatusUpdated(address indexed crowdsaleAddress, bool isActive)",
    "event FactoryConfigUpdated(address indexed admin, uint256 creationFee, bool publicCreation)"
  ],
  
  TokenVesting: [
    // Core functions
    "function createVestingSchedule(address, uint256, uint256, uint256, uint8) external",
    "function releaseTokens(bytes32) external",
    "function revokeVesting(bytes32) external",
    "function batchRelease(bytes32[]) external",
    
    // Query functions
    "function getVestingSchedule(address) external view returns (tuple(address,uint256,uint256,uint256,uint256,uint8,bool))",
    "function getReleasableAmount(bytes32) external view returns (uint256)",
    "function getBeneficiaries() external view returns (address[])",
    "function getTotalVestingSchedules() external view returns (uint256)",
    
    // Events
    "event VestingScheduleCreated(bytes32 indexed scheduleId, address indexed beneficiary, uint256 amount)",
    "event TokensReleased(bytes32 indexed scheduleId, address indexed beneficiary, uint256 amount)",
    "event VestingRevoked(bytes32 indexed scheduleId, address indexed beneficiary, uint256 revokedAmount)"
  ],
  
  CrowdsaleToken: [
    // ERC20 functions
    "function name() external view returns (string)",
    "function symbol() external view returns (string)",
    "function decimals() external view returns (uint8)",
    "function totalSupply() external view returns (uint256)",
    "function balanceOf(address) external view returns (uint256)",
    "function transfer(address, uint256) external returns (bool)",
    "function allowance(address, address) external view returns (uint256)",
    "function approve(address, uint256) external returns (bool)",
    "function transferFrom(address, address, uint256) external returns (bool)",
    
    // Extended functions
    "function mint(address, uint256) external",
    "function batchMint(address[], uint256[]) external",
    "function burn(uint256) external",
    "function burnFrom(address, uint256) external",
    "function maxSupply() external view returns (uint256)",
    "function remainingMintable() external view returns (uint256)",
    "function canMint() external view returns (bool)",
    
    // Events
    "event Transfer(address indexed from, address indexed to, uint256 value)",
    "event Approval(address indexed owner, address indexed spender, uint256 value)"
  ],
  
  WhitelistManager: [
    // Core functions - Updated to match actual contract
    "function addToWhitelist(address user, uint8 level) external",
    "function removeFromWhitelist(address user) external", 
    "function batchAddToWhitelist(address[] calldata users, uint8[] calldata levels) external",
    "function batchRemoveFromWhitelist(address[] calldata users) external",
    "function addToWhitelistWithExpiration(address user, uint8 level, uint256 expirationTime) external",
    "function transferWhitelistStatus(address from, address to) external",
    
    // Query functions - Updated to match actual contract
    "function isWhitelisted(address user) external view returns (bool)",
    "function isVIP(address user) external view returns (bool)",
    "function isBlacklisted(address user) external view returns (bool)",
    "function isExpired(address user) external view returns (bool)",
    "function getWhitelistStatus(address user) external view returns (uint8)",
    "function getWhitelistInfo(address user) external view returns (tuple(uint8 level, uint256 expirationTime, uint256 addedTime, address addedBy))",
    "function getWhitelistStats() external view returns (uint256 vipCount, uint256 whitelistedCount, uint256 blacklistedCount, uint256 totalCount)",
    
    // Management functions
    "function cleanupExpiredWhitelists(address[] calldata users) external",
    "function pause() external",
    "function unpause() external",
    "function paused() external view returns (bool)",
    
    // AccessControl functions (inherited from OpenZeppelin)
    "function hasRole(bytes32 role, address account) external view returns (bool)",
    "function grantRole(bytes32 role, address account) external",
    "function revokeRole(bytes32 role, address account) external",
    "function renounceRole(bytes32 role, address account) external",
    "function getRoleAdmin(bytes32 role) external view returns (bytes32)",
    "function DEFAULT_ADMIN_ROLE() external view returns (bytes32)",
    "function WHITELIST_ADMIN_ROLE() external view returns (bytes32)",
    "function WHITELIST_OPERATOR_ROLE() external view returns (bytes32)",
    
    // New query functions for frontend - simplified ABI
    "function getAllWhitelistUsers(uint256 offset, uint256 limit) external view returns (address[], uint256)",
    
    // Events - Updated to match actual contract
    "event WhitelistAdded(address indexed user, uint8 indexed level, uint256 expirationTime, address indexed addedBy)",
    "event WhitelistRemoved(address indexed user, uint8 indexed previousLevel, address indexed removedBy)",
    "event WhitelistTransferred(address indexed from, address indexed to, uint8 indexed level, address transferredBy)",
    "event WhitelistExpired(address indexed user, uint8 indexed previousLevel)",
    "event BatchWhitelistAdded(address[] users, uint8[] levels, uint256 expirationTime, address indexed addedBy)"
  ]
} as const;

export const getContractAddress = (contractName: string): string | null => {
  const envKey = `VITE_${contractName.toUpperCase()}_ADDRESS`;
  const envAddress = import.meta.env[envKey];
  
  // console.log(`Getting contract address for ${contractName}:`, {
  //   envKey,
  //   envAddress,
  //   allEnvVars: Object.keys(import.meta.env).filter(key => key.startsWith('VITE_'))
  // });
  
  // 如果环境变量未设置或为空，返回null而不是抛出错误
  if (!envAddress || envAddress.trim() === '') {
    console.warn(`Contract address for ${contractName} not found. Environment key: ${envKey}`);
    return null;
  }
  
  return envAddress.trim();
};

export const getContractABI = (contractName: keyof typeof CONTRACT_ABIS) => {
  return CONTRACT_ABIS[contractName];
};

// Export CONTRACT_ABIS as CONTRACTS for backward compatibility
export const CONTRACTS = CONTRACT_ABIS;
