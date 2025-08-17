// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IWhitelistManager.sol";

/**
 * @title WhitelistManager
 * @dev 白名单管理合约实现
 * 
 * 特性：
 * - 分层白名单管理（黑名单、普通、白名单、VIP）
 * - 批量操作优化
 * - 时间控制机制
 * - 权限转移功能
 * - Gas优化设计
 * - 完整的事件日志
 */
contract WhitelistManager is 
    AccessControl, 
    ReentrancyGuard, 
    Pausable, 
    IWhitelistManager 
{
    
    // ============ 角色定义 ============
    bytes32 public constant WHITELIST_ADMIN_ROLE = keccak256("WHITELIST_ADMIN_ROLE");
    bytes32 public constant WHITELIST_OPERATOR_ROLE = keccak256("WHITELIST_OPERATOR_ROLE");
    
    // ============ 状态变量 ============
    
    // 用户白名单信息映射
    mapping(address => WhitelistInfo) private _whitelistInfo;
    
    // 用户地址数组（用于遍历）
    address[] private _allUsers;
    mapping(address => uint256) private _userIndex; // 用户地址在数组中的索引
    
    // 统计信息
    uint256 public totalUsers;
    uint256 public vipCount;
    uint256 public whitelistedCount;
    uint256 public blacklistedCount;
    
    // 批量操作限制
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    // ============ 修饰符 ============
    
    /**
     * @dev 检查是否有白名单管理权限
     */
    modifier onlyWhitelistAdmin() {
        require(
            hasRole(WHITELIST_ADMIN_ROLE, msg.sender) || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "WhitelistManager: caller is not whitelist admin"
        );
        _;
    }
    
    /**
     * @dev 检查是否有白名单操作权限
     */
    modifier onlyWhitelistOperator() {
        require(
            hasRole(WHITELIST_OPERATOR_ROLE, msg.sender) || 
            hasRole(WHITELIST_ADMIN_ROLE, msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "WhitelistManager: caller is not whitelist operator"
        );
        _;
    }
    
    /**
     * @dev 检查地址有效性
     */
    modifier validAddress(address addr) {
        require(addr != address(0), "WhitelistManager: invalid address");
        _;
    }
    
    /**
     * @dev 检查批量操作数组长度
     */
    modifier validBatchSize(uint256 length) {
        require(length > 0 && length <= MAX_BATCH_SIZE, "WhitelistManager: invalid batch size");
        _;
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数
     * @param admin 管理员地址
     */
    constructor(address admin) validAddress(admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(WHITELIST_ADMIN_ROLE, admin);
        _grantRole(WHITELIST_OPERATOR_ROLE, admin);
    }
    
    // ============ 核心功能实现 ============
    
    /**
     * @dev 添加用户到白名单
     * @param user 用户地址
     * @param level 白名单级别（NONE, WHITELISTED, VIP, BLACKLISTED）
     * 
     * 功能概述：
     * 将指定用户添加到白名单中，设置相应的权限级别
     * 
     * 实现步骤：
     * 1. 验证用户地址有效性和权限
     * 2. 调用内部函数_addToWhitelist处理添加逻辑
     * 3. 更新用户统计信息
     * 4. 发出WhitelistAdded事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：为众筹参与者设置白名单权限，控制参与资格
     * 安全考虑：使用ReentrancyGuard防重入，严格权限控制，地址有效性验证
     */
    function addToWhitelist(
        address user, 
        WhitelistLevel level
    ) 
        external 
        override 
        onlyWhitelistOperator 
        whenNotPaused 
        validAddress(user) 
        nonReentrant 
    {
        _addToWhitelist(user, level, 0);
    }
    
    /**
     * @dev 添加用户到白名单（带过期时间）
     * @param user 用户地址
     * @param level 白名单级别
     * @param expirationTime 过期时间戳（0表示永不过期）
     * 
     * 功能概述：
     * 将用户添加到白名单并设置过期时间，支持临时权限管理
     * 
     * 实现步骤：
     * 1. 验证过期时间的有效性（必须大于当前时间或为0）
     * 2. 调用内部函数处理添加逻辑
     * 3. 设置过期时间并更新统计
     * 4. 发出相应事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：为临时参与者或测试用户设置有时限的白名单权限
     * 安全考虑：验证过期时间合理性，防止设置过去的时间
     */
    function addToWhitelistWithExpiration(
        address user,
        WhitelistLevel level,
        uint256 expirationTime
    )
        external
        override
        onlyWhitelistOperator
        whenNotPaused
        validAddress(user)
        nonReentrant
    {
        require(
            expirationTime == 0 || expirationTime > block.timestamp,
            "WhitelistManager: invalid expiration time"
        );
        _addToWhitelist(user, level, expirationTime);
    }
    
    /**
     * @dev 从白名单移除用户
     * @param user 要移除的用户地址
     * 
     * 功能概述：
     * 从白名单中完全移除指定用户，清除其所有权限
     * 
     * 实现步骤：
     * 1. 验证用户地址有效性和操作权限
     * 2. 调用内部函数_removeFromWhitelist处理移除逻辑
     * 3. 更新用户数组和索引映射
     * 4. 更新统计信息
     * 5. 发出WhitelistRemoved事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：移除违规用户或不再需要权限的用户
     * 安全考虑：完全清除用户数据，更新数组结构保持数据一致性
     */
    function removeFromWhitelist(
        address user
    ) 
        external 
        override 
        onlyWhitelistOperator 
        whenNotPaused 
        validAddress(user) 
        nonReentrant 
    {
        _removeFromWhitelist(user);
    }
    
    /**
     * @dev 批量添加用户到白名单
     * @param users 用户地址数组
     * @param levels 对应的白名单级别数组
     * 
     * 功能概述：
     * 批量将多个用户添加到白名单中，提高操作效率
     * 
     * 实现步骤：
     * 1. 验证数组长度匹配和批量大小限制
     * 2. 遍历用户数组，验证每个地址有效性
     * 3. 对每个用户调用内部添加函数
     * 4. 创建内存数组用于事件发出
     * 5. 发出BatchWhitelistAdded事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：批量处理众筹参与者的白名单权限，节省Gas成本
     * 安全考虑：限制批量大小防止Gas耗尽，验证每个地址有效性
     */
    function batchAddToWhitelist(
        address[] calldata users,
        WhitelistLevel[] calldata levels
    )
        external
        override
        onlyWhitelistOperator
        whenNotPaused
        validBatchSize(users.length)
        nonReentrant
    {
        require(users.length == levels.length, "WhitelistManager: arrays length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "WhitelistManager: invalid address in batch");
            _addToWhitelist(users[i], levels[i], 0);
        }
        
        // 创建存储数组以匹配事件参数
        address[] memory usersMemory = new address[](users.length);
        WhitelistLevel[] memory levelsMemory = new WhitelistLevel[](levels.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            usersMemory[i] = users[i];
            levelsMemory[i] = levels[i];
        }
        
        emit BatchWhitelistAdded(usersMemory, levelsMemory, 0, msg.sender);
    }
    
    /**
     * @dev 批量添加用户到白名单（带过期时间）
     * @param users 用户地址数组
     * @param levels 对应的白名单级别数组
     * @param expirationTime 统一的过期时间戳
     * 
     * 功能概述：
     * 批量将用户添加到白名单并设置统一的过期时间
     * 
     * 实现步骤：
     * 1. 验证数组长度匹配和过期时间有效性
     * 2. 验证批量大小在允许范围内
     * 3. 遍历处理每个用户的添加操作
     * 4. 为所有用户设置相同的过期时间
     * 5. 发出批量添加事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：为临时活动或测试阶段批量设置有时限的白名单权限
     * 安全考虑：统一过期时间管理，防止设置无效时间
     */
    function batchAddToWhitelistWithExpiration(
        address[] calldata users,
        WhitelistLevel[] calldata levels,
        uint256 expirationTime
    )
        external
        override
        onlyWhitelistOperator
        whenNotPaused
        validBatchSize(users.length)
        nonReentrant
    {
        require(users.length == levels.length, "WhitelistManager: arrays length mismatch");
        require(
            expirationTime == 0 || expirationTime > block.timestamp,
            "WhitelistManager: invalid expiration time"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "WhitelistManager: invalid address in batch");
            _addToWhitelist(users[i], levels[i], expirationTime);
        }
        
        emit BatchWhitelistAdded(users, levels, expirationTime, msg.sender);
    }
    
    /**
     * @dev 批量移除用户白名单
     * @param users 要移除的用户地址数组
     * 
     * 功能概述：
     * 批量从白名单中移除多个用户，提高管理效率
     * 
     * 实现步骤：
     * 1. 验证批量大小在允许范围内
     * 2. 遍历用户数组，验证每个地址有效性
     * 3. 对每个用户调用内部移除函数
     * 4. 更新相关统计信息
     * 5. 为每个用户发出移除事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：批量清理违规用户或过期权限，维护白名单质量
     * 安全考虑：限制批量大小，验证每个地址，安全更新数据结构
     */
    function batchRemoveFromWhitelist(
        address[] calldata users
    )
        external
        override
        onlyWhitelistOperator
        whenNotPaused
        validBatchSize(users.length)
        nonReentrant
    {
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "WhitelistManager: invalid address in batch");
            _removeFromWhitelist(users[i]);
        }
    }
    
    /**
     * @dev 转移白名单状态
     * @param from 源用户地址
     * @param to 目标用户地址
     * 
     * 功能概述：
     * 将一个用户的白名单状态完全转移给另一个用户
     * 
     * 实现步骤：
     * 1. 验证源地址和目标地址的有效性
     * 2. 检查源地址确实有白名单状态
     * 3. 处理目标地址的现有状态（如果有）
     * 4. 转移白名单级别和过期时间
     * 5. 清除源地址状态并更新统计
     * 6. 发出WhitelistTransferred事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：处理用户地址变更或权限转让场景
     * 安全考虑：防止转移到相同地址，正确处理统计数据，保持数据一致性
     */
    function transferWhitelistStatus(
        address from,
        address to
    )
        external
        override
        onlyWhitelistOperator
        whenNotPaused
        validAddress(from)
        validAddress(to)
        nonReentrant
    {
        require(from != to, "WhitelistManager: cannot transfer to same address");
        
        WhitelistInfo memory fromInfo = _whitelistInfo[from];
        require(fromInfo.addedTime != 0, "WhitelistManager: from address not whitelisted");
        
        // 检查目标地址是否已有白名单状态
        WhitelistInfo memory toInfo = _whitelistInfo[to];
        if (toInfo.addedTime != 0) {
            _updateStats(toInfo.level, false); // 移除原有状态的统计
            totalUsers--; // 减少总用户数，因为要被覆盖
        } else {
            totalUsers++; // 增加总用户数，因为是新用户
        }
        
        // 转移状态
        _whitelistInfo[to] = WhitelistInfo({
            level: fromInfo.level,
            expirationTime: fromInfo.expirationTime,
            addedTime: block.timestamp,
            addedBy: msg.sender
        });
        
        // 清除源地址状态（手动清除，不调用_removeFromWhitelist以避免影响统计）
        delete _whitelistInfo[from];
        totalUsers--; // 减少总用户数
        _updateStats(fromInfo.level, false); // 移除源地址的统计
        _updateStats(fromInfo.level, true); // 添加目标地址的统计
        
        emit WhitelistTransferred(from, to, fromInfo.level, msg.sender);
    }
    
    // ============ 查询功能实现 ============
    
    /**
     * @dev 获取用户白名单状态
     * @param user 用户地址
     * @return level 用户当前的有效白名单级别
     * 
     * 功能概述：
     * 查询用户当前的有效白名单级别，考虑过期时间
     * 
     * 实现步骤：
     * 1. 调用内部函数_getEffectiveLevel获取有效级别
     * 2. 考虑过期时间，返回实际有效的级别
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：众筹合约查询用户参与资格和权限级别
     * 安全考虑：只读操作，自动处理过期状态，无安全风险
     */
    function getWhitelistStatus(address user) external view override returns (WhitelistLevel level) {
        return _getEffectiveLevel(user);
    }
    
    /**
     * @dev 获取用户完整白名单信息
     * @param user 用户地址
     * @return info 用户的完整白名单信息结构
     * 
     * 功能概述：
     * 获取用户的详细白名单信息，包括级别、过期时间、添加时间等
     * 
     * 实现步骤：
     * 1. 从存储中直接返回用户的白名单信息结构
     * 2. 包含所有原始数据，不考虑过期状态
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：获取用户白名单的完整历史和配置信息
     * 安全考虑：只读操作，返回原始数据，无安全风险
     */
    function getWhitelistInfo(address user) external view override returns (WhitelistInfo memory info) {
        return _whitelistInfo[user];
    }
    
    /**
     * @dev 检查用户是否在白名单中
     * @param user 用户地址
     * @return 用户是否具有白名单或VIP权限
     * 
     * 功能概述：
     * 检查用户是否具有有效的白名单权限（WHITELISTED或VIP级别）
     * 
     * 实现步骤：
     * 1. 获取用户的有效级别
     * 2. 判断是否为WHITELISTED或VIP级别
     * 3. 返回布尔值结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：众筹合约快速检查用户参与资格
     * 安全考虑：自动处理过期状态，只返回有效权限
     */
    function isWhitelisted(address user) external view override returns (bool) {
        WhitelistLevel level = _getEffectiveLevel(user);
        return level == WhitelistLevel.WHITELISTED || level == WhitelistLevel.VIP;
    }
    
    /**
     * @dev 检查用户是否为VIP
     * @param user 用户地址
     * @return 用户是否具有VIP权限
     * 
     * 功能概述：
     * 检查用户是否具有有效的VIP级别权限
     * 
     * 实现步骤：
     * 1. 获取用户的有效级别
     * 2. 判断是否为VIP级别
     * 3. 返回布尔值结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：众筹合约检查VIP用户的特殊权限和优惠
     * 安全考虑：自动处理过期状态，确保只返回有效VIP状态
     */
    function isVIP(address user) external view override returns (bool) {
        return _getEffectiveLevel(user) == WhitelistLevel.VIP;
    }
    
    /**
     * @dev 检查用户是否被黑名单
     * @param user 用户地址
     * @return 用户是否被列入黑名单
     * 
     * 功能概述：
     * 检查用户是否被列入黑名单，禁止参与众筹
     * 
     * 实现步骤：
     * 1. 获取用户的有效级别
     * 2. 判断是否为BLACKLISTED级别
     * 3. 返回布尔值结果
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：众筹合约检查用户是否被禁止参与
     * 安全考虑：自动处理过期状态，确保黑名单检查的准确性
     */
    function isBlacklisted(address user) external view override returns (bool) {
        return _getEffectiveLevel(user) == WhitelistLevel.BLACKLISTED;
    }
    
    /**
     * @dev 检查白名单是否过期
     * @param user 用户地址
     * @return 用户的白名单权限是否已过期
     * 
     * 功能概述：
     * 检查用户的白名单权限是否已经过期
     * 
     * 实现步骤：
     * 1. 获取用户的白名单信息
     * 2. 检查过期时间是否设置且已过当前时间
     * 3. 返回过期状态
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：检查临时白名单权限的有效性
     * 安全考虑：只读操作，基于当前时间戳判断，无安全风险
     */
    function isExpired(address user) external view override returns (bool) {
        WhitelistInfo memory info = _whitelistInfo[user];
        return info.expirationTime != 0 && block.timestamp >= info.expirationTime;
    }
    
    /**
     * @dev 获取白名单统计信息
     * @return _vipCount VIP用户数量
     * @return _whitelistedCount 白名单用户数量
     * @return _blacklistedCount 黑名单用户数量
     * @return _totalCount 总用户数量
     * 
     * 功能概述：
     * 获取白名单系统的全面统计信息
     * 
     * 实现步骤：
     * 1. 返回存储中的各类统计数据
     * 2. 包括VIP、白名单、黑名单和总用户数
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：为管理员和前端提供白名单系统的整体数据概览
     * 安全考虑：只读操作，返回实时统计数据，无安全风险
     */
    function getWhitelistStats() external view override returns (
        uint256 _vipCount,
        uint256 _whitelistedCount,
        uint256 _blacklistedCount,
        uint256 _totalCount
    ) {
        return (vipCount, whitelistedCount, blacklistedCount, totalUsers);
    }
    
    /**
     * @dev 获取所有白名单用户地址（分页）
     * @param offset 起始索引
     * @param limit 返回数量限制
     * @return users 用户地址数组
     * @return total 总用户数
     */
    function getAllWhitelistUsers(uint256 offset, uint256 limit) 
        external 
        view 
        returns (address[] memory users, uint256 total) 
    {
        total = _allUsers.length;
        
        if (offset >= total) {
            return (new address[](0), total);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        uint256 length = end - offset;
        users = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            users[i] = _allUsers[offset + i];
        }
        
        return (users, total);
    }
    
    /**
     * @dev 按级别获取白名单用户（分页）
     * @param level 白名单级别
     * @param offset 起始索引
     * @param limit 返回数量限制
     * @return users 用户地址数组
     * @return infos 用户信息数组
     */
    function getUsersByLevel(WhitelistLevel level, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory users, WhitelistInfo[] memory infos)
    {
        // 先计算符合条件的用户数量
        uint256 matchCount = 0;
        for (uint256 i = 0; i < _allUsers.length; i++) {
            if (_getEffectiveLevel(_allUsers[i]) == level) {
                matchCount++;
            }
        }
        
        if (offset >= matchCount) {
            return (new address[](0), new WhitelistInfo[](0));
        }
        
        uint256 end = offset + limit;
        if (end > matchCount) {
            end = matchCount;
        }
        
        uint256 length = end - offset;
        users = new address[](length);
        infos = new WhitelistInfo[](length);
        
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < _allUsers.length && resultIndex < length; i++) {
            if (_getEffectiveLevel(_allUsers[i]) == level) {
                if (currentIndex >= offset) {
                    users[resultIndex] = _allUsers[i];
                    infos[resultIndex] = _whitelistInfo[_allUsers[i]];
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return (users, infos);
    }
    
    /**
     * @dev 批量获取用户白名单信息
     * @param userAddresses 用户地址数组
     * @return infos 用户信息数组
     * @return levels 有效级别数组
     */
    function getBatchWhitelistInfo(address[] calldata userAddresses)
        external
        view
        returns (WhitelistInfo[] memory infos, WhitelistLevel[] memory levels)
    {
        infos = new WhitelistInfo[](userAddresses.length);
        levels = new WhitelistLevel[](userAddresses.length);
        
        for (uint256 i = 0; i < userAddresses.length; i++) {
            infos[i] = _whitelistInfo[userAddresses[i]];
            levels[i] = _getEffectiveLevel(userAddresses[i]);
        }
        
        return (infos, levels);
    }
    
    // ============ 管理功能实现 ============
    
    /**
     * @dev 清理过期的白名单条目
     * @param users 要检查和清理的用户地址数组
     * 
     * 功能概述：
     * 批量清理已过期的白名单条目，将其级别设置为NONE
     * 
     * 实现步骤：
     * 1. 验证批量大小在允许范围内
     * 2. 遍历用户数组，检查每个用户的过期状态
     * 3. 对于过期用户，更新统计并设置级别为NONE
     * 4. 清除过期时间并发出WhitelistExpired事件
     * 
     * 权限要求：只允许WHITELIST_OPERATOR_ROLE或更高权限角色调用
     * 用途说明：定期维护白名单数据质量，清理过期条目
     * 安全考虑：只处理真正过期的条目，保留记录但清除权限
     */
    function cleanupExpiredWhitelists(
        address[] calldata users
    )
        external
        override
        onlyWhitelistOperator
        validBatchSize(users.length)
    {
        for (uint256 i = 0; i < users.length; i++) {
            WhitelistInfo memory info = _whitelistInfo[users[i]];
            if (info.expirationTime != 0 && block.timestamp >= info.expirationTime && info.addedTime != 0) {
                WhitelistLevel previousLevel = info.level;
                
                // 更新统计（移除旧级别）
                _updateStats(previousLevel, false);
                
                // 将级别设置为NONE，保留记录但清除过期时间
                _whitelistInfo[users[i]].level = WhitelistLevel.NONE;
                _whitelistInfo[users[i]].expirationTime = 0;
                
                emit WhitelistExpired(users[i], previousLevel);
            }
        }
    }
    
    /**
     * @dev 暂停白名单功能
     * 
     * 功能概述：
     * 暂停白名单管理合约的所有状态变更操作
     * 
     * 实现步骤：
     * 1. 调用OpenZeppelin的_pause()函数
     * 2. 触发Paused事件
     * 3. 禁止所有状态变更操作
     * 
     * 权限要求：只允许WHITELIST_ADMIN_ROLE或DEFAULT_ADMIN_ROLE角色调用
     * 用途说明：紧急情况下暂停白名单管理操作
     * 安全考虑：严格权限控制，防止滥用暂停功能
     */
    function pause() external override onlyWhitelistAdmin {
        _pause();
    }
    
    /**
     * @dev 恢复白名单功能
     * 
     * 功能概述：
     * 恢复白名单管理合约的正常运行，解除暂停状态
     * 
     * 实现步骤：
     * 1. 调用OpenZeppelin的_unpause()函数
     * 2. 触发Unpaused事件
     * 3. 恢复所有状态变更操作
     * 
     * 权限要求：只允许WHITELIST_ADMIN_ROLE或DEFAULT_ADMIN_ROLE角色调用
     * 用途说明：紧急情况处理完毕后恢复正常运行
     * 安全考虑：严格权限控制，确保只有管理员可以恢复
     */
    function unpause() external override onlyWhitelistAdmin {
        _unpause();
    }
    
    /**
     * @dev 检查合约是否暂停
     * @return 合约是否处于暂停状态
     * 
     * 功能概述：
     * 检查白名单管理合约是否处于暂停状态
     * 
     * 实现步骤：
     * 1. 调用父类的paused()函数
     * 2. 返回当前暂停状态
     * 
     * 权限要求：无，公开查询接口
     * 用途说明：其他合约检查白名单系统的可用性
     * 安全考虑：只读操作，无安全风险
     */
    function paused() public view override(Pausable, IWhitelistManager) returns (bool) {
        return super.paused();
    }
    
    // ============ 内部函数 ============
    
    /**
     * @dev 内部添加白名单函数
     */
    function _addToWhitelist(
        address user,
        WhitelistLevel level,
        uint256 expirationTime
    ) internal {
        WhitelistInfo memory currentInfo = _whitelistInfo[user];
        
        // 如果用户已存在（通过addedTime判断），先移除旧的统计
        if (currentInfo.addedTime != 0) {
            // 如果新级别与旧级别相同，不需要更新统计
            if (currentInfo.level == level) {
                // 只更新过期时间
                _whitelistInfo[user].expirationTime = expirationTime;
                emit WhitelistAdded(user, level, expirationTime, msg.sender);
                return;
            }
            _updateStats(currentInfo.level, false);
        } else {
            // 新用户，添加到数组
            _userIndex[user] = _allUsers.length;
            _allUsers.push(user);
            totalUsers++;
        }
        
        // 更新用户信息
        _whitelistInfo[user] = WhitelistInfo({
            level: level,
            expirationTime: expirationTime,
            addedTime: block.timestamp,
            addedBy: msg.sender
        });
        
        // 更新统计
        _updateStats(level, true);
        
        emit WhitelistAdded(user, level, expirationTime, msg.sender);
    }
    
    /**
     * @dev 内部移除白名单函数
     */
    function _removeFromWhitelist(address user) internal {
        WhitelistInfo memory info = _whitelistInfo[user];
        
        // 检查用户是否真的存在（通过addedTime判断）
        if (info.addedTime != 0) {
            WhitelistLevel previousLevel = info.level;
            
            // 从数组中移除用户
            uint256 index = _userIndex[user];
            uint256 lastIndex = _allUsers.length - 1;
            
            if (index != lastIndex) {
                address lastUser = _allUsers[lastIndex];
                _allUsers[index] = lastUser;
                _userIndex[lastUser] = index;
            }
            
            _allUsers.pop();
            delete _userIndex[user];
            
            // 清除用户信息
            delete _whitelistInfo[user];
            totalUsers--;
            
            // 更新统计
            _updateStats(previousLevel, false);
            
            emit WhitelistRemoved(user, previousLevel, msg.sender);
        }
    }
    
    /**
     * @dev 获取有效的白名单级别（考虑过期时间）
     */
    function _getEffectiveLevel(address user) internal view returns (WhitelistLevel) {
        WhitelistInfo memory info = _whitelistInfo[user];
        
        // 如果用户从未被添加过（addedTime为0），返回NONE
        if (info.addedTime == 0) {
            return WhitelistLevel.NONE;
        }
        
        // 检查是否过期
        if (info.expirationTime != 0 && block.timestamp >= info.expirationTime) {
            return WhitelistLevel.NONE;
        }
        
        return info.level;
    }
    
    /**
     * @dev 更新统计信息
     * @param level 白名单级别
     * @param increase 是否增加计数
     */
    function _updateStats(WhitelistLevel level, bool increase) internal {
        if (level == WhitelistLevel.VIP) {
            if (increase) {
                vipCount++;
            } else if (vipCount > 0) {
                vipCount--;
            }
        } else if (level == WhitelistLevel.WHITELISTED) {
            if (increase) {
                whitelistedCount++;
            } else if (whitelistedCount > 0) {
                whitelistedCount--;
            }
        } else if (level == WhitelistLevel.BLACKLISTED) {
            if (increase) {
                blacklistedCount++;
            } else if (blacklistedCount > 0) {
                blacklistedCount--;
            }
        }
    }
}
