// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICrowdsaleFactory.sol";
import "./TokenCrowdsale.sol";
import "./CrowdsaleToken.sol";
import "./TokenVesting.sol";
import "./WhitelistManager.sol";
import "./RefundVault.sol";

/**
 * @title CrowdsaleFactoryLite
 * @dev 精简版众筹工厂合约 - 解决合约大小限制问题
 */
contract CrowdsaleFactoryLite is ICrowdsaleFactory, AccessControl, ReentrancyGuard {
    
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");
    bytes32 public constant FACTORY_OPERATOR_ROLE = keccak256("FACTORY_OPERATOR_ROLE");
    
    mapping(address => CrowdsaleInstance) public crowdsaleInstances;
    mapping(address => address[]) public creatorCrowdsales;
    address[] public allCrowdsales;
    
    uint256 public creationFee;
    bool public publicCreationAllowed;
    uint256 public totalFeesCollected;
    
    event CrowdsaleCreated(
        address indexed crowdsaleAddress,
        address indexed tokenAddress,
        address indexed creator,
        string tokenName,
        string tokenSymbol
    );
    
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event PublicCreationToggled(bool allowed);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    
    modifier validCrowdsale(address crowdsaleAddress) {
        require(crowdsaleInstances[crowdsaleAddress].crowdsaleAddress != address(0), "Invalid crowdsale");
        _;
    }
    
    modifier onlyCreatorOrAdmin(address crowdsaleAddress) {
        require(
            crowdsaleInstances[crowdsaleAddress].creator == _msgSender() ||
            hasRole(FACTORY_ADMIN_ROLE, _msgSender()),
            "Not creator or admin"
        );
        _;
    }
    
    constructor(uint256 _creationFee, bool _publicCreationAllowed) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FACTORY_ADMIN_ROLE, _msgSender());
        _grantRole(FACTORY_OPERATOR_ROLE, _msgSender());
        
        creationFee = _creationFee;
        publicCreationAllowed = _publicCreationAllowed;
    }
    
    function createCrowdsale(CrowdsaleParams calldata params) 
        external 
        payable 
        override
        nonReentrant
        returns (address crowdsaleAddress, address tokenAddress, address vestingAddress) 
    {
        require(
            publicCreationAllowed || hasRole(FACTORY_OPERATOR_ROLE, _msgSender()),
            "Creation not allowed"
        );
        require(msg.value >= creationFee, "Insufficient creation fee");
        
        // 部署代币合约
        tokenAddress = _deployToken(params);
        
        // 部署释放合约（如果需要）
        if (params.vestingParams.enabled) {
            vestingAddress = _deployVesting(tokenAddress);
        }
        
        // 部署众筹合约
        crowdsaleAddress = _deployCrowdsale(params, tokenAddress, vestingAddress);
        
        // 记录实例
        _recordInstance(crowdsaleAddress, tokenAddress, vestingAddress);
        
        // 收取费用
        totalFeesCollected += msg.value;
        
        emit CrowdsaleCreated(crowdsaleAddress, tokenAddress, _msgSender(), params.tokenName, params.tokenSymbol);
    }
    
    function _deployToken(CrowdsaleParams calldata params) internal returns (address) {
        CrowdsaleToken token = new CrowdsaleToken(
            params.tokenName,
            params.tokenSymbol,
            params.totalSupply,
            _msgSender()
        );
        return address(token);
    }
    
    function _deployVesting(address tokenAddress) internal returns (address) {
        TokenVesting vesting = new TokenVesting(tokenAddress, _msgSender());
        return address(vesting);
    }
    
    function _deployCrowdsale(
        CrowdsaleParams calldata params,
        address tokenAddress,
        address vestingAddress
    ) internal returns (address) {
        // 部署白名单管理器
        WhitelistManager whitelist = new WhitelistManager(_msgSender());
        
        TokenCrowdsale crowdsale = new TokenCrowdsale(
            tokenAddress,
            address(whitelist),
            payable(params.fundingWallet),
            _msgSender()
        );
        
        // 设置释放合约（如果有）
        if (vestingAddress != address(0)) {
            crowdsale.setVestingContract(vestingAddress);
            crowdsale.setVestingConfig(
                params.vestingParams.enabled,
                params.vestingParams.cliffDuration,
                params.vestingParams.vestingDuration,
                params.vestingParams.vestingType,
                params.vestingParams.immediateReleasePercentage
            );
        }
        
        return address(crowdsale);
    }
    
    function _recordInstance(
        address crowdsaleAddress,
        address tokenAddress,
        address vestingAddress
    ) internal {
        CrowdsaleInstance memory instance = CrowdsaleInstance({
            crowdsaleAddress: crowdsaleAddress,
            tokenAddress: tokenAddress,
            vestingAddress: vestingAddress,
            creator: _msgSender(),
            createdAt: block.timestamp,
            isActive: true
        });
        
        crowdsaleInstances[crowdsaleAddress] = instance;
        creatorCrowdsales[_msgSender()].push(crowdsaleAddress);
        allCrowdsales.push(crowdsaleAddress);
    }
    
    // 查询功能
    function getCrowdsaleInstance(address crowdsaleAddress) 
        external 
        view 
        override
        validCrowdsale(crowdsaleAddress)
        returns (CrowdsaleInstance memory) 
    {
        return crowdsaleInstances[crowdsaleAddress];
    }
    
    function getCreatorCrowdsales(address creator) 
        external 
        view 
        override
        returns (CrowdsaleInstance[] memory instances) 
    {
        address[] memory addresses = creatorCrowdsales[creator];
        instances = new CrowdsaleInstance[](addresses.length);
        
        for (uint256 i = 0; i < addresses.length; i++) {
            instances[i] = crowdsaleInstances[addresses[i]];
        }
    }
    
    function getActiveCrowdsales() 
        external 
        view 
        override
        returns (CrowdsaleInstance[] memory instances) 
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allCrowdsales.length; i++) {
            if (crowdsaleInstances[allCrowdsales[i]].isActive) {
                activeCount++;
            }
        }
        
        instances = new CrowdsaleInstance[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allCrowdsales.length; i++) {
            if (crowdsaleInstances[allCrowdsales[i]].isActive) {
                instances[index] = crowdsaleInstances[allCrowdsales[i]];
                index++;
            }
        }
    }
    
    function getTotalCrowdsales() external view override returns (uint256) {
        return allCrowdsales.length;
    }
    
    function validateCrowdsaleParams(CrowdsaleParams calldata params) 
        public 
        view 
        override
        returns (bool isValid, string memory errorMessage) 
    {
        if (bytes(params.tokenName).length == 0) return (false, "Empty token name");
        if (bytes(params.tokenSymbol).length == 0) return (false, "Empty token symbol");
        if (params.totalSupply == 0) return (false, "Zero total supply");
        if (params.softCap == 0) return (false, "Zero soft cap");
        if (params.hardCap <= params.softCap) return (false, "Hard cap must be greater than soft cap");
        if (params.startTime <= block.timestamp) return (false, "Start time must be in future");
        if (params.endTime <= params.startTime) return (false, "End time must be after start time");
        
        return (true, "");
    }
    
    // 管理功能
    function setCreationFee(uint256 _creationFee) external onlyRole(FACTORY_ADMIN_ROLE) {
        uint256 oldFee = creationFee;
        creationFee = _creationFee;
        emit CreationFeeUpdated(oldFee, _creationFee);
    }
    
    function togglePublicCreation() external onlyRole(FACTORY_ADMIN_ROLE) {
        publicCreationAllowed = !publicCreationAllowed;
        emit PublicCreationToggled(publicCreationAllowed);
    }
    
    function withdrawFees(address payable recipient) external onlyRole(FACTORY_ADMIN_ROLE) {
        uint256 amount = address(this).balance;
        require(amount > 0, "No fees to withdraw");
        
        recipient.transfer(amount);
        emit FeesWithdrawn(recipient, amount);
    }
    
    function deactivateCrowdsale(address crowdsaleAddress) 
        external 
        validCrowdsale(crowdsaleAddress)
        onlyCreatorOrAdmin(crowdsaleAddress) 
    {
        crowdsaleInstances[crowdsaleAddress].isActive = false;
    }
    
    // 实现缺失的接口函数
    function batchCreateCrowdsale(CrowdsaleParams[] calldata paramsArray)
        external
        payable
        returns (address[] memory crowdsaleAddresses)
    {
        require(paramsArray.length > 0, "Empty params array");
        require(msg.value >= creationFee * paramsArray.length, "Insufficient creation fee");
        
        crowdsaleAddresses = new address[](paramsArray.length);
        
        for (uint256 i = 0; i < paramsArray.length; i++) {
            // 简化批量创建，直接调用内部函数
            address tokenAddress = _deployToken(paramsArray[i]);
            address vestingAddress;
            if (paramsArray[i].vestingParams.enabled) {
                vestingAddress = _deployVesting(tokenAddress);
            }
            address crowdsaleAddress = _deployCrowdsale(paramsArray[i], tokenAddress, vestingAddress);
            _recordInstance(crowdsaleAddress, tokenAddress, vestingAddress);
            
            crowdsaleAddresses[i] = crowdsaleAddress;
            emit CrowdsaleCreated(crowdsaleAddress, tokenAddress, _msgSender(), paramsArray[i].tokenName, paramsArray[i].tokenSymbol);
        }
        
        totalFeesCollected += msg.value;
        return crowdsaleAddresses;
    }
    
    function updateCrowdsaleStatus(address crowdsaleAddress, bool isActive) external {
        require(
            crowdsaleInstances[crowdsaleAddress].creator == _msgSender() ||
            hasRole(FACTORY_ADMIN_ROLE, _msgSender()),
            "Not authorized"
        );
        crowdsaleInstances[crowdsaleAddress].isActive = isActive;
    }
    
    function setPublicCreationAllowed(bool allowed) external onlyRole(FACTORY_ADMIN_ROLE) {
        publicCreationAllowed = allowed;
        emit PublicCreationToggled(allowed);
    }
    
    function withdrawFees(address payable to, uint256 amount) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(amount <= address(this).balance, "Insufficient balance");
        to.transfer(amount);
        emit FeesWithdrawn(to, amount);
    }
    
    function getCreationFee() external view returns (uint256) {
        return creationFee;
    }
    
    function isPublicCreationAllowed() external view returns (bool) {
        return publicCreationAllowed;
    }
    
    function getFactoryStats() external view returns (
        uint256 totalCrowdsales,
        uint256 activeCrowdsales,
        uint256 totalFeesCollected
    ) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allCrowdsales.length; i++) {
            if (crowdsaleInstances[allCrowdsales[i]].isActive) {
                activeCount++;
            }
        }
        
        return (allCrowdsales.length, activeCount, totalFeesCollected);
    }
}
