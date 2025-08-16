import React from 'react';
import { Dialog, Transition } from '@headlessui/react';
import { Fragment } from 'react';
import { UserInvestment } from '@/hooks/useUserInvestments';
import { formatDate, formatEther } from '@/utils/formatters';
import { 
  XMarkIcon,
  CurrencyDollarIcon,
  ChartBarIcon,
  CalendarIcon,
  ArrowTopRightOnSquareIcon,
  DocumentDuplicateIcon
} from '@heroicons/react/24/outline';
import { Button } from '@/components/ui/Button';

interface InvestmentDetailModalProps {
  investment: UserInvestment | null;
  isOpen: boolean;
  onClose: () => void;
}

export const InvestmentDetailModal: React.FC<InvestmentDetailModalProps> = ({
  investment,
  isOpen,
  onClose,
}) => {
  if (!investment) return null;

  const profitColor = parseFloat(investment.profitLoss) >= 0 ? 'text-green-600' : 'text-red-600';
  const profitBgColor = parseFloat(investment.profitLoss) >= 0 ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200';

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const openEtherscan = (hash: string) => {
    // For local development, this would open a block explorer
    // In production, use the appropriate explorer URL
    window.open(`https://etherscan.io/tx/${hash}`, '_blank');
  };

  return (
    <Transition appear show={isOpen} as={Fragment}>
      <Dialog as="div" className="relative z-50" onClose={onClose}>
        <Transition.Child
          as={Fragment}
          enter="ease-out duration-300"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in duration-200"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black bg-opacity-25" />
        </Transition.Child>

        <div className="fixed inset-0 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4 text-center">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                <div className="flex justify-between items-start mb-4">
                  <Dialog.Title as="h3" className="text-lg font-semibold text-gray-900">
                    投资详情
                  </Dialog.Title>
                  <button
                    onClick={onClose}
                    className="text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    <XMarkIcon className="h-6 w-6" />
                  </button>
                </div>

                <div className="space-y-4">
                  {/* Project Info */}
                  <div className="bg-gray-50 rounded-lg p-4">
                    <h4 className="font-medium text-gray-900 mb-2">{investment.crowdsaleName}</h4>
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <span>代币: {investment.tokenSymbol}</span>
                      <button
                        onClick={() => copyToClipboard(investment.tokenAddress)}
                        className="flex items-center gap-1 hover:text-blue-600 transition-colors"
                      >
                        <DocumentDuplicateIcon className="h-4 w-4" />
                      </button>
                    </div>
                  </div>

                  {/* Investment Details */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="flex items-start gap-3">
                      <CurrencyDollarIcon className="h-5 w-5 text-blue-500 mt-0.5" />
                      <div>
                        <p className="text-sm text-gray-500">投资金额</p>
                        <p className="font-semibold text-gray-900">{formatEther(investment.investedAmount)} ETH</p>
                      </div>
                    </div>
                    
                    <div className="flex items-start gap-3">
                      <ChartBarIcon className="h-5 w-5 text-green-500 mt-0.5" />
                      <div>
                        <p className="text-sm text-gray-500">获得代币</p>
                        <p className="font-semibold text-gray-900">{formatEther(investment.tokenAmount)} {investment.tokenSymbol}</p>
                      </div>
                    </div>
                    
                    <div className="flex items-start gap-3">
                      <CalendarIcon className="h-5 w-5 text-purple-500 mt-0.5" />
                      <div>
                        <p className="text-sm text-gray-500">投资时间</p>
                        <p className="font-semibold text-gray-900">{formatDate(investment.investmentDate)}</p>
                      </div>
                    </div>
                    
                    <div className="flex items-start gap-3">
                      <div className={`h-5 w-5 rounded-full mt-0.5 ${
                        investment.status === 'active' ? 'bg-green-500' :
                        investment.status === 'completed' ? 'bg-blue-500' : 'bg-red-500'
                      }`} />
                      <div>
                        <p className="text-sm text-gray-500">状态</p>
                        <p className="font-semibold text-gray-900">
                          {investment.status === 'active' ? '进行中' :
                           investment.status === 'completed' ? '已完成' : '已退款'}
                        </p>
                      </div>
                    </div>
                  </div>

                  {/* Current Value & Profit */}
                  <div className={`rounded-lg p-4 border ${profitBgColor}`}>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-sm text-gray-600 mb-1">当前价值</p>
                        <p className="text-xl font-bold text-gray-900">${investment.currentValue}</p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600 mb-1">收益</p>
                        <div>
                          <p className={`text-xl font-bold ${profitColor}`}>
                            ${investment.profitLoss}
                          </p>
                          <p className={`text-sm ${profitColor}`}>
                            ({investment.profitLossPercentage > 0 ? '+' : ''}{investment.profitLossPercentage.toFixed(2)}%)
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Transaction Hash */}
                  {investment.transactionHash && (
                    <div className="bg-gray-50 rounded-lg p-4">
                      <p className="text-sm text-gray-500 mb-2">交易哈希</p>
                      <div className="flex items-center gap-2">
                        <code className="text-xs bg-white px-2 py-1 rounded border flex-1 truncate">
                          {investment.transactionHash}
                        </code>
                        <button
                          onClick={() => copyToClipboard(investment.transactionHash)}
                          className="text-gray-400 hover:text-blue-600 transition-colors"
                        >
                          <DocumentDuplicateIcon className="h-4 w-4" />
                        </button>
                        <button
                          onClick={() => openEtherscan(investment.transactionHash)}
                          className="text-gray-400 hover:text-blue-600 transition-colors"
                        >
                          <ArrowTopRightOnSquareIcon className="h-4 w-4" />
                        </button>
                      </div>
                    </div>
                  )}
                </div>

                <div className="mt-6 flex justify-end">
                  <Button onClick={onClose} variant="outline">
                    关闭
                  </Button>
                </div>
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
};
