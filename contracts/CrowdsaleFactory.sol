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
     * @param params 众筹参数结构体，包含代币信息、时间设置、资金目标等
     * @return crowdsaleAddress 创建的众筹合约地址
     * @return tokenAddress 创建的代币合约地址  
     * @return vestingAddress 创建的释放合约地址（如果启用）
     * 
     * 实现步骤：
     * 1. 验证创建费用是否足够
     * 2. 验证众筹参数的有效性
     * 3. 依次部署子合约：代币、释放、白名单、众筹、退款金库
     * 4. 配置各合约间的权限关系
     * 5. 记录众筹实例信息
     * 6. 更新费用统计并发出事件
     * 
     * 权限要求：需要FACTORY_OPERATOR_ROLE或启用公开创建
     * 状态要求：合约未暂停，支付足够的创建费用
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
     * @param paramsArray 众筹参数数组，每个元素包含一个众筹的完整配置
     * @return crowdsaleAddresses 创建的所有众筹合约地址数组
     * 
     * 实现步骤：
     * 1. 计算总费用并验证支付金额
     * 2. 循环调用createCrowdsale创建每个众筹实例
     * 3. 收集所有创建的众筹地址
     * 4. 退还多余的费用给调用者
     * 
     * 权限要求：需要FACTORY_OPERATOR_ROLE或启用公开创建
     * 状态要求：合约未暂停，支付足够的总创建费用
     * Gas优化：使用批量操作减少交易次数
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
    
    /**
     * @dev 部署代币合约
     * @param params 众筹参数，包含代币名称、符号、总供应量等信息
     * @return 部署的代币合约地址
     * 
     * 实现步骤：
     * 1. 使用参数创建新的CrowdsaleToken实例
     * 2. 工厂作为临时管理员进行初始化
     * 3. 铸造全部代币供应量给工厂合约
     * 4. 返回代币合约地址供后续配置使用
     */
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
    
    /**
     * @dev 部署代币释放合约
     * @param tokenAddress 关联的代币合约地址
     * @param params 众筹参数，包含释放配置信息
     * @return 部署的释放合约地址，如果未启用释放则返回零地址
     * 
     * 实现步骤：
     * 1. 检查释放功能是否启用
     * 2. 如果启用，创建新的TokenVesting实例
     * 3. 工厂作为临时管理员进行初始化
     * 4. 返回释放合约地址供后续权限配置
     */
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
    
    /**
     * @dev 部署白名单管理合约
     * @return 部署的白名单合约地址
     * 
     * 实现步骤：
     * 1. 创建新的WhitelistManager实例
     * 2. 工厂作为临时管理员进行初始化
     * 3. 返回白名单合约地址供众筹合约使用
     */
    function _deployWhitelist() internal returns (address) {
        // 直接创建新的白名单合约实例
        WhitelistManager whitelist = new WhitelistManager(address(this));
        
        return address(whitelist);
    }
    
    /**
     * @dev 部署退款金库合约
     * @param beneficiary 资金受益人地址（通常是众筹的资金钱包）
     * @param crowdsale 关联的众筹合约地址
     * @return 部署的退款金库合约地址
     * 
     * 实现步骤：
     * 1. 创建新的RefundVault实例
     * 2. 设置受益人和关联众筹合约
     * 3. 配置多签要求（需要1个签名）
     * 4. 工厂作为临时管理员进行初始化
     */
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
    
    /**
     * @dev 部署众筹主合约
     * @param tokenAddress 关联的代币合约地址
     * @param whitelistAddress 关联的白名单合约地址
     * @param params 众筹参数配置
     * @return 部署的众筹合约地址
     * 
     * 实现步骤：
     * 1. 创建新的TokenCrowdsale实例
     * 2. 传入代币、白名单、资金钱包地址
     * 3. 工厂作为临时管理员进行初始化
     * 4. 返回众筹合约地址供后续权限配置
     */
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
    
    /**
     * @dev 配置各合约间的权限关系
     * @param crowdsaleAddress 众筹合约地址
     * @param tokenAddress 代币合约地址
     * @param vestingAddress 释放合约地址
     * @param whitelistAddress 白名单合约地址
     * @param vaultAddress 退款金库合约地址
     * @param vestingParams 释放参数配置
     * 
     * 实现步骤：
     * 1. 授予众筹合约代币铸造权限
     * 2. 授予众筹合约释放管理权限（如果启用）
     * 3. 授予众筹合约白名单管理权限
     * 4. 配置退款金库操作权限
     * 5. 设置释放合约和配置（如果启用）
     * 6. 将所有管理权限转移给创建者
     * 7. 清理工厂的临时权限
     * 
     * 权限设计：确保各合约间的最小权限原则和安全隔离
     */
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
    
    /**
     * @dev 获取指定众筹实例的详细信息
     * @param crowdsaleAddress 众筹合约地址
     * @return instance 众筹实例信息，包含所有相关合约地址和元数据
     * 
     * 实现步骤：
     * 1. 验证众筹地址的有效性
     * 2. 从映射中获取完整的实例信息
     * 3. 返回包含创建者、时间戳、状态等的结构体
     * 
     * 权限要求：无，公开查询接口
     * 用途：前端展示、合约集成、状态查询
     */
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
    
    /**
     * @dev 验证众筹参数的有效性
     * @param params 待验证的众筹参数结构体
     * @return isValid 参数是否有效
     * @return errorMessage 如果无效，返回具体的错误信息
     * 
     * 验证规则：
     * 1. 代币名称和符号不能为空
     * 2. 总供应量必须大于0
     * 3. 软顶必须大于0，硬顶必须大于软顶
     * 4. 开始时间必须在未来，结束时间必须晚于开始时间
     * 5. 资金钱包地址不能为零地址
     * 6. 代币价格必须大于0
     * 7. 如果启用释放，验证释放参数的合理性
     * 
     * 用途：创建众筹前的参数校验，确保配置合理性
     */
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
    
    /**
     * @dev 更新众筹实例的活跃状态
     * @param crowdsaleAddress 众筹合约地址
     * @param isActive 新的活跃状态
     * 
     * 实现步骤：
     * 1. 验证调用者具有工厂管理员权限
     * 2. 验证众筹地址的有效性
     * 3. 更新实例状态并发出事件
     * 
     * 权限要求：FACTORY_ADMIN_ROLE
     * 用途：管理员控制众筹的可见性和活跃状态
     */
    function updateCrowdsaleStatus(address crowdsaleAddress, bool isActive) 
        external 
        override
        onlyRole(FACTORY_ADMIN_ROLE)
        validCrowdsale(crowdsaleAddress)
    {
        crowdsaleInstances[crowdsaleAddress].isActive = isActive;
        emit CrowdsaleStatusUpdated(crowdsaleAddress, isActive);
    }
    
    /**
     * @dev 设置众筹创建费用
     * @param fee 新的创建费用（以wei为单位）
     * 
     * 实现步骤：
     * 1. 验证调用者具有工厂管理员权限
     * 2. 更新创建费用状态变量
     * 3. 发出配置更新事件
     * 
     * 权限要求：FACTORY_ADMIN_ROLE
     * 用途：动态调整众筹创建的成本
     */
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
     * @param crowdsaleAddress 需要停止的众筹合约地址
     * 
     * 实现步骤：
     * 1. 验证调用者具有工厂管理员权限
     * 2. 验证众筹地址的有效性
     * 3. 调用众筹合约的紧急暂停功能
     * 4. 更新实例状态为非活跃
     * 5. 发出状态更新事件
     * 
     * 权限要求：FACTORY_ADMIN_ROLE
     * 用途：在发现安全问题或异常情况时快速停止众筹
     * 安全考虑：只能由工厂管理员执行，确保紧急响应能力
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
     * @dev 获取合约模板地址（已废弃功能）
     * @return crowdsale 众筹模板地址（已设为零地址）
     * @return token 代币模板地址（已设为零地址）
     * @return vesting 释放模板地址（已设为零地址）
     * @return whitelist 白名单模板地址（已设为零地址）
     * @return vault 退款金库模板地址（已设为零地址）
     * 
     * 实现说明：
     * 1. 此功能已废弃，不再使用模板克隆模式
     * 2. 现在直接创建新合约实例以避免复杂性
     * 3. 保留接口用于向后兼容
     * 
     * 用途：接口兼容性，所有地址均返回零地址
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
