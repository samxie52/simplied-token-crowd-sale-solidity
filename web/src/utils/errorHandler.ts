/**
 * 合约错误处理工具
 * 统一处理各种合约交互错误并返回用户友好的错误信息
 */

export const handleContractError = (error: any): string => {
  console.error('Contract error:', error);

  // 常见错误类型处理
  if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
    return '交易可能失败，请检查参数或网络状态';
  }
  
  if (error.code === 'INSUFFICIENT_FUNDS') {
    return 'ETH余额不足支付Gas费用';
  }
  
  if (error.code === 'USER_REJECTED') {
    return '用户取消了交易';
  }
  
  if (error.code === 'NETWORK_ERROR') {
    return '网络连接错误，请检查网络状态';
  }

  if (error.code === 'CALL_EXCEPTION') {
    return '合约调用失败，请检查网络或合约状态';
  }

  // 合约特定错误
  if (error.message?.includes('AccessControl')) {
    return '权限不足，无法执行此操作';
  }
  
  if (error.message?.includes('Pausable: paused')) {
    return '合约已暂停，无法执行此操作';
  }
  
  if (error.message?.includes('Crowdsale: not active')) {
    return '众筹未激活或已结束';
  }

  if (error.message?.includes('Whitelist: already whitelisted')) {
    return '用户已在白名单中';
  }

  if (error.message?.includes('Whitelist: not whitelisted')) {
    return '用户不在白名单中';
  }

  if (error.message?.includes('Invalid address')) {
    return '无效的地址格式';
  }

  if (error.message?.includes('execution reverted')) {
    // 尝试提取具体的revert原因
    const revertReason = error.message.match(/execution reverted: (.+)/)?.[1];
    if (revertReason) {
      return `交易失败: ${revertReason}`;
    }
    return '交易被合约拒绝，请检查参数';
  }

  // 返回原始错误信息或默认消息
  return error.message || '交易失败，请重试';
};

/**
 * 检查是否为网络错误
 */
export const isNetworkError = (error: any): boolean => {
  return error.code === 'NETWORK_ERROR' || 
         error.code === 'TIMEOUT' ||
         error.message?.includes('network');
};

/**
 * 检查是否为用户拒绝错误
 */
export const isUserRejectedError = (error: any): boolean => {
  return error.code === 'USER_REJECTED' || 
         error.code === 4001 ||
         error.message?.includes('User denied');
};

/**
 * 检查是否为权限错误
 */
export const isPermissionError = (error: any): boolean => {
  return error.message?.includes('AccessControl') ||
         error.message?.includes('Ownable') ||
         error.message?.includes('permission') ||
         error.message?.includes('unauthorized');
};

/**
 * 格式化交易错误信息
 */
export const formatTransactionError = (error: any, operation: string): string => {
  const baseMessage = handleContractError(error);
  return `${operation}失败: ${baseMessage}`;
};
