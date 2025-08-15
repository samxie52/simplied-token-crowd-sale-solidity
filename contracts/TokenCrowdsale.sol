// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/ICrowdsale.sol";
import "./interfaces/IWhitelistManager.sol";
import "./interfaces/IPricingStrategy.sol";
import "./interfaces/IRefundVault.sol";
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
    
    /// @dev 定价策略合约
    IPricingStrategy public pricingStrategy;
    
    /// @dev 资金托管合约
    IRefundVault public refundVault;
    
    /// @dev 用户购买记录
    mapping(address => PurchaseRecord[]) public purchaseHistory;
    
    /// @dev 用户总购买金额
    mapping(address => uint256) public totalPurchased;
    
    /// @dev 用户最后购买时间
    mapping(address => uint256) public lastPurchaseTime;
    
    /// @dev 购买冷却时间 (5分钟)
    uint256 public constant PURCHASE_COOLDOWN = 5 minutes;
    
    // ============ Structs ============
    
    /**
     * @dev 购买记录结构
     */
    struct PurchaseRecord {
        uint256 weiAmount;        // ETH金额
        uint256 tokenAmount;      // 代币数量
        uint256 price;            // 购买时价格
        uint256 timestamp;        // 购买时间
        IPricingStrategy.PricingType pricingType; // 定价类型
        bool isWhitelistPurchase; // 是否白名单购买
    }
    
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
    
    /**
     * @dev 检查购买冷却时间
     */
    modifier purchaseCooldown(address buyer) {
        require(
            block.timestamp >= lastPurchaseTime[buyer] + PURCHASE_COOLDOWN,
            "TokenCrowdsale: purchase cooldown not passed"
        );
        _;
    }
    
    /**
     * @dev 检查购买金额限制
     */
    modifier validPurchaseAmount(uint256 weiAmount) {
        require(weiAmount >= config.minPurchase, "TokenCrowdsale: below minimum purchase");
        require(weiAmount <= config.maxPurchase, "TokenCrowdsale: exceeds maximum purchase");
        _;
    }
    
    /**
     * @dev 检查众筹是否活跃
     */
    modifier onlyActiveSale() {
        require(
            currentPhase == CrowdsalePhase.PRESALE || currentPhase == CrowdsalePhase.PUBLIC_SALE,
            "TokenCrowdsale: sale not active"
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
        
        emit CrowdsaleInitialized(_admin, block.timestamp);
    }
    
    // ============ Purchase Functions ============
    
    /**
     * @dev 购买代币 - 核心购买功能
     */
    function purchaseTokens() 
        external 
        payable 
        nonReentrant
        whenNotPaused
        onlyActiveSale
        withinTimeWindow
        validPurchaseAmount(msg.value)
        purchaseCooldown(msg.sender)
    {
        address buyer = msg.sender;
        uint256 weiAmount = msg.value;
        
        // 检查硬顶限制
        require(stats.totalRaised + weiAmount <= config.hardCap, "TokenCrowdsale: exceeds hard cap");
        
        // 检查白名单权限（预售阶段）
        if (currentPhase == CrowdsalePhase.PRESALE) {
            require(whitelistManager.isWhitelisted(buyer), "TokenCrowdsale: not whitelisted for presale");
        }
        
        // 检查定价策略是否设置
        require(address(pricingStrategy) != address(0), "TokenCrowdsale: pricing strategy not set");
        
        // 验证购买有效性
        require(pricingStrategy.isValidPurchase(buyer, weiAmount), "TokenCrowdsale: invalid purchase");
        
        // 计算代币数量
        uint256 tokenAmount = pricingStrategy.calculateTokenAmount(weiAmount, buyer);
        require(tokenAmount > 0, "TokenCrowdsale: invalid token amount");
        
        // 执行购买
        _processPurchase(buyer, weiAmount, tokenAmount);
        
        // 转移资金到托管合约
        if (address(refundVault) != address(0)) {
            refundVault.deposit{value: weiAmount}(buyer);
        } else {
            // 如果没有设置托管合约，直接转移到资金钱包
            fundingWallet.transfer(weiAmount);
        }
        
        emit TokensPurchased(buyer, weiAmount, tokenAmount, block.timestamp);
    }
    
    /**
     * @dev 批量购买（为多个地址购买代币）- 仅管理员
     */
    function batchPurchase(
        address[] calldata buyers,
        uint256[] calldata weiAmounts
    ) 
        external 
        payable 
        nonReentrant
        onlyRole(CrowdsaleConstants.CROWDSALE_OPERATOR_ROLE)
        whenNotPaused
        onlyActiveSale
    {
        require(buyers.length == weiAmounts.length, "TokenCrowdsale: arrays length mismatch");
        require(buyers.length <= 50, "TokenCrowdsale: too many buyers");
        
        uint256 totalWeiNeeded = 0;
        for (uint256 i = 0; i < weiAmounts.length; i++) {
            totalWeiNeeded += weiAmounts[i];
        }
        require(msg.value >= totalWeiNeeded, "TokenCrowdsale: insufficient payment");
        
        for (uint256 i = 0; i < buyers.length; i++) {
            address buyer = buyers[i];
            uint256 weiAmount = weiAmounts[i];
            
            if (weiAmount == 0 || buyer == address(0)) continue;
            
            // 检查购买限制
            if (weiAmount < config.minPurchase || weiAmount > config.maxPurchase) continue;
            
            // 检查硬顶
            if (stats.totalRaised + weiAmount > config.hardCap) break;
            
            // 预售阶段检查白名单
            if (currentPhase == CrowdsalePhase.PRESALE && !whitelistManager.isWhitelisted(buyer)) {
                continue;
            }
            
            // 计算代币数量
            uint256 tokenAmount = pricingStrategy.calculateTokenAmount(weiAmount, buyer);
            if (tokenAmount == 0) continue;
            
            // 执行购买
            _processPurchase(buyer, weiAmount, tokenAmount);
            
            // 转移资金到托管合约
            if (address(refundVault) != address(0)) {
                refundVault.deposit{value: weiAmount}(buyer);
            }
            
            emit TokensPurchased(buyer, weiAmount, tokenAmount, block.timestamp);
        }
        
        // 如果没有设置托管合约，转移剩余资金到资金钱包
        if (address(refundVault) == address(0) && address(this).balance > 0) {
            fundingWallet.transfer(address(this).balance);
        }
        
        // 退还多余的ETH
        if (msg.value > totalWeiNeeded) {
            payable(msg.sender).transfer(msg.value - totalWeiNeeded);
        }
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
        
        // 处理资金托管
        if (address(refundVault) != address(0)) {
            if (isSoftCapReached()) {
                // 软顶达成，释放资金到资金钱包
                refundVault.release();
            } else {
                // 软顶未达成，启用退款
                refundVault.enableRefunds();
            }
        }
        
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
    
    /**
     * @dev 设置定价策略
     */
    function setPricingStrategy(address _pricingStrategy) 
        external 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        validAddress(_pricingStrategy)
        whenNotPaused
    {
        pricingStrategy = IPricingStrategy(_pricingStrategy);
        emit PricingStrategyUpdated(_pricingStrategy, _msgSender());
    }
    
    /**
     * @dev 设置资金托管合约
     */
    function setRefundVault(address _refundVault) 
        external 
        onlyRole(CrowdsaleConstants.CROWDSALE_ADMIN_ROLE)
        validAddress(_refundVault)
        whenNotPaused
    {
        refundVault = IRefundVault(_refundVault);
        emit RefundVaultUpdated(_refundVault, _msgSender());
    }
    
    // ============ Query Functions ============
    
    /**
     * @dev 获取用户购买历史
     */
    function getUserPurchaseHistory(address user) 
        external view returns (PurchaseRecord[] memory) {
        return purchaseHistory[user];
    }
    
    /**
     * @dev 获取用户总购买金额
     */
    function getUserTotalPurchased(address user) external view returns (uint256) {
        return totalPurchased[user];
    }
    
    /**
     * @dev 获取当前代币价格
     */
    function getCurrentTokenPrice() external view returns (uint256) {
        if (address(pricingStrategy) == address(0)) return 0;
        return pricingStrategy.getCurrentPrice();
    }
    
    /**
     * @dev 获取用户的代币价格（考虑白名单折扣）
     */
    function getTokenPriceForUser(address user) external view returns (uint256) {
        if (address(pricingStrategy) == address(0)) return 0;
        return pricingStrategy.getPriceForBuyer(user);
    }
    
    /**
     * @dev 计算指定金额可购买的代币数量
     */
    function calculateTokenAmount(uint256 weiAmount, address buyer) 
        external view returns (uint256) {
        if (address(pricingStrategy) == address(0)) return 0;
        return pricingStrategy.calculateTokenAmount(weiAmount, buyer);
    }
    
    /**
     * @dev 检查用户是否可以购买
     */
    function canPurchase(address buyer, uint256 weiAmount) external view returns (bool) {
        // 检查基本条件
        if (paused() || 
            (currentPhase != CrowdsalePhase.PRESALE && currentPhase != CrowdsalePhase.PUBLIC_SALE) ||
            !isInValidTimeWindow() ||
            weiAmount < config.minPurchase ||
            weiAmount > config.maxPurchase ||
            stats.totalRaised + weiAmount > config.hardCap) {
            return false;
        }
        
        // 检查购买冷却时间
        if (block.timestamp < lastPurchaseTime[buyer] + PURCHASE_COOLDOWN) {
            return false;
        }
        
        // 预售阶段检查白名单
        if (currentPhase == CrowdsalePhase.PRESALE && !whitelistManager.isWhitelisted(buyer)) {
            return false;
        }
        
        // 检查定价策略
        if (address(pricingStrategy) == address(0)) {
            return false;
        }
        
        return pricingStrategy.isValidPurchase(buyer, weiAmount);
    }
    
    /**
     * @dev 获取剩余可购买代币数量（基于硬顶）
     */
    function getRemainingTokens() external view returns (uint256) {
        if (stats.totalRaised >= config.hardCap) {
            return 0;
        }
        
        uint256 remainingWei = config.hardCap - stats.totalRaised;
        if (address(pricingStrategy) == address(0)) {
            return 0;
        }
        
        // 使用当前价格估算剩余代币数量
        uint256 currentPrice = pricingStrategy.getCurrentPrice();
        if (currentPrice == 0) return 0;
        
        return (remainingWei * 1e18) / currentPrice;
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev 处理购买逻辑
     */
    function _processPurchase(address buyer, uint256 weiAmount, uint256 tokenAmount) internal {
        // 更新统计数据
        stats.totalRaised += weiAmount;
        stats.totalTokensSold += tokenAmount;
        stats.totalPurchases += 1;
        
        // 更新参与者状态
        if (!hasParticipated[buyer]) {
            hasParticipated[buyer] = true;
            stats.totalParticipants += 1;
        }
        
        // 更新用户数据
        totalPurchased[buyer] += weiAmount;
        lastPurchaseTime[buyer] = block.timestamp;
        
        // 记录购买历史
        purchaseHistory[buyer].push(PurchaseRecord({
            weiAmount: weiAmount,
            tokenAmount: tokenAmount,
            price: pricingStrategy.getPriceForBuyer(buyer),
            timestamp: block.timestamp,
            pricingType: pricingStrategy.getPricingType(),
            isWhitelistPurchase: whitelistManager.isWhitelisted(buyer)
        }));
        
        // 铸造代币给购买者
        token.mint(buyer, tokenAmount);
        
        // 检查目标达成
        if (isSoftCapReached() && stats.totalRaised - weiAmount < config.softCap) {
            emit CapReached("soft", config.softCap, block.timestamp);
        }
        if (isHardCapReached()) {
            emit CapReached("hard", config.hardCap, block.timestamp);
        }
    }
    
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
    
    /**
     * @dev 代币购买事件
     */
    event TokensPurchased(
        address indexed buyer,
        uint256 weiAmount,
        uint256 tokenAmount,
        uint256 timestamp
    );
    
    /**
     * @dev 定价策略更新事件
     */
    event PricingStrategyUpdated(
        address indexed newStrategy,
        address indexed updatedBy
    );
}
