// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ITokenVesting.sol";

/**
 * @title ICrowdsaleFactory
 * @dev 众筹工厂接口定义
 */
interface ICrowdsaleFactory {
    
    // ============ 结构体定义 ============
    
    /**
     * @dev 众筹参数配置
     */
    struct CrowdsaleParams {
        string tokenName;           // 代币名称
        string tokenSymbol;         // 代币符号
        uint256 totalSupply;        // 代币总供应量
        uint256 softCap;           // 软顶目标
        uint256 hardCap;           // 硬顶目标
        uint256 startTime;         // 开始时间
        uint256 endTime;           // 结束时间
        address fundingWallet;     // 资金接收地址
        uint256 tokenPrice;        // 代币价格 (wei per token)
        VestingParams vestingParams; // 释放参数
    }
    
    /**
     * @dev 代币释放参数
     */
    struct VestingParams {
        bool enabled;                           // 是否启用释放
        uint256 cliffDuration;                  // 悬崖期时长
        uint256 vestingDuration;                // 释放总时长
        ITokenVesting.VestingType vestingType;  // 释放类型
        uint256 immediateReleasePercentage;     // 立即释放百分比 (basis points)
    }
    
    /**
     * @dev 众筹实例信息
     */
    struct CrowdsaleInstance {
        address crowdsaleAddress;   // 众筹合约地址
        address tokenAddress;       // 代币合约地址
        address vestingAddress;     // 释放合约地址
        address creator;            // 创建者地址
        uint256 createdAt;         // 创建时间
        bool isActive;             // 是否活跃
    }
    
    // ============ 事件定义 ============
    
    /**
     * @dev 众筹创建事件
     */
    event CrowdsaleCreated(
        address indexed creator,
        address indexed crowdsaleAddress,
        address indexed tokenAddress,
        address vestingAddress,
        string tokenName,
        string tokenSymbol
    );
    
    /**
     * @dev 众筹状态更新事件
     */
    event CrowdsaleStatusUpdated(
        address indexed crowdsaleAddress,
        bool isActive
    );
    
    /**
     * @dev 工厂配置更新事件
     */
    event FactoryConfigUpdated(
        address indexed admin,
        uint256 creationFee,
        bool publicCreation
    );
    
    // ============ 核心功能 ============
    
    /**
     * @dev 创建新的众筹实例
     * @param params 众筹参数
     * @return crowdsaleAddress 众筹合约地址
     * @return tokenAddress 代币合约地址
     * @return vestingAddress 释放合约地址
     */
    function createCrowdsale(CrowdsaleParams calldata params) 
        external 
        payable 
        returns (
            address crowdsaleAddress,
            address tokenAddress,
            address vestingAddress
        );
    
    /**
     * @dev 批量创建众筹实例
     * @param paramsArray 众筹参数数组
     * @return crowdsaleAddresses 众筹合约地址数组
     */
    function batchCreateCrowdsale(CrowdsaleParams[] calldata paramsArray)
        external
        payable
        returns (address[] memory crowdsaleAddresses);
    
    // ============ 查询功能 ============
    
    /**
     * @dev 获取众筹实例信息
     * @param crowdsaleAddress 众筹合约地址
     * @return instance 众筹实例信息
     */
    function getCrowdsaleInstance(address crowdsaleAddress) 
        external 
        view 
        returns (CrowdsaleInstance memory instance);
    
    /**
     * @dev 获取创建者的所有众筹实例
     * @param creator 创建者地址
     * @return instances 众筹实例数组
     */
    function getCreatorCrowdsales(address creator) 
        external 
        view 
        returns (CrowdsaleInstance[] memory instances);
    
    /**
     * @dev 获取所有活跃的众筹实例
     * @return instances 活跃众筹实例数组
     */
    function getActiveCrowdsales() 
        external 
        view 
        returns (CrowdsaleInstance[] memory instances);
    
    /**
     * @dev 获取众筹总数
     * @return count 众筹总数
     */
    function getTotalCrowdsales() external view returns (uint256 count);
    
    /**
     * @dev 验证众筹参数
     * @param params 众筹参数
     * @return isValid 是否有效
     * @return errorMessage 错误信息
     */
    function validateCrowdsaleParams(CrowdsaleParams calldata params) 
        external 
        view 
        returns (bool isValid, string memory errorMessage);
    
    // ============ 管理功能 ============
    
    /**
     * @dev 更新众筹状态
     * @param crowdsaleAddress 众筹合约地址
     * @param isActive 是否活跃
     */
    function updateCrowdsaleStatus(address crowdsaleAddress, bool isActive) external;
    
    /**
     * @dev 设置创建费用
     * @param fee 创建费用
     */
    function setCreationFee(uint256 fee) external;
    
    /**
     * @dev 设置是否允许公开创建
     * @param allowed 是否允许
     */
    function setPublicCreationAllowed(bool allowed) external;
    
    /**
     * @dev 提取费用
     * @param to 接收地址
     * @param amount 提取金额
     */
    function withdrawFees(address payable to, uint256 amount) external;
    
    // ============ 配置查询 ============
    
    /**
     * @dev 获取创建费用
     * @return fee 创建费用
     */
    function getCreationFee() external view returns (uint256 fee);
    
    /**
     * @dev 是否允许公开创建
     * @return allowed 是否允许
     */
    function isPublicCreationAllowed() external view returns (bool allowed);
    
    /**
     * @dev 获取工厂统计信息
     * @return totalCrowdsales 总众筹数
     * @return activeCrowdsales 活跃众筹数
     * @return totalFeesCollected 总收取费用
     */
    function getFactoryStats() 
        external 
        view 
        returns (
            uint256 totalCrowdsales,
            uint256 activeCrowdsales,
            uint256 totalFeesCollected
        );
}
