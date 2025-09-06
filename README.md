# Digital Collectible Card Game

A blockchain-based digital collectible card game built on the Stacks network using Clarity smart contracts.

## 🎮 Game Overview

Digital Collectible Card Game is a turn-based collectible card game where players can:
- Mint unique NFT cards with different stats and abilities
- Battle other players using their card collections
- Earn rewards and climb leaderboards
- Trade cards in a decentralized marketplace

## 🛠 Technology Stack

- **Blockchain**: Stacks Network
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Clarinet Test Framework
- **Version Control**: Git & GitHub

## 📋 Contract Overview

This project consists of two main smart contracts:

### 1. Card NFT Contract (`card-nft.clar`)
- Handles the creation and management of unique collectible cards
- Implements NFT functionality (minting, ownership, transfers)
- Manages card metadata and statistics
- Controls card supply and rarity

### 2. Battle Mechanics Contract (`battle-mechanics.clar`)
- Manages combat between player cards
- Implements battle logic and win/loss determination
- Tracks player statistics and rankings
- Handles reward distribution

## 🌿 Branch Structure

- **`main`**: Production-ready code and documentation
- **`development`**: Active development branch with latest features

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) - Clarity development tool
- [Node.js](https://nodejs.org/) - For running tests and development tools
- [Git](https://git-scm.com/) - Version control

### Installation
```bash
# Clone the repository
git clone https://github.com/samueladeboye/Digital-Collectible-Card-Game.git
cd Digital-Collectible-Card-Game

# Install dependencies
npm install

# Check contract syntax
clarinet check
```

### Running Tests
```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/card-nft_test.ts
```

## 📁 Project Structure

```
Digital-Collectible-Card-Game/
├── contracts/           # Clarity smart contracts
│   ├── card-nft.clar
│   └── battle-mechanics.clar
├── tests/              # Contract tests
├── settings/           # Network configurations
├── Clarinet.toml       # Project configuration
└── README.md           # This file
```

## 🎯 Core Features

### Card NFT Features
- **Mint Cards**: Create unique collectible cards with randomized stats
- **Transfer Cards**: Send cards between players
- **Card Metadata**: Store card attributes (attack, defense, health, rarity)
- **Supply Management**: Control total card supply and minting limits

### Battle System Features
- **Turn-Based Combat**: Strategic card battles between players
- **Stat-Based Outcomes**: Battle results determined by card statistics
- **Reward System**: Winners earn points and climb rankings
- **Battle History**: Track battle outcomes and statistics

## 🔧 Development

### Adding New Features
1. Create a feature branch from `development`
2. Implement your changes
3. Run tests: `clarinet test`
4. Submit a pull request to `development`

### Contract Development
- All contracts are written in Clarity
- Follow the existing code style and patterns
- Add comprehensive tests for new functionality
- Use `clarinet check` to validate syntax

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with [Clarinet](https://docs.hiro.so/clarinet) by Hiro
- Powered by the [Stacks](https://www.stacks.co/) blockchain
- Inspired by classic trading card games

## 📞 Support

For questions and support, please open an issue in this repository.

---

**Happy Gaming! 🎲**
