import { BrowserRouter } from 'react-router-dom';
import { AppRouter } from './router';
import ErrorBoundary from './components/ErrorBoundary';
import './App.css';
import './styles/globals.css';

function App() {
  return (
    <ErrorBoundary>
      <BrowserRouter>
        <div className="min-h-screen bg-gray-50">
          <AppRouter />
        </div>
      </BrowserRouter>
    </ErrorBoundary>
  );
}

export default App;
