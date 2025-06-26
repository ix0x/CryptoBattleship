# CryptoBattleship V2 New Functions Reference

This document provides detailed reference for all new and modified functions introduced in the V2 tokenomics upgrade.

---

## Table of Contents

1. [TokenomicsCore.sol Updates](#tokenomicscore-contract-updates)
2. [StakingPool.sol Updates](#stakingpool-contract-updates)
3. [Modified Function Signatures](#modified-function-signatures)
4. [New Data Structures](#new-data-structures)

---

## TokenomicsCore Contract Updates

### Dynamic Emission Functions

#### `calculateDynamicEmissions(uint256 epoch) public view returns (uint256)`
- **Purpose**: Calculate total emissions for an epoch using dynamic formula
- **Parameters**: 
  - `epoch`: Epoch number to calculate emissions for
- **Returns**: `totalEmission` - Total emission amount (base + revenue bonus)
- **Formula**: `baseEmission + (previousEpochRevenue * multiplier)`
- **Access**: Public view function
- **Gas**: ~10,000 gas

**Example Usage:**
```solidity
uint256 nextEmission = tokenomicsCore.calculateDynamicEmissions(currentEpoch + 1);
```

#### `setEmissionRevenueMultiplier(uint256 multiplier) external onlyOwner`
- **Purpose**: Configure the revenue multiplier for dynamic emissions
- **Parameters**: 
  - `multiplier`: Percentage of previous week revenue to add (0-50%)
- **Access**: Owner only
- **Validation**: Multiplier must be ≤ 50%
- **Gas**: ~25,000 gas

**Example Usage:**
```solidity
// Set 15% of previous week revenue as emission bonus
tokenomicsCore.setEmissionRevenueMultiplier(15);
```

### Multi-Token Revenue Functions

#### `recordMultiTokenRevenue(address token, uint256 amount) external`
- **Purpose**: Record and distribute multi-token revenue directly to stakeholders
- **Parameters**: 
  - `token`: Revenue token contract address
  - `amount`: Amount of revenue to distribute
- **Access**: Authorized minters only
- **Distribution**: 70% staking, 20% team, 10% liquidity
- **Gas**: ~80,000 gas

**Example Usage:**
```solidity
// Record 1000 USDC revenue from marketplace fees
tokenomicsCore.recordMultiTokenRevenue(usdcAddress, 1000e6);
```

### Enhanced Emission Processing

#### `processWeeklyEmissions(uint256 epoch) external`
- **Purpose**: Process weekly emissions with linear payout setup
- **Parameters**: 
  - `epoch`: Epoch to process emissions for
- **Access**: Automation admins or owner
- **Enhancements**: Now sets up linear payout over following week
- **Gas**: ~120,000 gas

**New Features:**
- Sets up `EmissionEpochInfo` for linear distribution
- Records epoch start time for payout calculations
- Maintains backward compatibility

### Enhanced View Functions

#### `getClaimableEmissions(address player) external view returns (uint256 liquid, uint256 vested)`
- **Purpose**: Calculate claimable emissions with linear payout consideration
- **Parameters**: 
  - `player`: Player address to check
- **Returns**: 
  - `liquid`: Immediately claimable liquid tokens
  - `vested`: Vested tokens that will be locked
- **Enhancement**: Now considers time-based linear unlocking
- **Gas**: ~50,000 gas per epoch processed

---

## StakingPool Contract Updates

### Multi-Token Revenue Functions

#### `addRevenueToken(address token) external onlyOwner`
- **Purpose**: Add a new token as supported revenue token
- **Parameters**: 
  - `token`: Token contract address to add
- **Access**: Owner only
- **Validation**: Non-zero address, not already supported
- **Gas**: ~45,000 gas

**Example Usage:**
```solidity
// Add USDC as supported revenue token
stakingPool.addRevenueToken(0xA0b86a33E6441e08c5b90c28e62b0e35b6ceF06d);
```

#### `addRevenueToPool(address token, uint256 amount) external`
- **Purpose**: Add multi-token revenue to the staking pool
- **Parameters**: 
  - `token`: Revenue token address
  - `amount`: Amount to add to pool
- **Access**: TokenomicsCore or owner
- **Validation**: Token must be supported, amount > 0
- **Gas**: ~65,000 gas

#### `claimRevenue(address token) external returns (uint256)`
- **Purpose**: Claim accumulated revenue in specific token
- **Parameters**: 
  - `token`: Revenue token to claim
- **Returns**: `claimed` - Amount of tokens claimed
- **Access**: Any user with claimable revenue
- **Gas**: ~100,000 gas + (epochs * 15,000)

**Example Usage:**
```solidity
// Claim all available USDC revenue
uint256 claimed = stakingPool.claimRevenue(usdcAddress);
```

#### `calculateClaimableRevenue(address user, address token) external view returns (uint256)`
- **Purpose**: Calculate claimable revenue for user in specific token
- **Parameters**: 
  - `user`: User address
  - `token`: Revenue token address
- **Returns**: `claimable` - Amount available to claim
- **Gas**: ~30,000 gas per epoch

#### `getSupportedRevenueTokens() external view returns (address[])`
- **Purpose**: Get list of all supported revenue tokens
- **Returns**: Array of token contract addresses
- **Gas**: ~5,000 gas + (tokens * 1,000)

### Enhanced Staking Functions

#### `stake(uint256 amount, uint256 lockWeeks) external returns (uint256)`
- **Purpose**: Stake SHIP tokens with specified lock period
- **Parameters**: 
  - `amount`: Amount of SHIP to stake
  - `lockWeeks`: Lock period in weeks (1-52)
- **Returns**: `stakeId` - Generated stake ID
- **Changes**: Removed auto-compound parameter
- **Gas**: ~85,000 gas

#### `claimRewards(uint256 stakeId) external returns (uint256)`
- **Purpose**: Claim SHIP rewards for specific stake
- **Parameters**: 
  - `stakeId`: Stake ID to claim rewards for
- **Returns**: `rewardAmount` - Amount of SHIP claimed
- **Changes**: Removed compound parameter, implements linear payout
- **Gas**: ~120,000 gas + (epochs * 20,000)

### Enhanced Reward Calculation

#### `calculatePendingRewards(uint256 stakeId) public view returns (uint256)`
- **Purpose**: Calculate pending SHIP rewards with linear payout
- **Parameters**: 
  - `stakeId`: Stake ID to check
- **Returns**: `pendingRewards` - Available rewards including linear unlock
- **Enhancement**: Now considers time-based unlocking within epochs
- **Gas**: ~40,000 gas per epoch

**Linear Calculation:**
```solidity
if (timeNow >= epochEnd) {
    availableReward = userEpochReward; // Full amount
} else if (timeNow > epochStart) {
    uint256 elapsed = timeNow.sub(epochStart);
    availableReward = userEpochReward.mul(elapsed).div(SECONDS_PER_WEEK);
} else {
    availableReward = 0; // Not started
}
```

---

## Modified Function Signatures

### Removed Parameters

#### StakingPool Functions
```solidity
// OLD: Auto-compound parameter
function stake(uint256 amount, uint256 lockWeeks, bool autoCompound) external returns (uint256);

// NEW: Simplified signature
function stake(uint256 amount, uint256 lockWeeks) external returns (uint256);
```

```solidity
// OLD: Compound parameter
function claimRewards(uint256 stakeId, bool compound) external returns (uint256);

// NEW: Direct claiming only
function claimRewards(uint256 stakeId) external returns (uint256);
```

### Enhanced Return Values

#### TokenomicsCore Functions
```solidity
// Enhanced with linear payout consideration
function getClaimableEmissions(address player) external view returns (uint256 liquid, uint256 vested);
```

---

## New Data Structures

### TokenomicsCore.sol

#### `EmissionEpochInfo`
```solidity
struct EmissionEpochInfo {
    uint256 totalEmissions;                    // Total emissions for epoch
    uint256 startTime;                         // Epoch start time
    uint256 totalCredits;                      // Total credits for epoch
    mapping(address => uint256) playerClaimed; // player => claimed amount
}
```

#### `epochRevenueTotals`
```solidity
mapping(uint256 => uint256) public epochRevenueTotals; // Track revenue per epoch for dynamic emissions
```

#### `emissionRevenueMultiplier`
```solidity
uint256 public emissionRevenueMultiplier = 10; // 10% of previous week revenue
```

### StakingPool.sol

#### `RevenuePool`
```solidity
struct RevenuePool {
    uint256 totalDeposited;                               // Total revenue deposited
    uint256 totalClaimed;                                 // Total revenue claimed
    mapping(uint256 => uint256) epochDeposits;            // epoch => amount
    mapping(address => mapping(uint256 => uint256)) userClaims; // user => epoch => claimed
}
```

#### `EpochRewardInfo`
```solidity
struct EpochRewardInfo {
    uint256 totalRewards;                          // Total SHIP rewards for epoch
    uint256 startTime;                             // Epoch start time
    uint256 totalWeightedStake;                    // Total weighted stake for epoch
    mapping(address => uint256) userClaimed;       // user => claimed amount
}
```

#### Revenue Token Mappings
```solidity
mapping(address => RevenuePool) public revenuePools;    // token => pool data
address[] public revenueTokens;                         // supported tokens array
mapping(address => bool) public isRevenueToken;         // token => supported flag
```

---

## Gas Usage Summary

| Function | Estimated Gas | Notes |
|----------|---------------|-------|
| `calculateDynamicEmissions()` | ~10,000 | View function |
| `setEmissionRevenueMultiplier()` | ~25,000 | Admin function |
| `recordMultiTokenRevenue()` | ~80,000 | Includes transfers |
| `addRevenueToken()` | ~45,000 | One-time setup |
| `claimRevenue()` | ~100k + epochs | Scales with epochs |
| `stake()` (new) | ~85,000 | Simplified version |
| `claimRewards()` (new) | ~120k + epochs | Linear calculation |
| `calculatePendingRewards()` | ~40k per epoch | View function |

---

## Integration Examples

### Frontend Integration

#### Check Multiple Revenue Tokens
```javascript
const supportedTokens = await stakingPool.getSupportedRevenueTokens();
const userRevenue = {};

for (const token of supportedTokens) {
    const claimable = await stakingPool.calculateClaimableRevenue(userAddress, token);
    if (claimable.gt(0)) {
        userRevenue[token] = claimable;
    }
}
```

#### Calculate Linear Progress
```javascript
const epochInfo = await stakingPool.epochRewardInfo(epochNumber);
const epochStart = epochInfo.startTime;
const epochEnd = epochStart + (7 * 24 * 60 * 60); // 1 week
const now = Math.floor(Date.now() / 1000);

const progress = Math.min(100, ((now - epochStart) / (epochEnd - epochStart)) * 100);
```

### Backend Integration

#### Process Dynamic Emissions
```javascript
// Calculate next week's emissions
const currentEpoch = await tokenomicsCore.getCurrentEpoch();
const nextEmissions = await tokenomicsCore.calculateDynamicEmissions(currentEpoch + 1);

// Process emissions (via automation)
await tokenomicsCore.processWeeklyEmissions(currentEpoch);
```

#### Record Multi-Token Revenue
```javascript
// Record marketplace fees in USDC
const usdcRevenue = await marketplace.getWeeklyFees();
await tokenomicsCore.recordMultiTokenRevenue(usdcAddress, usdcRevenue);
```

---

## Testing Recommendations

### Unit Tests
1. **Dynamic Emission Calculation**: Test various revenue scenarios
2. **Linear Payout Logic**: Verify time-based unlocking
3. **Multi-Token Revenue**: Test multiple token distributions
4. **Edge Cases**: Zero revenue, maximum caps, epoch boundaries

### Integration Tests
1. **Cross-Contract Revenue Flow**: TokenomicsCore → StakingPool
2. **Epoch Processing**: Automated weekly processing
3. **Claim Scenarios**: Multiple epochs, partial claims
4. **Emergency Functions**: Pause, recovery, admin controls

### Performance Tests
1. **Gas Usage**: Measure actual gas consumption
2. **Scaling**: Test with many epochs/users
3. **View Function Performance**: Large data sets
4. **Batch Operations**: Multiple claims, multiple epochs