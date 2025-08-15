import React, { useState, useEffect } from 'react';
import { ClockIcon } from '@heroicons/react/24/outline';

interface CountdownTimerProps {
  endTime: number; // Unix timestamp
  onComplete?: () => void;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
}

interface TimeLeft {
  days: number;
  hours: number;
  minutes: number;
  seconds: number;
}

export const CountdownTimer: React.FC<CountdownTimerProps> = ({
  endTime,
  onComplete,
  className = '',
  size = 'md'
}) => {
  const [timeLeft, setTimeLeft] = useState<TimeLeft>({ days: 0, hours: 0, minutes: 0, seconds: 0 });
  const [isExpired, setIsExpired] = useState(false);

  useEffect(() => {
    const calculateTimeLeft = () => {
      const now = Math.floor(Date.now() / 1000);
      const difference = endTime - now;

      if (difference <= 0) {
        setIsExpired(true);
        setTimeLeft({ days: 0, hours: 0, minutes: 0, seconds: 0 });
        onComplete?.();
        return;
      }

      const days = Math.floor(difference / (24 * 60 * 60));
      const hours = Math.floor((difference % (24 * 60 * 60)) / (60 * 60));
      const minutes = Math.floor((difference % (60 * 60)) / 60);
      const seconds = difference % 60;

      setTimeLeft({ days, hours, minutes, seconds });
    };

    calculateTimeLeft();
    const timer = setInterval(calculateTimeLeft, 1000);

    return () => clearInterval(timer);
  }, [endTime, onComplete]);

  const sizeClasses = {
    sm: {
      container: 'text-sm',
      number: 'text-lg',
      label: 'text-xs'
    },
    md: {
      container: 'text-base',
      number: 'text-2xl',
      label: 'text-sm'
    },
    lg: {
      container: 'text-lg',
      number: 'text-3xl',
      label: 'text-base'
    }
  };

  const classes = sizeClasses[size];

  if (isExpired) {
    return (
      <div className={`flex items-center justify-center p-4 bg-red-50 dark:bg-red-900/20 rounded-lg ${className}`}>
        <ClockIcon className="h-6 w-6 text-red-500 mr-2" />
        <span className="text-red-600 dark:text-red-400 font-medium">
          众筹已结束
        </span>
      </div>
    );
  }

  return (
    <div className={`${classes.container} ${className}`}>
      <div className="flex items-center justify-center mb-2">
        <ClockIcon className="h-5 w-5 text-gray-500 mr-2" />
        <span className="text-gray-600 dark:text-gray-400 font-medium">
          剩余时间
        </span>
      </div>
      
      <div className="grid grid-cols-4 gap-2 text-center">
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className={`font-bold text-blue-600 dark:text-blue-400 ${classes.number}`}>
            {timeLeft.days.toString().padStart(2, '0')}
          </div>
          <div className={`text-gray-500 dark:text-gray-400 ${classes.label}`}>
            天
          </div>
        </div>
        
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className={`font-bold text-blue-600 dark:text-blue-400 ${classes.number}`}>
            {timeLeft.hours.toString().padStart(2, '0')}
          </div>
          <div className={`text-gray-500 dark:text-gray-400 ${classes.label}`}>
            时
          </div>
        </div>
        
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className={`font-bold text-blue-600 dark:text-blue-400 ${classes.number}`}>
            {timeLeft.minutes.toString().padStart(2, '0')}
          </div>
          <div className={`text-gray-500 dark:text-gray-400 ${classes.label}`}>
            分
          </div>
        </div>
        
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className={`font-bold text-blue-600 dark:text-blue-400 ${classes.number}`}>
            {timeLeft.seconds.toString().padStart(2, '0')}
          </div>
          <div className={`text-gray-500 dark:text-gray-400 ${classes.label}`}>
            秒
          </div>
        </div>
      </div>
    </div>
  );
};
