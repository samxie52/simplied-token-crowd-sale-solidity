import React, { useState, useEffect } from 'react';
import { formatEther, parseEther } from 'ethers';
import { Button } from '@/components/ui/Button';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { useWallet } from '@/hooks/useWallet';
import { useCrowdsale } from '@/hooks/useCrowdsale';
import { formatTokenAmount, formatEther as formatEtherUtil } from '@/utils/formatters';
import { 
  CurrencyDollarIcon, 
  ExclamationTriangleIcon,
  CheckCircleIcon,
  ArrowPathIcon 
} from '@heroicons/react/24/outline';

interface PurchaseFormProps {
  crowdsaleAddress: string;
  className?: string;
}

export const PurchaseForm: React.FC<PurchaseFormProps> = ({
  crowdsaleAddress,
  className = ''
}) => {
  const { isConnected, balance, address } = useWallet();
  const { 
    purchaseTokens, 
    isPurchasing, 
    config, 
    isLoading, 
    checkWhitelistStatus,
    getCrowdsaleContract 
  } = useCrowdsale(crowdsaleAddress);
  
  const [ethAmount, setEthAmount] = useState('');
  const [tokenAmount, setTokenAmount] = useState('');
  const [errors, setErrors] = useState<string[]>([]);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [tokenPrice, setTokenPrice] = useState('0');
  const [userWhitelistStatus, setUserWhitelistStatus] = useState<{
    isWhitelisted: boolean;
    tier: 'VIP' | 'WHITELISTED' | 'NONE';
    discount: number;
  } | null>(null);
  const [loadingPrice, setLoadingPrice] = useState(false);

  // 计算实际价格（考虑折扣）
  const actualPrice = userWhitelistStatus?.isWhitelisted 
    ? parseFloat(tokenPrice) * (1 - userWhitelistStatus.discount / 100)
    : parseFloat(tokenPrice);

  // 获取购买限制
  const minPurchase = config ? formatEther(config.minPurchase) : '0.01';
  const maxPurchase = config ? formatEther(config.maxPurchase) : '10';

  // 获取代币价格和白名单状态
  useEffect(() => {
    const fetchPriceAndWhitelist = async () => {
      if (!address || !crowdsaleAddress) return;
      
      setLoadingPrice(true);
      try {
        const contract = await getCrowdsaleContract(crowdsaleAddress);
        if (!contract) return;
        
        // 获取用户的代币价格（考虑白名单折扣）
        const [userPrice, whitelistStatus] = await Promise.all([
          contract.getTokenPriceForUser(address),
          checkWhitelistStatus(address)
        ]);
        
        setTokenPrice(formatEther(userPrice));
        setUserWhitelistStatus(whitelistStatus);
      } catch (error) {
        console.error('Failed to fetch price and whitelist:', error);
        // 回退到基础价格
        try {
          const contract = await getCrowdsaleContract(crowdsaleAddress);
          if (contract) {
            const basePrice = await contract.getCurrentTokenPrice();
            setTokenPrice(formatEther(basePrice));
          }
        } catch (fallbackError) {
          console.error('Failed to fetch base price:', fallbackError);
          setTokenPrice('0.0001'); // 默认价格
        }
      } finally {
        setLoadingPrice(false);
      }
    };
    
    fetchPriceAndWhitelist();
  }, [address, crowdsaleAddress, getCrowdsaleContract, checkWhitelistStatus]);

  // ETH金额变化时计算代币数量和验证
  useEffect(() => {
    if (ethAmount && !isNaN(parseFloat(ethAmount)) && actualPrice > 0) {
      const tokens = parseFloat(ethAmount) / actualPrice;
      setTokenAmount(tokens.toFixed(6));
      
      // 实时验证
      const validationErrors = validateInput();
      setErrors(validationErrors);
    } else {
      setTokenAmount('');
      setErrors([]);
    }
  }, [ethAmount, actualPrice, balance, minPurchase, maxPurchase]);

  // 代币数量变化时计算ETH金额
  const handleTokenAmountChange = (value: string) => {
    setTokenAmount(value);
    if (value && !isNaN(parseFloat(value))) {
      const eth = parseFloat(value) * actualPrice;
      setEthAmount(eth.toFixed(6));
    } else {
      setEthAmount('');
    }
  };

  // 验证输入
  const validateInput = (): string[] => {
    const errors: string[] = [];
    const ethValue = parseFloat(ethAmount);
    // Balance is already in Ether format as a string, no need to format
    const userBalance = balance ? parseFloat(balance) : 0;

    if (!ethAmount || ethValue <= 0) {
      errors.push('请输入有效的ETH金额');
    }

    if (ethValue < parseFloat(minPurchase)) {
      errors.push(`最小购买金额为 ${minPurchase} ETH`);
    }

    if (ethValue > parseFloat(maxPurchase)) {
      errors.push(`最大购买金额为 ${maxPurchase} ETH`);
    }

    if (ethValue > userBalance) {
      errors.push('余额不足');
    }

    // 预留Gas费用
    if (ethValue > userBalance - 0.01) {
      errors.push('请预留Gas费用（约0.01 ETH）');
    }

    return errors;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    const validationErrors = validateInput();
    setErrors(validationErrors);
    
    if (validationErrors.length > 0) {
      return;
    }

    setShowConfirmation(true);
  };

  const handleConfirmPurchase = async () => {
    try {
      setShowConfirmation(false);
      await purchaseTokens(ethAmount);
      
      // 重置表单
      setEthAmount('');
      setTokenAmount('');
      setErrors([]);
    } catch (error) {
      console.error('Purchase failed:', error);
      setErrors(['购买失败，请重试']);
    }
  };

  const getDiscountBadge = () => {
    if (!userWhitelistStatus?.isWhitelisted) return null;
    
    const { tier, discount } = userWhitelistStatus;
    const badgeColors = {
      VIP: 'bg-purple-100 text-purple-800 border-purple-200',
      WHITELISTED: 'bg-blue-100 text-blue-800 border-blue-200',
      NONE: ''
    };

    return (
      <div className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium border ${badgeColors[tier]}`}>
        <CheckCircleIcon className="h-3 w-3 mr-1" />
        {tier === 'VIP' ? 'VIP用户' : '白名单用户'} -{discount}%
      </div>
    );
  };

  if (!isConnected) {
    return (
      <Card className={className}>
        <CardContent className="p-6 text-center">
          <CurrencyDollarIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 dark:text-gray-400 mb-4">
            请先连接钱包以参与众筹
          </p>
          <Button variant="primary" size="lg">
            连接钱包
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={className}>
      <CardHeader>
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
            购买代币
          </h3>
          {getDiscountBadge()}
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        {/* 价格信息 */}
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm text-gray-600 dark:text-gray-400">代币价格</span>
            <div className="flex items-center gap-2">
              {loadingPrice ? (
                <ArrowPathIcon className="h-4 w-4 animate-spin text-gray-400" />
              ) : (
                <span className="font-medium">
                  {actualPrice.toFixed(6)} ETH
                  {userWhitelistStatus?.isWhitelisted && (
                    <span className="text-green-600 text-xs ml-2">
                      (原价: {parseFloat(tokenPrice).toFixed(6)} ETH)
                    </span>
                  )}
                </span>
              )}
            </div>
          </div>
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm text-gray-600 dark:text-gray-400">钱包余额</span>
            <span className="font-medium">{formatEtherUtil(balance || '0')} ETH</span>
          </div>
          {config && (
            <>
              <div className="flex justify-between items-center mb-1">
                <span className="text-sm text-gray-600 dark:text-gray-400">购买限制</span>
                <span className="text-sm font-medium">
                  {minPurchase} - {maxPurchase} ETH
                </span>
              </div>
            </>
          )}
        </div>

        {/* 购买表单 */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* ETH金额输入 */}
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                支付金额 (ETH)
              </label>
              <div className="relative">
                <input
                  type="number"
                  step="0.000001"
                  min="0"
                  value={ethAmount}
                  onChange={(e) => setEthAmount(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                  placeholder="0.0"
                />
                <button
                  type="button"
                  onClick={() => {
                    const maxAmount = Math.min(
                      parseFloat(balance || '0') - 0.01, // 预留Gas费
                      parseFloat(maxPurchase)
                    );
                    setEthAmount(Math.max(0, maxAmount).toFixed(6));
                  }}
                  className="absolute right-2 top-1/2 transform -translate-y-1/2 text-xs text-blue-600 hover:text-blue-800"
                  disabled={!balance}
                >
                  最大
                </button>
              </div>
            </div>

            {/* 代币数量显示 */}
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                获得代币
              </label>
              <input
                type="number"
                step="0.000001"
                min="0"
                value={tokenAmount}
                onChange={(e) => handleTokenAmountChange(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                placeholder="0.0"
              />
            </div>
          </div>

          {/* 快速金额选择 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              快速选择
            </label>
            <div className="grid grid-cols-4 gap-2">
              {['0.1', '0.5', '1.0', '5.0'].map((amount) => (
                <button
                  key={amount}
                  type="button"
                  onClick={() => setEthAmount(amount)}
                  className="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
                  {amount} ETH
                </button>
              ))}
            </div>
          </div>

          {/* 错误信息 */}
          {errors.length > 0 && (
            <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-md p-3">
              <div className="flex">
                <ExclamationTriangleIcon className="h-5 w-5 text-red-400 mr-2 flex-shrink-0" />
                <div>
                  {errors.map((error, index) => (
                    <p key={index} className="text-sm text-red-600 dark:text-red-400">
                      {error}
                    </p>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* 购买按钮 */}
          <Button
            type="submit"
            variant="primary"
            size="lg"
            className="w-full"
            disabled={isPurchasing || !ethAmount || errors.length > 0 || isLoading || loadingPrice || !config}
            loading={isPurchasing}
          >
            {isPurchasing ? '处理中...' : 
             isLoading || loadingPrice ? '加载中...' :
             !config ? '众筹数据加载中...' :
             '购买代币'}
          </Button>
        </form>

          {/* 购买限制提示 */}
        <div className="text-xs text-gray-500 dark:text-gray-400 space-y-1">
          <p>• 最小购买金额: {minPurchase} ETH</p>
          <p>• 最大购买金额: {maxPurchase} ETH</p>
          <p>• 请预留足够的Gas费用</p>
          {userWhitelistStatus?.isWhitelisted && (
            <p className="text-green-600">• 您享有 {userWhitelistStatus.discount}% 的白名单折扣</p>
          )}
          {isLoading && (
            <p className="text-blue-600">• 正在加载众筹数据...</p>
          )}
        </div>
      </CardContent>

      {/* 确认对话框 */}
      {showConfirmation && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              确认购买
            </h3>
            <div className="space-y-3 mb-6">
              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">支付金额:</span>
                <span className="font-medium">{ethAmount} ETH</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">获得代币:</span>
                <span className="font-medium">{formatTokenAmount(tokenAmount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600 dark:text-gray-400">单价:</span>
                <span className="font-medium">{actualPrice.toFixed(6)} ETH</span>
              </div>
              {userWhitelistStatus?.isWhitelisted && (
                <div className="flex justify-between text-green-600">
                  <span>折扣:</span>
                  <span>-{userWhitelistStatus.discount}%</span>
                </div>
              )}
            </div>
            <div className="flex space-x-3">
              <Button
                variant="secondary"
                onClick={() => setShowConfirmation(false)}
                className="flex-1"
              >
                取消
              </Button>
              <Button
                variant="primary"
                onClick={handleConfirmPurchase}
                className="flex-1"
                loading={isPurchasing}
              >
                确认购买
              </Button>
            </div>
          </div>
        </div>
      )}
    </Card>
  );
};
