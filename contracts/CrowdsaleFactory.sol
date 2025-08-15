// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/ICrowdsaleFactory.sol";
import "./TokenCrowdsale.sol";
import "./CrowdsaleToken.sol";
import "./TokenVesting.sol";
import "./WhitelistManager.sol";
import "./RefundVault.sol";

/**
 * @title CrowdsaleFactory
 * @dev 众筹工厂合约 - 用于批量部署和管理众筹实例
 * @author CrowdsaleTeam
 */
contract CrowdsaleFactory is ICrowdsaleFactory, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ 角色定义 ============
    
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");
    bytes32 public constant FACTORY_OPERATOR_ROLE = keccak256("FACTORY_OPERATOR_ROLE");
    
    // ============ 状态变量 ============
    
    /// @dev 众筹实例映射
    mapping(address => CrowdsaleInstance) public crowdsaleInstances;
    
    /// @dev 创建者众筹映射
    mapping(address => address[]) public creatorCrowdsales;
    
    /// @dev 所有众筹地址数组
    address[] public allCrowdsales;
    
    /// @dev 活跃众筹地址数组
    address[] public activeCrowdsales;
    
    /// @dev 创建费用
    uint256 public creationFee;
    
    /// @dev 是否允许公开创建
    bool public publicCreationAllowed;
    
    /// @dev 总收取费用
    uint256 public totalFeesCollected;
    
    /// @dev 合约模板地址 (已废弃，保留用于接口兼容)
    address public immutable crowdsaleTemplate;
    address public immutable tokenTemplate;
    address public immutable vestingTemplate;
    address public immutable whitelistTemplate;
    address public immutable vaultTemplate;
    
    // ============ 修饰符 ============
    
    modifier onlyCreator() {
        require(
            publicCreationAllowed || hasRole(FACTORY_OPERATOR_ROLE, _msgSender()),
            "CrowdsaleFactory: not authorized to create"
        );
        _;
    }
    
    modifier validCrowdsale(address crowdsaleAddress) {
        require(
            crowdsaleInstances[crowdsaleAddress].crowdsaleAddress != address(0),
            "CrowdsaleFactory: crowdsale not found"
        );
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor(
        uint256 _creationFee,
        bool _publicCreationAllowed
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FACTORY_ADMIN_ROLE, _msgSender());
        _grantRole(FACTORY_OPERATOR_ROLE, _msgSender());
        
        creationFee = _creationFee;
        publicCreationAllowed = _publicCreationAllowed;
        
        // 不再使用模板合约，直接设置为零地址
        crowdsaleTemplate = address(0);
        tokenTemplate = address(0);
        vestingTemplate = address(0);
        whitelistTemplate = address(0);
        vaultTemplate = address(0);
    }
    
    // ============ 核心功能 ============
    
    /**
     * @dev 创建新的众筹实例
     */
    function createCrowdsale(CrowdsaleParams calldata params) 
        external 
        payable 
        override
        nonReentrant
        whenNotPaused
        onlyCreator
        returns (
            address crowdsaleAddress,
            address tokenAddress,
            address vestingAddress
        )
    {
        require(msg.value >= creationFee, "CrowdsaleFactory: insufficient fee");
        
        // 验证参数
        (bool isValid, string memory errorMessage) = validateCrowdsaleParams(params);
        require(isValid, errorMessage);
        
        // 部署子合约
        tokenAddress = _deployToken(params);
        vestingAddress = _deployVesting(tokenAddress, params);
        address whitelistAddress = _deployWhitelist();
        
        // 先部署主众筹合约
        crowdsaleAddress = _deployCrowdsale(
            tokenAddress,
            whitelistAddress,
            address(0), // vault地址稍后设置
            params
        );
        
        // 然后部署vault，使用正确的crowdsale地址
        address vaultAddress = _deployVault(params.fundingWallet, crowdsaleAddress);
        
        // 配置权限
        _setupPermissions(
            crowdsaleAddress,
            tokenAddress,
            vestingAddress,
            whitelistAddress,
            vaultAddress,
            params.vestingParams
        );
        
        // 记录实例
        _recordCrowdsaleInstance(crowdsaleAddress, tokenAddress, vestingAddress);
        
        // 更新费用统计
        totalFeesCollected += msg.value;
        
        emit CrowdsaleCreated(
            _msgSender(),
            crowdsaleAddress,
            tokenAddress,
            vestingAddress,
            params.tokenName,
            params.tokenSymbol
        );
    }
    
    /**
     * @dev 批量创建众筹实例
     */
    function batchCreateCrowdsale(CrowdsaleParams[] calldata paramsArray)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        onlyCreator
        returns (address[] memory crowdsaleAddresses)
    {
        uint256 totalFee = creationFee * paramsArray.length;
        require(msg.value >= totalFee, "CrowdsaleFactory: insufficient fee");
        
        crowdsaleAddresses = new address[](paramsArray.length);
        
        for (uint256 i = 0; i < paramsArray.length; i++) {
            (address crowdsaleAddr,,) = this.createCrowdsale{value: creationFee}(paramsArray[i]);
            crowdsaleAddresses[i] = crowdsaleAddr;
        }
        
        // 退还多余费用
        if (msg.value > totalFee) {
            payable(_msgSender()).transfer(msg.value - totalFee);
        }
    }
    
    // ============ 内部部署函数 ============
    
    function _deployToken(CrowdsaleParams memory params) internal returns (address) {
        CrowdsaleToken token = new CrowdsaleToken(
            params.tokenName,
            params.tokenSymbol,
            params.totalSupply,
            address(this) // 工厂作为临时管理员
        );
        
        // 铸造全部代币供应量给工厂合约，用于后续分配
        token.mint(address(this), params.totalSupply);
        
        return address(token);
    }
    
    function _deployVesting(address tokenAddress, CrowdsaleParams calldata params) 
        internal 
        returns (address) 
    {
        if (!params.vestingParams.enabled) {
            return address(0);
        }
        
        // 直接创建新的释放合约实例
        TokenVesting vesting = new TokenVesting(
            tokenAddress,
            address(this) // 工厂作为临时管理员
        );
        
        return address(vesting);
    }
    
    function _deployWhitelist() internal returns (address) {
        // 直接创建新的白名单合约实例
        WhitelistManager whitelist = new WhitelistManager(address(this));
        
        return address(whitelist);
    }
    
    function _deployVault(address beneficiary, address crowdsale) internal returns (address) {
        // 直接创建新的退款金库合约实例
        RefundVault vault = new RefundVault(
            beneficiary,
            crowdsale,
            1, // 需要1个签名
            address(this) // 工厂作为临时管理员
        );
        
        return address(vault);
    }
    
    function _deployCrowdsale(
        address tokenAddress,
        address whitelistAddress,
        address /* vaultAddress */,
        CrowdsaleParams calldata params
    ) internal returns (address) {
        // 直接创建新的众筹合约实例
        TokenCrowdsale crowdsale = new TokenCrowdsale(
            tokenAddress,
            whitelistAddress,
            payable(params.fundingWallet),
            address(this) // 工厂作为临时管理员
        );
        
        return address(crowdsale);
    }
    
    function _setupPermissions(
        address crowdsaleAddress,
        address tokenAddress,
        address vestingAddress,
        address whitelistAddress,
        address vaultAddress,
        VestingParams memory vestingParams
    ) internal {
        // 工厂已经在部署时获得了所有合约的admin权限，现在设置各合约之间的权限关系
        
        // 设置各合约之间的权限关系
        CrowdsaleToken(tokenAddress).grantRole(
            CrowdsaleToken(tokenAddress).MINTER_ROLE(),
            crowdsaleAddress
        );
        
        if (vestingAddress != address(0)) {
            TokenVesting(vestingAddress).grantRole(
                TokenVesting(vestingAddress).VESTING_ADMIN_ROLE(),
                crowdsaleAddress
            );
        }
        
        WhitelistManager(whitelistAddress).grantRole(
            WhitelistManager(whitelistAddress).WHITELIST_ADMIN_ROLE(),
            crowdsaleAddress
        );
        
        // 临时给工厂CROWDSALE_ADMIN_ROLE来调用setRefundVault
        TokenCrowdsale(crowdsaleAddress).grantRole(
            CrowdsaleConstants.CROWDSALE_ADMIN_ROLE,
            address(this)
        );
        
        // 给TokenCrowdsale授予RefundVault的OPERATOR权限，用于调用release()和enableRefunds()
        RefundVault(payable(vaultAddress)).grantRole(
            RefundVault(payable(vaultAddress)).VAULT_OPERATOR_ROLE(),
            crowdsaleAddress
        );
        
        // 设置RefundVault
        TokenCrowdsale(crowdsaleAddress).setRefundVault(vaultAddress);
        
        // 设置归属合约和配置（如果启用）
        if (vestingAddress != address(0)) {
            TokenCrowdsale(crowdsaleAddress).setVestingContract(vestingAddress);
            
            // 设置归属配置
            TokenCrowdsale(crowdsaleAddress).setVestingConfig(
                vestingParams.enabled,
                vestingParams.cliffDuration,
                vestingParams.vestingDuration,
                vestingParams.vestingType,
                vestingParams.immediateReleasePercentage
            );
        }
        
        // 撤销工厂的CROWDSALE_ADMIN_ROLE
        TokenCrowdsale(crowdsaleAddress).revokeRole(
            CrowdsaleConstants.CROWDSALE_ADMIN_ROLE,
            address(this)
        );
        
        // 给创建者授予CROWDSALE_ADMIN_ROLE权限
        TokenCrowdsale(crowdsaleAddress).grantRole(
            CrowdsaleConstants.CROWDSALE_ADMIN_ROLE,
            _msgSender()
        );
        
        // 将代币转移给众筹合约，用于后续购买转移
        // 获取代币总供应量并转移给众筹合约
        uint256 tokenBalance = CrowdsaleToken(tokenAddress).balanceOf(address(this));
        if (tokenBalance > 0) {
            CrowdsaleToken(tokenAddress).transfer(crowdsaleAddress, tokenBalance);
        }
        
        // 最后转移所有权给创建者
        address creator = _msgSender();
        
        // 先给创建者授予所有合约的admin权限
        CrowdsaleToken(tokenAddress).grantRole(
            CrowdsaleToken(tokenAddress).DEFAULT_ADMIN_ROLE(),
            creator
        );
        
        if (vestingAddress != address(0)) {
            TokenVesting(vestingAddress).grantRole(
                TokenVesting(vestingAddress).DEFAULT_ADMIN_ROLE(),
                creator
            );
        }
        
        WhitelistManager(whitelistAddress).grantRole(
            WhitelistManager(whitelistAddress).DEFAULT_ADMIN_ROLE(),
            creator
        );
        
        RefundVault(payable(vaultAddress)).grantRole(
            RefundVault(payable(vaultAddress)).DEFAULT_ADMIN_ROLE(),
            creator
        );
        
        TokenCrowdsale(crowdsaleAddress).grantRole(
            TokenCrowdsale(crowdsaleAddress).DEFAULT_ADMIN_ROLE(),
            creator
        );
        
        // 最后统一清理工厂的所有权限
        CrowdsaleToken(tokenAddress).revokeRole(
            CrowdsaleToken(tokenAddress).DEFAULT_ADMIN_ROLE(),
            address(this)
        );
        
        if (vestingAddress != address(0)) {
            TokenVesting(vestingAddress).revokeRole(
                TokenVesting(vestingAddress).DEFAULT_ADMIN_ROLE(),
                address(this)
            );
        }
        
        WhitelistManager(whitelistAddress).revokeRole(
            WhitelistManager(whitelistAddress).DEFAULT_ADMIN_ROLE(),
            address(this)
        );
        
        RefundVault(payable(vaultAddress)).revokeRole(
            RefundVault(payable(vaultAddress)).DEFAULT_ADMIN_ROLE(),
            address(this)
        );
        
        TokenCrowdsale(crowdsaleAddress).revokeRole(
            TokenCrowdsale(crowdsaleAddress).DEFAULT_ADMIN_ROLE(),
            address(this)
        );
    }
    
    function _recordCrowdsaleInstance(
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
        activeCrowdsales.push(crowdsaleAddress);
    }
    
    // ============ 查询功能 ============
    
    function getCrowdsaleInstance(address crowdsaleAddress) 
        external 
        view 
        override
        validCrowdsale(crowdsaleAddress)
        returns (CrowdsaleInstance memory instance) 
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
        
        // 计算活跃众筹数量
        for (uint256 i = 0; i < allCrowdsales.length; i++) {
            if (crowdsaleInstances[allCrowdsales[i]].isActive) {
                activeCount++;
            }
        }
        
        instances = new CrowdsaleInstance[](activeCount);
        uint256 index = 0;
        
        // 填充活跃众筹
        for (uint256 i = 0; i < allCrowdsales.length; i++) {
            if (crowdsaleInstances[allCrowdsales[i]].isActive) {
                instances[index] = crowdsaleInstances[allCrowdsales[i]];
                index++;
            }
        }
    }
    
    function getTotalCrowdsales() external view override returns (uint256 count) {
        return allCrowdsales.length;
    }
    
    function validateCrowdsaleParams(CrowdsaleParams calldata params) 
        public 
        view 
        override
        returns (bool isValid, string memory errorMessage) 
    {
        if (bytes(params.tokenName).length == 0) {
            return (false, "Empty token name");
        }
        
        if (bytes(params.tokenSymbol).length == 0) {
            return (false, "Empty token symbol");
        }
        
        if (params.totalSupply == 0) {
            return (false, "Zero total supply");
        }
        
        if (params.softCap == 0) {
            return (false, "Zero soft cap");
        }
        
        if (params.hardCap <= params.softCap) {
            return (false, "Hard cap must be greater than soft cap");
        }
        
        if (params.startTime <= block.timestamp) {
            return (false, "Start time must be in future");
        }
        
        if (params.endTime <= params.startTime) {
            return (false, "End time must be after start time");
        }
        
        if (params.fundingWallet == address(0)) {
            return (false, "Zero funding wallet");
        }
        
        if (params.tokenPrice == 0) {
            return (false, "Zero token price");
        }
        
        // 验证释放参数
        if (params.vestingParams.enabled) {
            if (params.vestingParams.vestingDuration == 0) {
                return (false, "Zero vesting duration");
            }
            
            if (params.vestingParams.immediateReleasePercentage > 10000) {
                return (false, "Immediate release percentage too high");
            }
        }
        
        return (true, "");
    }
    
    // ============ 管理功能 ============
    
    function updateCrowdsaleStatus(address crowdsaleAddress, bool isActive) 
        external 
        override
        onlyRole(FACTORY_ADMIN_ROLE)
        validCrowdsale(crowdsaleAddress)
    {
        crowdsaleInstances[crowdsaleAddress].isActive = isActive;
        emit CrowdsaleStatusUpdated(crowdsaleAddress, isActive);
    }
    
    function setCreationFee(uint256 fee) 
        external 
        override
        onlyRole(FACTORY_ADMIN_ROLE) 
    {
        creationFee = fee;
        emit FactoryConfigUpdated(_msgSender(), fee, publicCreationAllowed);
    }
    
    function setPublicCreationAllowed(bool allowed) 
        external 
        override
        onlyRole(FACTORY_ADMIN_ROLE) 
    {
        publicCreationAllowed = allowed;
        emit FactoryConfigUpdated(_msgSender(), creationFee, allowed);
    }
    
    function withdrawFees(address payable to, uint256 amount) 
        external 
        override
        onlyRole(FACTORY_ADMIN_ROLE) 
    {
        require(to != address(0), "CrowdsaleFactory: zero address");
        require(amount <= address(this).balance, "CrowdsaleFactory: insufficient balance");
        
        to.transfer(amount);
    }
    
    function pause() external onlyRole(FACTORY_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(FACTORY_ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ 配置查询 ============
    
    function getCreationFee() external view override returns (uint256 fee) {
        return creationFee;
    }
    
    function isPublicCreationAllowed() external view override returns (bool allowed) {
        return publicCreationAllowed;
    }
    
    function getFactoryStats() 
        external 
        view 
        override
        returns (
            uint256 totalCrowdsales,
            uint256 activeCrowdsalesCount,
            uint256 totalFeesCollectedAmount
        ) 
    {
        totalCrowdsales = allCrowdsales.length;
        totalFeesCollectedAmount = totalFeesCollected;
        
        // 计算活跃众筹数量
        for (uint256 i = 0; i < allCrowdsales.length; i++) {
            if (crowdsaleInstances[allCrowdsales[i]].isActive) {
                activeCrowdsalesCount++;
            }
        }
    }
    
    // ============ 紧急功能 ============
    
    /**
     * @dev 紧急停止特定众筹
     */
    function emergencyStopCrowdsale(address crowdsaleAddress) 
        external 
        onlyRole(FACTORY_ADMIN_ROLE)
        validCrowdsale(crowdsaleAddress)
    {
        // TokenCrowdsale使用emergencyPause而不是pause
        TokenCrowdsale(crowdsaleAddress).emergencyPause("Factory emergency pause");
        crowdsaleInstances[crowdsaleAddress].isActive = false;
        emit CrowdsaleStatusUpdated(crowdsaleAddress, false);
    }
    
    /**
     * @dev 获取合约模板地址
     */
    function getTemplateAddresses() 
        external 
        view 
        returns (
            address crowdsale,
            address token,
            address vesting,
            address whitelist,
            address vault
        ) 
    {
        return (
            crowdsaleTemplate,
            tokenTemplate,
            vestingTemplate,
            whitelistTemplate,
            vaultTemplate
        );
    }
    
    // ============ 接收ETH ============
    
    receive() external payable {
        // 接收ETH用于支付创建费用
    }
}
