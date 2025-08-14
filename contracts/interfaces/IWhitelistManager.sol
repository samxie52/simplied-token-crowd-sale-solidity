// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

/**
 * @title IWhitelistManager
 * @dev 白名单管理合约接口
 * 
 * 定义了白名单管理的标准接口，支持分层权限、批量操作和时间控制
 */
interface IWhitelistManager {
    
    /**
     * @dev 白名单级别枚举
     */
    enum WhitelistLevel {
        BLACKLISTED,    // 0 - 黑名单
        NONE,          // 1 - 无权限
        WHITELISTED,   // 2 - 白名单
        VIP            // 3 - VIP用户
    }
    
    /**
     * @dev 用户白名单信息结构
     */
    struct WhitelistInfo {
        WhitelistLevel level;      // 白名单级别
        uint256 expirationTime;    // 过期时间 (0表示永不过期)
        uint256 addedTime;         // 添加时间
        address addedBy;           // 添加者地址
    }
    
    // ============ 事件定义 ============
    
    /**
     * @dev 用户被添加到白名单时触发
     */
    event WhitelistAdded(
        address indexed user,
        WhitelistLevel indexed level,
        uint256 expirationTime,
        address indexed addedBy
    );
    
    /**
     * @dev 用户被移除白名单时触发
     */
    event WhitelistRemoved(
        address indexed user,
        WhitelistLevel previousLevel,
        address indexed removedBy
    );
    
    /**
     * @dev 批量添加白名单时触发
     */
    event BatchWhitelistAdded(
        address[] users,
        WhitelistLevel[] levels,
        uint256 expirationTime,
        address indexed addedBy
    );
    
    /**
     * @dev 白名单状态转移时触发
     */
    event WhitelistTransferred(
        address indexed from,
        address indexed to,
        WhitelistLevel level,
        address indexed transferredBy
    );
    
    /**
     * @dev 白名单过期时触发
     */
    event WhitelistExpired(
        address indexed user,
        WhitelistLevel previousLevel
    );
    
    // ============ 核心功能接口 ============
    
    /**
     * @dev 添加用户到白名单
     * @param user 用户地址
     * @param level 白名单级别
     */
    function addToWhitelist(address user, WhitelistLevel level) external;
    
    /**
     * @dev 添加用户到白名单（带过期时间）
     * @param user 用户地址
     * @param level 白名单级别
     * @param expirationTime 过期时间戳
     */
    function addToWhitelistWithExpiration(
        address user, 
        WhitelistLevel level, 
        uint256 expirationTime
    ) external;
    
    /**
     * @dev 从白名单移除用户
     * @param user 用户地址
     */
    function removeFromWhitelist(address user) external;
    
    /**
     * @dev 批量添加用户到白名单
     * @param users 用户地址数组
     * @param levels 白名单级别数组
     */
    function batchAddToWhitelist(
        address[] calldata users, 
        WhitelistLevel[] calldata levels
    ) external;
    
    /**
     * @dev 批量添加用户到白名单（带过期时间）
     * @param users 用户地址数组
     * @param levels 白名单级别数组
     * @param expirationTime 过期时间戳
     */
    function batchAddToWhitelistWithExpiration(
        address[] calldata users,
        WhitelistLevel[] calldata levels,
        uint256 expirationTime
    ) external;
    
    /**
     * @dev 批量移除用户白名单
     * @param users 用户地址数组
     */
    function batchRemoveFromWhitelist(address[] calldata users) external;
    
    /**
     * @dev 转移白名单状态
     * @param from 源地址
     * @param to 目标地址
     */
    function transferWhitelistStatus(address from, address to) external;
    
    // ============ 查询接口 ============
    
    /**
     * @dev 获取用户白名单状态
     * @param user 用户地址
     * @return level 白名单级别
     */
    function getWhitelistStatus(address user) external view returns (WhitelistLevel level);
    
    /**
     * @dev 获取用户完整白名单信息
     * @param user 用户地址
     * @return info 白名单信息结构
     */
    function getWhitelistInfo(address user) external view returns (WhitelistInfo memory info);
    
    /**
     * @dev 检查用户是否在白名单中
     * @param user 用户地址
     * @return 是否在白名单中
     */
    function isWhitelisted(address user) external view returns (bool);
    
    /**
     * @dev 检查用户是否为VIP
     * @param user 用户地址
     * @return 是否为VIP用户
     */
    function isVIP(address user) external view returns (bool);
    
    /**
     * @dev 检查用户是否被黑名单
     * @param user 用户地址
     * @return 是否被黑名单
     */
    function isBlacklisted(address user) external view returns (bool);
    
    /**
     * @dev 检查白名单是否过期
     * @param user 用户地址
     * @return 是否过期
     */
    function isExpired(address user) external view returns (bool);
    
    /**
     * @dev 获取白名单统计信息
     * @return vipCount VIP用户数量
     * @return whitelistedCount 白名单用户数量
     * @return blacklistedCount 黑名单用户数量
     * @return totalCount 总用户数量
     */
    function getWhitelistStats() external view returns (
        uint256 vipCount,
        uint256 whitelistedCount, 
        uint256 blacklistedCount,
        uint256 totalCount
    );
    
    // ============ 管理接口 ============
    
    /**
     * @dev 清理过期的白名单条目
     * @param users 要检查的用户地址数组
     */
    function cleanupExpiredWhitelists(address[] calldata users) external;
    
    /**
     * @dev 暂停白名单功能
     */
    function pause() external;
    
    /**
     * @dev 恢复白名单功能
     */
    function unpause() external;
    
    /**
     * @dev 检查合约是否暂停
     * @return 是否暂停
     */
    function paused() external view returns (bool);
}
