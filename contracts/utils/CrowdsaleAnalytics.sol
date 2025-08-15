// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ICrowdsale.sol";
import "../interfaces/IPricingStrategy.sol";

/**
 * @title CrowdsaleAnalytics
 * @dev 众筹数据分析工具库
 * @author CrowdsaleTeam
 */
library CrowdsaleAnalytics {
    
    // ============ 结构体定义 ============
    
    /**
     * @dev 众筹分析数据
     */
    struct AnalyticsData {
        uint256 totalParticipants;          // 总参与者数
        uint256 totalTokensSold;            // 总代币销售量
        uint256 totalFundsRaised;          // 总筹集资金
        uint256 averagePurchaseAmount;      // 平均购买金额
        uint256 whitelistParticipants;      // 白名单参与者数
        uint256 publicParticipants;         // 公开参与者数
        uint256 totalPurchases;             // 总购买次数
        uint256 largestPurchase;            // 最大单笔购买
        uint256 smallestPurchase;           // 最小单笔购买
        uint256 medianPurchaseAmount;       // 中位数购买金额
    }
    
    /**
     * @dev 用户统计数据
     */
    struct UserStats {
        uint256 totalPurchased;             // 总购买金额
        uint256 totalTokens;                // 总代币数量
        uint256 purchaseCount;              // 购买次数
        uint256 firstPurchaseTime;          // 首次购买时间
        uint256 lastPurchaseTime;           // 最后购买时间
        bool isWhitelisted;                 // 是否白名单用户
        IPricingStrategy.PricingType preferredPricingType; // 偏好定价类型
    }
    
    /**
     * @dev 时间段分析数据
     */
    struct TimeAnalytics {
        uint256 hourlyPurchases;            // 每小时购买数
        uint256 dailyPurchases;             // 每日购买数
        uint256 weeklyPurchases;            // 每周购买数
        uint256 peakHour;                   // 高峰小时
        uint256 peakDay;                    // 高峰日
    }
    
    // ============ 分析函数 ============
    
    /**
     * @dev 计算众筹进度百分比
     * @param raised 已筹集金额
     * @param target 目标金额
     * @return percentage 进度百分比 (basis points)
     */
    function calculateProgress(uint256 raised, uint256 target) 
        internal 
        pure 
        returns (uint256 percentage) 
    {
        if (target == 0) return 0;
        return (raised * 10000) / target;
    }
    
    /**
     * @dev 计算平均购买金额
     * @param totalRaised 总筹集金额
     * @param totalPurchases 总购买次数
     * @return average 平均购买金额
     */
    function calculateAveragePurchase(uint256 totalRaised, uint256 totalPurchases) 
        internal 
        pure 
        returns (uint256 average) 
    {
        if (totalPurchases == 0) return 0;
        return totalRaised / totalPurchases;
    }
    
    /**
     * @dev 计算众筹成功概率
     * @param currentRaised 当前筹集金额
     * @param softCap 软顶目标
     * @param timeRemaining 剩余时间
     * @param totalDuration 总时长
     * @return probability 成功概率 (basis points)
     */
    function calculateSuccessProbability(
        uint256 currentRaised,
        uint256 softCap,
        uint256 timeRemaining,
        uint256 totalDuration
    ) internal pure returns (uint256 probability) {
        if (currentRaised >= softCap) return 10000; // 100%
        if (timeRemaining == 0) return 0;
        
        uint256 progressRate = (currentRaised * 10000) / (totalDuration - timeRemaining);
        uint256 requiredRate = (softCap * 10000) / totalDuration;
        
        if (progressRate >= requiredRate) {
            return 8000; // 80%
        } else if (progressRate >= requiredRate * 70 / 100) {
            return 6000; // 60%
        } else if (progressRate >= requiredRate * 50 / 100) {
            return 4000; // 40%
        } else {
            return 2000; // 20%
        }
    }
    
    /**
     * @dev 计算代币分布统计
     * @param purchases 购买记录数组
     * @return distribution 分布数据
     */
    function calculateTokenDistribution(uint256[] memory purchases) 
        internal 
        pure 
        returns (uint256[5] memory distribution) 
    {
        if (purchases.length == 0) return distribution;
        
        // 排序购买金额
        uint256[] memory sorted = _quickSort(purchases, 0, int256(purchases.length - 1));
        uint256 total = 0;
        
        for (uint256 i = 0; i < sorted.length; i++) {
            total += sorted[i];
        }
        
        // 计算分位数
        uint256 len = sorted.length;
        distribution[0] = sorted[0]; // 最小值
        distribution[1] = sorted[len * 25 / 100]; // 25%分位数
        distribution[2] = sorted[len * 50 / 100]; // 中位数
        distribution[3] = sorted[len * 75 / 100]; // 75%分位数
        distribution[4] = sorted[len - 1]; // 最大值
        
        return distribution;
    }
    
    /**
     * @dev 计算用户参与度评分
     * @param userStats 用户统计数据
     * @param crowdsaleStats 众筹统计数据
     * @return score 参与度评分 (0-100)
     */
    function calculateEngagementScore(
        UserStats memory userStats,
        AnalyticsData memory crowdsaleStats
    ) internal pure returns (uint256 score) {
        if (crowdsaleStats.totalParticipants == 0) return 0;
        
        uint256 purchaseScore = (userStats.purchaseCount * 30) / 
            (crowdsaleStats.totalPurchases / crowdsaleStats.totalParticipants);
        
        uint256 amountScore = (userStats.totalPurchased * 40) / 
            crowdsaleStats.averagePurchaseAmount;
        
        uint256 timeScore = userStats.firstPurchaseTime > 0 ? 20 : 0;
        uint256 whitelistScore = userStats.isWhitelisted ? 10 : 0;
        
        score = purchaseScore + amountScore + timeScore + whitelistScore;
        if (score > 100) score = 100;
    }
    
    /**
     * @dev 预测最终筹集金额
     * @param currentRaised 当前筹集金额
     * @param timeElapsed 已过时间
     * @param totalDuration 总时长
     * @return prediction 预测金额
     */
    function predictFinalAmount(
        uint256 currentRaised,
        uint256 timeElapsed,
        uint256 totalDuration
    ) internal pure returns (uint256 prediction) {
        if (timeElapsed == 0 || totalDuration == 0) return currentRaised;
        
        // 简单线性预测
        uint256 rate = currentRaised / timeElapsed;
        prediction = rate * totalDuration;
        
        // 应用衰减因子（后期增长通常放缓）
        uint256 decayFactor = 8000; // 80%
        prediction = (prediction * decayFactor) / 10000;
    }
    
    // ============ 内部工具函数 ============
    
    /**
     * @dev 快速排序算法
     */
    function _quickSort(uint256[] memory arr, int256 left, int256 right) 
        internal 
        pure 
        returns (uint256[] memory) 
    {
        if (left < right) {
            int256 pivotIndex = _partition(arr, left, right);
            _quickSort(arr, left, pivotIndex - 1);
            _quickSort(arr, pivotIndex + 1, right);
        }
        return arr;
    }
    
    /**
     * @dev 分区函数
     */
    function _partition(uint256[] memory arr, int256 left, int256 right) 
        internal 
        pure 
        returns (int256) 
    {
        uint256 pivot = arr[uint256(right)];
        int256 i = left - 1;
        
        for (int256 j = left; j < right; j++) {
            if (arr[uint256(j)] <= pivot) {
                i++;
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
            }
        }
        
        (arr[uint256(i + 1)], arr[uint256(right)]) = (arr[uint256(right)], arr[uint256(i + 1)]);
        return i + 1;
    }
    
    /**
     * @dev 计算标准差
     */
    function calculateStandardDeviation(uint256[] memory values, uint256 mean) 
        internal 
        pure 
        returns (uint256 stdDev) 
    {
        if (values.length <= 1) return 0;
        
        uint256 sumSquaredDiff = 0;
        for (uint256 i = 0; i < values.length; i++) {
            uint256 diff = values[i] > mean ? values[i] - mean : mean - values[i];
            sumSquaredDiff += diff * diff;
        }
        
        uint256 variance = sumSquaredDiff / (values.length - 1);
        stdDev = _sqrt(variance);
    }
    
    /**
     * @dev 计算平方根（巴比伦法）
     */
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    /**
     * @dev 计算复合增长率
     */
    function calculateCAGR(
        uint256 beginningValue,
        uint256 endingValue,
        uint256 periods
    ) internal pure returns (uint256 cagr) {
        if (beginningValue == 0 || periods == 0) return 0;
        
        // CAGR = (Ending Value / Beginning Value)^(1/periods) - 1
        // 简化计算，返回basis points
        if (endingValue > beginningValue) {
            uint256 growth = ((endingValue - beginningValue) * 10000) / beginningValue;
            cagr = growth / periods;
        } else {
            return 0;
        }
    }
}
