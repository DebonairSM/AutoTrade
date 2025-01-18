# Trading Framework

A comprehensive MQL4/MQL5 trading framework for developing and managing trading strategies.

## Directory Structure

```
├── src/                        # Shared framework code
│   ├── experts/
│   │   └── base/              # Base classes for Expert Advisors
│   ├── indicators/
│   │   └── base/              # Base classes for Custom Indicators
│   ├── scripts/
│   │   └── base/              # Base classes for Scripts
│   ├── include/               # Common include files
│   │   ├── utils/             # Utility functions
│   │   ├── constants/         # Constants and enums
│   │   └── interfaces/        # Interfaces/abstract classes
│   └── libraries/             # Reusable libraries
│
├── applications/
│   ├── experts/
│   │   ├── mql5/             # Primary MQL5 expert advisors
│   │   │   ├── trend_following/
│   │   │   ├── scalping/
│   │   │   └── mean_reversion/
│   │   │
│   │   └── mql4/             # MQL4 expert advisors
│   │       └── legacy_expert/ 
│   │
│   ├── indicators/           # MQL5 indicators
│   │   ├── trend/
│   │   ├── momentum/
│   │   └── volatility/
│   │
│   └── scripts/             # MQL5 utility scripts
│
├── tests/                   # Test framework
│   └── include/            # Test utilities
│
└── docs/                   # Documentation
    ├── api/
    └── examples/
```

## Overview

This trading framework provides a structured approach to developing trading solutions in both MQL4 and MQL5. It separates core functionality from specific implementations and promotes code reuse through a modular design.

### Key Components

- **src/**: Contains all shared framework code and base classes
- **applications/**: Houses the actual trading solutions (EAs, indicators, scripts)
- **tests/**: Framework for testing trading strategies
- **docs/**: Framework documentation and examples

## Getting Started

1. Clone this repository
2. Set up your development environment with MetaTrader 4/5
3. Link the framework to your MetaTrader data folder
4. Start developing your trading solutions in the appropriate directories

## Best Practices

- Inherit from base classes when creating new Expert Advisors
- Keep common utilities in the utils directory
- Document your code and maintain examples
- Use the testing framework for strategy validation 