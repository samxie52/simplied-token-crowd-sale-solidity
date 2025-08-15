# Token Crowdsale Frontend

A modern Web3 frontend for the Token Crowdsale Platform built with React, TypeScript, and ethers.js.

## 🚀 Features

- **Web3 Integration**: Connect with MetaMask and other Web3 wallets
- **Real-time Data**: Live crowdsale statistics and progress tracking
- **Responsive Design**: Works on desktop and mobile devices
- **Type Safety**: Full TypeScript implementation
- **Modern UI**: Built with Tailwind CSS and Headless UI

## 🛠️ Tech Stack

- **Frontend**: React 18 + TypeScript
- **Build Tool**: Vite
- **Web3**: ethers.js v6
- **UI**: Tailwind CSS + Headless UI
- **State Management**: Zustand
- **Testing**: Vitest + React Testing Library
- **Icons**: Heroicons

## 📦 Installation

1. Install dependencies:
```bash
npm install
```

2. Copy environment variables:
```bash
cp .env.example .env
```

3. Update `.env` with your contract addresses and configuration

## 🔧 Development

Start the development server:
```bash
npm run dev
```

Run tests:
```bash
npm run test
```

Build for production:
```bash
npm run build
```

## 🌐 Environment Variables

```env
# Network Configuration
VITE_NETWORK_ID=31337
VITE_NETWORK_NAME=localhost

# Contract Addresses
VITE_CROWDSALEFACTORY_ADDRESS=0x...
VITE_TOKENCROWDSALE_ADDRESS=0x...
VITE_TOKENVESTING_ADDRESS=0x...

# Optional Services
VITE_INFURA_PROJECT_ID=your_infura_id
VITE_WALLETCONNECT_PROJECT_ID=your_walletconnect_id
```

## 📁 Project Structure

```
src/
├── components/          # Reusable UI components
│   ├── ui/             # Basic UI components
│   ├── wallet/         # Wallet-related components
│   ├── crowdsale/      # Crowdsale-specific components
│   └── common/         # Common layout components
├── hooks/              # Custom React hooks
├── stores/             # Zustand state management
├── types/              # TypeScript type definitions
├── utils/              # Utility functions
├── pages/              # Page components
└── tests/              # Test files
```

## 🔗 Smart Contract Integration

The frontend integrates with the following smart contracts:

- **CrowdsaleFactory**: Create and manage crowdsale instances
- **TokenCrowdsale**: Main crowdsale functionality
- **TokenVesting**: Token vesting and release
- **WhitelistManager**: Whitelist management
- **RefundVault**: Refund handling

## 🧪 Testing

Run the test suite:
```bash
# Run all tests
npm run test

# Run tests in watch mode
npm run test:watch

# Run tests with UI
npm run test:ui

# Generate coverage report
npm run test:coverage
```

## 🚀 Deployment

1. Build the project:
```bash
npm run build
```

2. Deploy the `dist` folder to your hosting service

### Recommended Hosting

- **Vercel**: Zero-config deployment
- **Netlify**: Easy static site hosting
- **IPFS**: Decentralized hosting

## 🔒 Security Considerations

- Never store private keys in the frontend
- Validate all user inputs
- Use HTTPS in production
- Implement proper error handling
- Keep dependencies updated

## 📚 Usage Guide

### Connecting Wallet

1. Click "Connect Wallet" button
2. Select MetaMask from the options
3. Approve the connection request
4. Switch to the correct network if prompted

### Participating in Crowdsales

1. Browse available crowdsales on the home page
2. Click "View Details" on a crowdsale
3. Enter the amount you want to invest
4. Confirm the transaction in your wallet
5. Wait for transaction confirmation

### Creating Crowdsales

1. Click "Create Crowdsale" button
2. Fill in the crowdsale parameters
3. Configure token vesting settings
4. Review and confirm the creation
5. Pay the creation fee and gas costs

## 🐛 Troubleshooting

### Common Issues

**Wallet not connecting:**
- Ensure MetaMask is installed and unlocked
- Check if you're on the correct network
- Refresh the page and try again

**Transactions failing:**
- Check your ETH balance for gas fees
- Ensure you're not exceeding purchase limits
- Verify you're whitelisted if required

**Data not loading:**
- Check your internet connection
- Verify contract addresses in `.env`
- Try refreshing the page

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For support and questions:
- Create an issue on GitHub
- Check the documentation
- Review the smart contract interfaces

---

Built with ❤️ for the decentralized future
