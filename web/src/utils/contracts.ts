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
    "function token() external view returns (address)",
    "function whitelistManager() external view returns (address)",
    "function fundingWallet() external view returns (address)",
    
    // State management functions
    "function purchaseTokens() external payable",
    "function batchPurchase(address[] calldata recipients, uint256[] calldata amounts) external payable",
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
    
    // Events
    "event PhaseChanged(uint8 indexed previousPhase, uint8 indexed newPhase, uint256 timestamp, address indexed changedBy)",
    "event TokensPurchased(address indexed buyer, uint256 amount, uint256 tokenAmount, uint8 indexed phase)",
    "event ConfigUpdated(tuple(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) config, address indexed updatedBy)",
    "event CapReached(string indexed capType, uint256 amount, uint256 timestamp)",
    "event EmergencyAction(string action, address indexed executor, uint256 timestamp, string reason)"
  ],
  
  CrowdsaleFactory: [
    // Core functions
    "function createCrowdsale(tuple(string,string,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool)) external payable returns (address, address, address)",
    "function batchCreateCrowdsale(tuple(string,string,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool)[]) external payable returns (address[])",
    
    // Query functions
    "function getCrowdsaleInstance(address) external view returns (tuple(address,address,address,address,string,string,bool,uint256))",
    "function getCreatorCrowdsales(address) external view returns (tuple(address,address,address,address,string,string,bool,uint256)[])",
    "function getActiveCrowdsales() external view returns (tuple(address,address,address,address,string,string,bool,uint256)[])",
    "function getTotalCrowdsales() external view returns (uint256)",
    "function validateCrowdsaleParams(tuple(string,string,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bool)) external view returns (bool, string)",
    "function getFactoryStats() external view returns (uint256, uint256, uint256)",
    
    // Management functions
    "function updateCrowdsaleStatus(address, bool) external",
    "function setCreationFee(uint256) external",
    "function setPublicCreationAllowed(bool) external",
    "function withdrawFees(address, uint256) external",
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
    // Core functions
    "function addToWhitelist(address, uint8) external",
    "function removeFromWhitelist(address) external",
    "function batchAddToWhitelist(address[], uint8[]) external",
    "function batchRemoveFromWhitelist(address[]) external",
    
    // Query functions
    "function isWhitelisted(address) external view returns (bool)",
    "function getWhitelistInfo(address) external view returns (tuple(bool,uint8,uint256))",
    "function getWhitelistLevel(address) external view returns (uint8)",
    "function getTotalWhitelisted() external view returns (uint256)",
    "function getWhitelistedAddresses() external view returns (address[])",
    
    // Events
    "event AddedToWhitelist(address indexed account, uint8 level)",
    "event RemovedFromWhitelist(address indexed account)"
  ]
} as const;

export const getContractAddress = (contractName: string): string | null => {
  const envKey = `VITE_${contractName.toUpperCase()}_ADDRESS`;
  const envAddress = import.meta.env[envKey];
  
  // Fallback to hardcoded local addresses if env var not set
  if (!envAddress) {
    const localAddresses: Record<string, string> = {
      'CROWDSALEFACTORY': '0x0165878A594ca255338adfa4d48449f69242Eb8F', // TokenCrowdsale
      'TOKENCROWDSALE': '0x0165878A594ca255338adfa4d48449f69242Eb8F',
      'CROWDSALETOKEN': '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
      'WHITELISTMANAGER': '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
    };
    return localAddresses[contractName.toUpperCase()] || null;
  }
  
  return envAddress;
};

export const getContractABI = (contractName: keyof typeof CONTRACT_ABIS) => {
  return CONTRACT_ABIS[contractName];
};
