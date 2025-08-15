import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { Layout } from '../components/common/Layout';
import { Home } from '../pages/Home';
import { CrowdsaleDetail } from '../pages/CrowdsaleDetail';
import { Dashboard } from '../pages/Dashboard';
import { TransactionHistory } from '../pages/TransactionHistory';
import { AdminPanel } from '../pages/AdminPanel';

export const AppRouter: React.FC = () => {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/crowdsale/:address" element={<CrowdsaleDetail />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/transactions" element={<TransactionHistory />} />
        <Route path="/admin" element={<AdminPanel />} />
      </Routes>
    </Layout>
  );
};
