# Gasless Gossip Smart Contracts


## Overview

Gasless Gossip is a decentralized messaging application that enables users to send messages and transfer tokens seamlessly within conversations. Built on StarkNet, Gasless Gossip leverages Layer 2 scaling to provide near-zero gas fees while maintaining the security guarantees of Ethereum.

This repository contains the smart contracts that power the Gasless Gossip protocol, including messaging, token transfers, and user profiles.


## Architecture

Gasless Gossip's contract architecture is designed with the following principles:

- **Modularity**: Separate contracts for messaging, profile management, and token transfers
- **Upgradability**: Proxy pattern implementation for future improvements
- **Efficiency**: Optimized for minimal gas consumption on StarkNet
- **Security**: Thorough testing and security measures

## Contract Structure

The smart contracts in this repository include:


## Getting Started

### Prerequisites

- [Cairo 1.0](https://book.cairo-lang.org/ch01-01-installation.html) or later
- [Scarb](https://docs.swmansion.com/scarb/download.html) - Cairo package manager
- [StarkNet CLI](https://www.cairo-lang.org/docs/hello_starknet/index.html#installation)
- [Python 3.7+](https://www.python.org/downloads/) (for testing scripts)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/gaslessgossip/contracts.git
   cd contracts
   ```

2. Install dependencies:
   ```bash
   scarb install
   ```

3. Install Python requirements (for testing):
   ```bash
   pip install -r requirements.txt
   ```

## Development

### Building Contracts

To build the contracts:

```bash
scarb build
```

The compiled contracts will be available in the `target/` directory.

### Environment Configuration

Create a `.env` file based on the `.env.example`:

```bash
cp .env.example .env
# Edit .env with your configuration
```


## Testing

### Running Tests

Run the test suite:

```bash
scarb test
```

For more verbose output:

```bash
scarb test -- --verbose
```

### Coverage

Generate test coverage report:

```bash
scarb test-coverage
```

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

