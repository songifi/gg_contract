# Gasless Gossip Smart Contracts

## Overview

Gasless Gossip is a decentralized messaging application that enables users to manage friend relationships and privacy on StarkNet. This repository contains the smart contracts for friend management and related features.

## Architecture

- **Modularity**: Contracts are organized by feature (e.g., friend management)
- **Efficiency**: Optimized for minimal gas consumption on StarkNet
- **Security**: Thorough testing and security measures

## Contract Structure

All contract source files are located in the `src/` directory. Tests are located in the `tests/` directory.

## Getting Started

### Prerequisites

- [Cairo 1.0](https://book.cairo-lang.org/ch01-01-installation.html) or later
- [Scarb](https://docs.swmansion.com/scarb/download.html) - Cairo package manager
- [StarkNet Foundry (snforge)](https://github.com/foundry-rs/starknet-foundry) for advanced testing

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/songifi/gg_contract.git
   cd contracts
   ```

2. Install dependencies:
   ```bash
   scarb build
   ```

## Development

### Building Contracts

To build the contracts:

```bash
scarb build
```

The compiled contracts will be available in the `target/` directory.

## Testing

### Running Tests

Run the test suite:

```bash
snforge test
```

Test files are located in the `tests/` directory.

## Continuous Integration

This repository uses GitHub Actions for CI. The workflow automatically builds and tests contracts on every push and pull request to any branch. See `.github/workflows/ci.yml` for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
