import { Toaster } from 'react-hot-toast';
import { Layout } from '@/components/common/Layout';
import { Home } from '@/pages/Home';
import '@/styles/globals.css';

function App() {
  return (
    <>
      <Layout>
        <Home />
      </Layout>
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 5000,
          style: {
            background: '#363636',
            color: '#fff',
          },
          success: {
            duration: 3000,
            iconTheme: {
              primary: '#10b981',
              secondary: '#fff',
            },
          },
          error: {
            duration: 5000,
            iconTheme: {
              primary: '#ef4444',
              secondary: '#fff',
            },
          },
        }}
      />
    </>
  );
}

export default App;
