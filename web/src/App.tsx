import { BrowserRouter } from 'react-router-dom';
import { WagmiConfig } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AppRouter } from './router';
import ErrorBoundary from './components/ErrorBoundary';
import { config } from './config/wagmi';
import './App.css';
import './styles/globals.css';

const queryClient = new QueryClient();

function App() {
  return (
    <ErrorBoundary>
      <WagmiConfig config={config}>
        <QueryClientProvider client={queryClient}>
          <BrowserRouter>
            <div className="min-h-screen bg-gray-50">
              <AppRouter />
            </div>
          </BrowserRouter>
        </QueryClientProvider>
      </WagmiConfig>
    </ErrorBoundary>
  );
}

export default App;
