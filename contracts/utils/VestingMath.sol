// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VestingMath
 * @dev 代币释放数学计算库
 * @author Crowdsale Platform Team
 */
library VestingMath {
    
    // ============ 常量定义 ============
    
    uint256 public constant BASIS_POINTS = 10000;  // 100% = 10000 basis points
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant SECONDS_PER_MONTH = 2629746; // 30.44 days average
    uint256 public constant SECONDS_PER_YEAR = 31556952;  // 365.25 days
    
    // ============ 核心计算函数 ============
    
    /**
     * @dev 计算线性释放数量
     * @param totalAmount 总释放数量
     * @param startTime 开始时间
     * @param duration 释放期时长
     * @param currentTime 当前时间
     * @return 已释放数量
     */
    function calculateLinearVesting(
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 currentTime
    ) internal pure returns (uint256) {
        if (currentTime < startTime) {
            return 0;
        }
        
        if (currentTime >= startTime + duration) {
            return totalAmount;
        }
        
        uint256 timeElapsed = currentTime - startTime;
        return (totalAmount * timeElapsed) / duration;
    }
    
    /**
     * @dev 计算悬崖期释放数量
     * @param totalAmount 总释放数量
     * @param startTime 开始时间
     * @param cliffDuration 悬崖期时长
     * @param vestingDuration 释放期时长
     * @param currentTime 当前时间
     * @return 已释放数量
     */
    function calculateCliffVesting(
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 currentTime
    ) internal pure returns (uint256) {
        uint256 cliffEnd = startTime + cliffDuration;
        
        // 悬崖期内不释放
        if (currentTime < cliffEnd) {
            return 0;
        }
        
        uint256 vestingEnd = startTime + vestingDuration;
        
        // 释放期结束，全部释放
        if (currentTime >= vestingEnd) {
            return totalAmount;
        }
        
        // 悬崖期后线性释放
        uint256 effectiveVestingDuration = vestingDuration - cliffDuration;
        uint256 timeSinceCliff = currentTime - cliffEnd;
        
        return (totalAmount * timeSinceCliff) / effectiveVestingDuration;
    }
    
    /**
     * @dev 计算复合释放数量（悬崖期 + 线性释放）
     * @param totalAmount 总释放数量
     * @param startTime 开始时间
     * @param cliffDuration 悬崖期时长
     * @param vestingDuration 总释放期时长
     * @param currentTime 当前时间
     * @return 已释放数量
     */
    function calculateCompoundVesting(
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 currentTime
    ) internal pure returns (uint256) {
        if (currentTime < startTime) {
            return 0;
        }
        
        uint256 cliffEnd = startTime + cliffDuration;
        
        if (currentTime < cliffEnd) {
            return 0;
        }
        
        uint256 vestingEnd = startTime + vestingDuration;
        
        if (currentTime >= vestingEnd) {
            return totalAmount;
        }
        
        // 悬崖期后开始线性释放
        uint256 effectiveVestingDuration = vestingDuration - cliffDuration;
        uint256 timeSinceCliff = currentTime - cliffEnd;
        
        return (totalAmount * timeSinceCliff) / effectiveVestingDuration;
    }
    
    /**
     * @dev 计算基于百分比的释放数量
     * @param totalAmount 总数量
     * @param percentage 百分比 (basis points)
     * @return 计算结果
     */
    function calculatePercentageVesting(
        uint256 totalAmount,
        uint256 percentage
    ) internal pure returns (uint256) {
        require(percentage <= BASIS_POINTS, "VestingMath: percentage too high");
        return (totalAmount * percentage) / BASIS_POINTS;
    }
    
    // ============ 时间计算函数 ============
    
    /**
     * @dev 计算剩余释放时间
     * @param startTime 开始时间
     * @param duration 总时长
     * @param currentTime 当前时间
     * @return 剩余时间（秒）
     */
    function calculateRemainingTime(
        uint256 startTime,
        uint256 duration,
        uint256 currentTime
    ) internal pure returns (uint256) {
        uint256 endTime = startTime + duration;
        
        if (currentTime >= endTime) {
            return 0;
        }
        
        return endTime - currentTime;
    }
    
    /**
     * @dev 计算释放进度百分比
     * @param startTime 开始时间
     * @param duration 总时长
     * @param currentTime 当前时间
     * @return 进度百分比 (basis points)
     */
    function calculateVestingProgress(
        uint256 startTime,
        uint256 duration,
        uint256 currentTime
    ) internal pure returns (uint256) {
        if (currentTime < startTime) {
            return 0;
        }
        
        if (currentTime >= startTime + duration) {
            return BASIS_POINTS; // 100%
        }
        
        uint256 timeElapsed = currentTime - startTime;
        return (BASIS_POINTS * timeElapsed) / duration;
    }
    
    /**
     * @dev 计算下次释放时间
     * @param startTime 开始时间
     * @param cliffDuration 悬崖期时长
     * @param currentTime 当前时间
     * @return 下次释放时间
     */
    function calculateNextReleaseTime(
        uint256 startTime,
        uint256 cliffDuration,
        uint256 currentTime
    ) internal pure returns (uint256) {
        uint256 cliffEnd = startTime + cliffDuration;
        
        if (currentTime < cliffEnd) {
            return cliffEnd;
        }
        
        return currentTime; // 已经可以释放
    }
    
    // ============ 阶梯式释放计算 ============
    
    /**
     * @dev 计算阶梯式释放的步骤时间
     * @param startTime 开始时间
     * @param totalDuration 总时长
     * @param stepCount 步骤数量
     * @param stepIndex 步骤索引 (0-based)
     * @return 该步骤的释放时间
     */
    function calculateStepTime(
        uint256 startTime,
        uint256 totalDuration,
        uint256 stepCount,
        uint256 stepIndex
    ) internal pure returns (uint256) {
        require(stepIndex < stepCount, "VestingMath: invalid step index");
        require(stepCount > 0, "VestingMath: invalid step count");
        
        uint256 stepDuration = totalDuration / stepCount;
        return startTime + (stepIndex + 1) * stepDuration;
    }
    
    /**
     * @dev 计算阶梯式释放的当前可释放数量
     * @param totalAmount 总数量
     * @param startTime 开始时间
     * @param totalDuration 总时长
     * @param stepCount 步骤数量
     * @param currentTime 当前时间
     * @return 可释放数量
     */
    function calculateSteppedVesting(
        uint256 totalAmount,
        uint256 startTime,
        uint256 totalDuration,
        uint256 stepCount,
        uint256 currentTime
    ) internal pure returns (uint256) {
        if (currentTime < startTime) {
            return 0;
        }
        
        if (currentTime >= startTime + totalDuration) {
            return totalAmount;
        }
        
        uint256 stepDuration = totalDuration / stepCount;
        uint256 stepAmount = totalAmount / stepCount;
        uint256 completedSteps = 0;
        
        for (uint256 i = 0; i < stepCount; i++) {
            uint256 stepTime = startTime + (i + 1) * stepDuration;
            if (currentTime >= stepTime) {
                completedSteps++;
            } else {
                break;
            }
        }
        
        return completedSteps * stepAmount;
    }
    
    // ============ 工具函数 ============
    
    /**
     * @dev 检查时间是否有效
     * @param startTime 开始时间
     * @param duration 时长
     * @return 是否有效
     */
    function isValidTimeRange(
        uint256 startTime,
        uint256 duration
    ) internal view returns (bool) {
        return startTime > block.timestamp && duration > 0;
    }
    
    /**
     * @dev 检查释放是否已开始
     * @param startTime 开始时间
     * @param currentTime 当前时间
     * @return 是否已开始
     */
    function hasVestingStarted(
        uint256 startTime,
        uint256 currentTime
    ) internal pure returns (bool) {
        return currentTime >= startTime;
    }
    
    /**
     * @dev 检查释放是否已完成
     * @param startTime 开始时间
     * @param duration 时长
     * @param currentTime 当前时间
     * @return 是否已完成
     */
    function hasVestingCompleted(
        uint256 startTime,
        uint256 duration,
        uint256 currentTime
    ) internal pure returns (bool) {
        return currentTime >= startTime + duration;
    }
    
    /**
     * @dev 检查是否在悬崖期内
     * @param startTime 开始时间
     * @param cliffDuration 悬崖期时长
     * @param currentTime 当前时间
     * @return 是否在悬崖期内
     */
    function isInCliffPeriod(
        uint256 startTime,
        uint256 cliffDuration,
        uint256 currentTime
    ) internal pure returns (bool) {
        return currentTime >= startTime && currentTime < startTime + cliffDuration;
    }
    
    /**
     * @dev 安全的乘法运算，防止溢出
     * @param a 第一个数
     * @param b 第二个数
     * @return 乘积结果
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "VestingMath: multiplication overflow");
        return c;
    }
    
    /**
     * @dev 安全的除法运算，防止除零
     * @param a 被除数
     * @param b 除数
     * @return 除法结果
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "VestingMath: division by zero");
        return a / b;
    }
    
    /**
     * @dev 计算两个数的最小值
     * @param a 第一个数
     * @param b 第二个数
     * @return 最小值
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    /**
     * @dev 计算两个数的最大值
     * @param a 第一个数
     * @param b 第二个数
     * @return 最大值
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
