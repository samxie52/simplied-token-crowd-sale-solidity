import { configureChains, createConfig } from 'wagmi';
import { localhost, mainnet } from 'wagmi/chains';
import { InjectedConnector } from 'wagmi/connectors/injected';
import { MetaMaskConnector } from 'wagmi/connectors/metaMask';
import { WalletConnectConnector } from 'wagmi/connectors/walletConnect';
import { publicProvider } from 'wagmi/providers/public';
import { jsonRpcProvider } from 'wagmi/providers/jsonRpc';

// Get project ID from environment variables
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '';

const { chains, publicClient, webSocketPublicClient } = configureChains(
  [localhost, mainnet],
  [
    jsonRpcProvider({
      rpc: (chain) => {
        if (chain.id === localhost.id) {
          return { http: 'http://localhost:8545' };
        }
        return null;
      },
    }),
    publicProvider(),
  ]
);

export const config = createConfig({
  autoConnect: true,
  connectors: [
    new InjectedConnector({
      chains,
      options: {
        name: 'Injected',
        shimDisconnect: true,
      },
    }),
    new MetaMaskConnector({
      chains,
      options: {
        shimDisconnect: true,
      },
    }),
    ...(projectId ? [
      new WalletConnectConnector({
        chains,
        options: {
          projectId,
        },
      }),
    ] : []),
  ],
  publicClient,
  webSocketPublicClient,
});

export { chains };
