/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_NETWORK_ID: string
  readonly VITE_FACTORY_ADDRESS: string
  readonly VITE_CROWDSALEFACTORY_ADDRESS: string
  readonly VITE_REFRESH_INTERVAL: string
  readonly VITE_TRANSACTION_TIMEOUT: string
  readonly VITE_INFURA_PROJECT_ID: string
  readonly VITE_WALLETCONNECT_PROJECT_ID: string
  readonly VITE_ETHERSCAN_API_KEY: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
