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
     */
    function getWhitelistStatus(address user) external view override returns (WhitelistLevel level) {
        return _getEffectiveLevel(user);
    }
    
    /**
     * @dev 获取用户完整白名单信息
     */
    function getWhitelistInfo(address user) external view override returns (WhitelistInfo memory info) {
        return _whitelistInfo[user];
    }
    
    /**
     * @dev 检查用户是否在白名单中
     */
    function isWhitelisted(address user) external view override returns (bool) {
        WhitelistLevel level = _getEffectiveLevel(user);
        return level == WhitelistLevel.WHITELISTED || level == WhitelistLevel.VIP;
    }
    
    /**
     * @dev 检查用户是否为VIP
     */
    function isVIP(address user) external view override returns (bool) {
        return _getEffectiveLevel(user) == WhitelistLevel.VIP;
    }
    
    /**
     * @dev 检查用户是否被黑名单
     */
    function isBlacklisted(address user) external view override returns (bool) {
        return _getEffectiveLevel(user) == WhitelistLevel.BLACKLISTED;
    }
    
    /**
     * @dev 检查白名单是否过期
     */
    function isExpired(address user) external view override returns (bool) {
        WhitelistInfo memory info = _whitelistInfo[user];
        return info.expirationTime != 0 && block.timestamp >= info.expirationTime;
    }
    
    /**
     * @dev 获取白名单统计信息
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
     */
    function pause() external override onlyWhitelistAdmin {
        _pause();
    }
    
    /**
     * @dev 恢复白名单功能
     */
    function unpause() external override onlyWhitelistAdmin {
        _unpause();
    }
    
    /**
     * @dev 检查合约是否暂停
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
