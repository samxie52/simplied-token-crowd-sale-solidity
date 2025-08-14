// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/ICrowdsale.sol";
import "./interfaces/IWhitelistManager.sol";
import "./CrowdsaleToken.sol";
import "./utils/CrowdsaleConstants.sol";

/**
 * @title TokenCrowdsale
 * @dev 代币众筹主合约 - 实现多阶段众筹和状态管理
 * @author CrowdsaleTeam
 */
contract TokenCrowdsale is 
    ICrowdsale, 
    Context,
    AccessControl, 
    Pausable, 
    ReentrancyGuard 
{
    using CrowdsaleConstants for uint256;
    using CrowdsaleConstants for address;

    // ============ State Variables ============
    
    /// @dev 当前众筹阶段
    CrowdsalePhase public currentPhase;
    
    /// @dev 众筹配置
    CrowdsaleConfig public config;
    
    /// @dev 众筹统计
    CrowdsaleStats public stats;
    
    /// @dev ERC20代币合约
    CrowdsaleToken public immutable token;
    
    /// @dev 白名单管理合约
    IWhitelistManager public immutable whitelistManager;
    
    /// @dev 资金接收地址
    address payable public fundingWallet;
    
    /// @dev 紧急暂停开始时间
    uint256 public emergencyPauseStartTime;
    
    /// @dev 配置最后更新时间
    uint256 public lastConfigUpdateTime;
    
    /// @dev 参与者映射
    mapping(address => bool) public hasParticipated;
    
    // ============ Modifiers ============
    
    /**
     * @dev 检查当前阶段
     */
    modifier onlyInPhase(CrowdsalePhase _phase) {
        require(currentPhase == _phase, CrowdsaleConstants.ERROR_INVALID_PHASE);
        _;
    }
    
    /**
     * @dev 检查有效的状态转换
     */
    modifier onlyValidTransition(CrowdsalePhase _from, CrowdsalePhase _to) {
        require(currentPhase == _from, CrowdsaleConstants.ERROR_INVALID_STATE_TRANSITION);
        require(_isValidTransition(_from, _to), CrowdsaleConstants.ERROR_INVALID_STATE_TRANSITION);
        _;
    }
    
    /**
     * @dev 检查时间窗口
     */
    modifier withinTimeWindow() {
        require(isInValidTimeWindow(), CrowdsaleConstants.ERROR_TIME_WINDOW_CLOSED);
        _;
    }
    
    /**
     * @dev 检查有效地址
     */
    modifier validAddress(address _addr) {
        require(CrowdsaleConstants.isValidAddress(_addr), CrowdsaleConstants.ERROR_INVALID_ADDRESS);
        _;
    }
    
    /**
     * @dev 检查配置更新冷却时间
     */
    modifier configUpdateCooldown() {
        require(
            block.timestamp >= lastConfigUpdateTime + CrowdsaleConstants.CONFIG_UPDATE_COOLDOWN,
            "TokenCrowdsale: config update cooldown not passed"
        );
        _;
    }
    
    // ============ Constructor ============
    
    /**
     * @dev 构造函数
     * @param _token ERC20代币合约地址
     * @param _whitelistManager 白名单管理合约地址
     * @param _fundingWallet 资金接收钱包地址
     * @param _admin 管理员地址
     */
    constructor(
        address _token,
        address _whitelistManager,
        address payable _fundingWallet,
        address _admin
    ) 
        validAddress(_token)
        validAddress(_whitelistManager)
        validAddress(_fundingWallet)
        validAddress(_admin)
    {
        token = CrowdsaleToken(_token);
        whitelistManager = IWhitelistManager(_whitelistManager);
        fundingWallet = _fundingWallet;
        
        // 设置初始阶段
        currentPhase = CrowdsalePhase.PENDING;
        
        // 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE, _admin);
        _grantRole(CrowdsaleConstants.CROWDSALE_OPERATOR_ROLE, _admin);
        _grantRole(CrowdsaleConstants.EMERGENCY_ROLE, _admin);
        
        // 初始化时间戳
        lastConfigUpdateTime = block.timestamp;
        
        emit PhaseChanged(CrowdsalePhase.PENDING, CrowdsalePhase.PENDING, block.timestamp, _admin);
    }
    
    // ============ View Functions ============
    
    /**
     * @dev 获取当前众筹阶段
     */
    function getCurrentPhase() external view override returns (CrowdsalePhase) {
        return currentPhase;
    }
    
    /**
     * @dev 获取众筹配置
     */
    function getCrowdsaleConfig() external view override returns (CrowdsaleConfig memory) {
        return config;
    }
    
    /**
     * @dev 获取众筹统计信息
     */
    function getCrowdsaleStats() external view override returns (CrowdsaleStats memory) {
        return stats;
    }
    
    /**
     * @dev 检查是否在有效时间窗口内
     */
    function isInValidTimeWindow() public view override returns (bool) {
        uint256 currentTime = block.timestamp;
        
        if (currentPhase == CrowdsalePhase.PRESALE) {
            return currentTime >= config.presaleStartTime && 
                   currentTime <= config.presaleEndTime;
        } else if (currentPhase == CrowdsalePhase.PUBLIC_SALE) {
            return currentTime >= config.publicSaleStartTime && 
                   currentTime <= config.publicSaleEndTime;
        }
        
        return false;
    }
    
    /**
     * @dev 检查软顶是否达成
     */
    function isSoftCapReached() public view override returns (bool) {
        return stats.totalRaised >= config.softCap;
    }
    
    /**
     * @dev 检查硬顶是否达成
     */
    function isHardCapReached() public view override returns (bool) {
        return stats.totalRaised >= config.hardCap;
    }
    
    /**
     * @dev 获取当前筹资进度百分比
     */
    function getFundingProgress() external view override returns (uint256) {
        return CrowdsaleConstants.calculatePercentage(stats.totalRaised, config.hardCap);
    }
    
    /**
     * @dev 获取剩余可筹资金额
     */
    function getRemainingFunding() external view override returns (uint256) {
        if (stats.totalRaised >= config.hardCap) {
            return 0;
        }
        return config.hardCap - stats.totalRaised;
    }
    
    /**
     * @dev 检查地址是否已参与众筹
     */
    function hasUserParticipated(address _user) external view returns (bool) {
        return hasParticipated[_user];
    }
    
    // ============ State Management Functions ============
    
    /**
     * @dev 开始预售阶段
     */
    function startPresale() 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        onlyValidTransition(CrowdsalePhase.PENDING, CrowdsalePhase.PRESALE)
        whenNotPaused
    {
        require(block.timestamp >= config.presaleStartTime, CrowdsaleConstants.ERROR_TIME_WINDOW_NOT_OPEN);
        require(block.timestamp <= config.presaleEndTime, CrowdsaleConstants.ERROR_TIME_WINDOW_CLOSED);
        
        _changePhase(CrowdsalePhase.PRESALE);
    }
    
    /**
     * @dev 开始公售阶段
     */
    function startPublicSale() 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        onlyValidTransition(CrowdsalePhase.PRESALE, CrowdsalePhase.PUBLIC_SALE)
        whenNotPaused
    {
        require(block.timestamp >= config.publicSaleStartTime, CrowdsaleConstants.ERROR_TIME_WINDOW_NOT_OPEN);
        require(block.timestamp <= config.publicSaleEndTime, CrowdsaleConstants.ERROR_TIME_WINDOW_CLOSED);
        
        _changePhase(CrowdsalePhase.PUBLIC_SALE);
    }
    
    /**
     * @dev 结束众筹
     */
    function finalizeCrowdsale() 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        whenNotPaused
    {
        require(
            currentPhase == CrowdsalePhase.PRESALE || 
            currentPhase == CrowdsalePhase.PUBLIC_SALE,
            CrowdsaleConstants.ERROR_INVALID_PHASE
        );
        
        // 检查是否可以结束（时间到期或硬顶达成）
        bool timeExpired = (currentPhase == CrowdsalePhase.PRESALE && block.timestamp > config.presaleEndTime) ||
                          (currentPhase == CrowdsalePhase.PUBLIC_SALE && block.timestamp > config.publicSaleEndTime);
        bool hardCapReached = isHardCapReached();
        
        require(timeExpired || hardCapReached, "TokenCrowdsale: cannot finalize yet");
        
        _changePhase(CrowdsalePhase.FINALIZED);
    }
    
    /**
     * @dev 紧急暂停众筹
     */
    function emergencyPause(string calldata reason) 
        external 
        override 
        onlyRole(CrowdsaleConstants.EMERGENCY_ROLE)
    {
        require(!paused(), CrowdsaleConstants.ERROR_PAUSED);
        
        emergencyPauseStartTime = block.timestamp;
        _pause();
        
        emit EmergencyAction("pause", _msgSender(), block.timestamp, reason);
    }
    
    /**
     * @dev 恢复众筹
     */
    function emergencyResume(string calldata reason) 
        external 
        override 
        onlyRole(CrowdsaleConstants.EMERGENCY_ROLE)
    {
        require(paused(), CrowdsaleConstants.ERROR_NOT_PAUSED);
        require(
            block.timestamp <= emergencyPauseStartTime + CrowdsaleConstants.MAX_EMERGENCY_PAUSE_DURATION,
            "TokenCrowdsale: emergency pause duration exceeded"
        );
        
        emergencyPauseStartTime = 0;
        _unpause();
        
        emit EmergencyAction("resume", _msgSender(), block.timestamp, reason);
    }
    
    // ============ Configuration Functions ============
    
    /**
     * @dev 更新众筹配置
     */
    function updateConfig(CrowdsaleConfig calldata _config) 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        onlyInPhase(CrowdsalePhase.PENDING)
        configUpdateCooldown
        whenNotPaused
    {
        require(_validateConfig(_config), "TokenCrowdsale: invalid config");
        
        config = _config;
        lastConfigUpdateTime = block.timestamp;
        
        emit ConfigUpdated(_config, _msgSender());
    }
    
    /**
     * @dev 更新时间配置
     */
    function updateTimeConfig(
        uint256 _presaleStartTime,
        uint256 _presaleEndTime,
        uint256 _publicSaleStartTime,
        uint256 _publicSaleEndTime
    ) 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        onlyInPhase(CrowdsalePhase.PENDING)
        configUpdateCooldown
        whenNotPaused
    {
        require(
            CrowdsaleConstants.validateTimeSequence(
                _presaleStartTime,
                _presaleEndTime,
                _publicSaleStartTime,
                _publicSaleEndTime
            ),
            CrowdsaleConstants.ERROR_INVALID_TIME_SEQUENCE
        );
        
        config.presaleStartTime = _presaleStartTime;
        config.presaleEndTime = _presaleEndTime;
        config.publicSaleStartTime = _publicSaleStartTime;
        config.publicSaleEndTime = _publicSaleEndTime;
        
        lastConfigUpdateTime = block.timestamp;
        
        emit ConfigUpdated(config, _msgSender());
    }
    
    /**
     * @dev 更新资金目标
     */
    function updateFundingTargets(
        uint256 _softCap,
        uint256 _hardCap
    ) 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        onlyInPhase(CrowdsalePhase.PENDING)
        configUpdateCooldown
        whenNotPaused
    {
        require(
            CrowdsaleConstants.validateFundingTargets(_softCap, _hardCap),
            "TokenCrowdsale: invalid funding targets"
        );
        
        config.softCap = _softCap;
        config.hardCap = _hardCap;
        
        lastConfigUpdateTime = block.timestamp;
        
        emit ConfigUpdated(config, _msgSender());
    }
    
    /**
     * @dev 更新购买限额
     */
    function updatePurchaseLimits(
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) 
        external 
        override 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        configUpdateCooldown
        whenNotPaused
    {
        require(
            CrowdsaleConstants.validatePurchaseLimits(_minPurchase, _maxPurchase),
            "TokenCrowdsale: invalid purchase limits"
        );
        
        config.minPurchase = _minPurchase;
        config.maxPurchase = _maxPurchase;
        
        lastConfigUpdateTime = block.timestamp;
        
        emit ConfigUpdated(config, _msgSender());
    }
    
    /**
     * @dev 更新资金接收钱包
     */
    function updateFundingWallet(address payable _newWallet) 
        external 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        validAddress(_newWallet)
        whenNotPaused
    {
        address oldWallet = fundingWallet;
        fundingWallet = _newWallet;
        
        emit FundingWalletUpdated(oldWallet, _newWallet, _msgSender());
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev 改变众筹阶段
     */
    function _changePhase(CrowdsalePhase _newPhase) internal {
        CrowdsalePhase previousPhase = currentPhase;
        currentPhase = _newPhase;
        
        emit PhaseChanged(previousPhase, _newPhase, block.timestamp, _msgSender());
        
        // 检查目标达成
        if (_newPhase == CrowdsalePhase.PRESALE || _newPhase == CrowdsalePhase.PUBLIC_SALE) {
            if (isSoftCapReached() && previousPhase != CrowdsalePhase.FINALIZED) {
                emit CapReached("soft", config.softCap, block.timestamp);
            }
            if (isHardCapReached()) {
                emit CapReached("hard", config.hardCap, block.timestamp);
            }
        }
    }
    
    /**
     * @dev 验证状态转换是否有效
     */
    function _isValidTransition(CrowdsalePhase _from, CrowdsalePhase _to) internal pure returns (bool) {
        if (_from == CrowdsalePhase.PENDING && _to == CrowdsalePhase.PRESALE) return true;
        if (_from == CrowdsalePhase.PRESALE && _to == CrowdsalePhase.PUBLIC_SALE) return true;
        if (_from == CrowdsalePhase.PRESALE && _to == CrowdsalePhase.FINALIZED) return true;
        if (_from == CrowdsalePhase.PUBLIC_SALE && _to == CrowdsalePhase.FINALIZED) return true;
        return false;
    }
    
    /**
     * @dev 验证众筹配置
     */
    function _validateConfig(CrowdsaleConfig memory _config) internal pure returns (bool) {
        return CrowdsaleConstants.validateTimeSequence(
            _config.presaleStartTime,
            _config.presaleEndTime,
            _config.publicSaleStartTime,
            _config.publicSaleEndTime
        ) && CrowdsaleConstants.validateFundingTargets(
            _config.softCap,
            _config.hardCap
        ) && CrowdsaleConstants.validatePurchaseLimits(
            _config.minPurchase,
            _config.maxPurchase
        );
    }
    
    /**
     * @dev 重写paused函数以解决多重继承冲突
     */
    function paused() public view override(Pausable) returns (bool) {
        return Pausable.paused();
    }
    
    // ============ Additional Events ============
    
    /**
     * @dev 资金钱包更新事件
     */
    event FundingWalletUpdated(
        address indexed oldWallet,
        address indexed newWallet,
        address indexed updatedBy
    );
}
