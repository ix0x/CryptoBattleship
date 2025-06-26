# CryptoBattleship V2 Epoch System Guide

This document provides a comprehensive guide to the new epoch-based reward distribution system with linear weekly payouts.

---

## Overview

The V2 upgrade introduces a sophisticated epoch-based system where:
- **Epochs**: 1-week periods for reward calculation and distribution
- **Linear Payouts**: Rewards unlock gradually over each week (0% → 100%)
- **Multiple Streams**: Separate systems for SHIP emissions and multi-token revenue
- **Continuous Claiming**: Users can claim partial rewards throughout the week

---

## Epoch Timeline

### Epoch Structure
```
Epoch 1: Week 1 (Days 1-7)
├── Day 1: Epoch starts, rewards calculated for all stakers
├── Days 1-7: Linear payout (0% → 100% over 7 days)
└── Day 7: Epoch ends, full rewards available

Epoch 2: Week 2 (Days 8-14)
├── Day 8: New epoch starts, new rewards calculated
├── Days 8-14: Linear payout for Epoch 2
└── Previous epochs remain claimable
```

### Timing Details
- **Epoch Duration**: Exactly 7 days (604,800 seconds)
- **Genesis Timestamp**: Set at contract deployment
- **Epoch Calculation**: `((block.timestamp - genesisTimestamp) / 604800) + 1`
- **Linear Progress**: `(current_time - epoch_start) / 604800`

---

## Dual Reward Systems

### 1. SHIP Token Emissions (Credit-Based)

#### How It Works
1. **Players earn credits** from game participation and retired ships
2. **Credits decay** over 5 epochs (2 full value + 3 declining)
3. **Weekly emissions calculated** using dynamic formula
4. **Tokens distributed** based on credit share with linear unlock

#### Credit System
```solidity
// Credit earning sources
- Game wins: 1-30 credits (based on game size)
- Game losses: 0-15 credits (based on game size)  
- Retired ships: 1 credit per ship per epoch

// Credit decay schedule
Epochs 1-2: 100% value (full credits)
Epoch 3: 67% value (1/3 decay)
Epoch 4: 33% value (2/3 decay)
Epoch 5+: 0% value (fully expired)
```

#### Dynamic Emission Formula
```solidity
totalEmission = baseEmission + (previousWeekRevenue * multiplier)

// Default values:
baseEmission = 100,000 SHIP
multiplier = 10% (configurable 0-50%)
maxEmission = 1,000,000 SHIP (safety cap)
```

#### Distribution Process
```solidity
// 1. Calculate player's credit share
uint256 playerCredits = getPlayerCreditsForEpoch(player, epoch);
uint256 playerShare = epochEmissions * playerCredits / totalCredits;

// 2. Apply emission cap (if enabled)
if (emissionCapEnabled) {
    uint256 maxAllowed = epochEmissions * maxEmissionPercentage / 100;
    playerShare = min(playerShare, maxAllowed);
}

// 3. Calculate linear availability
uint256 elapsed = block.timestamp - epochStart;
uint256 availableAmount = playerShare * elapsed / EPOCH_DURATION;

// 4. Split into liquid and vested
uint256 liquid = availableAmount * 30 / 100;  // 30% immediate
uint256 vested = availableAmount * 70 / 100;  // 70% vested over 1 week
```

### 2. Multi-Token Revenue Sharing (Staking-Based)

#### How It Works
1. **Protocol generates revenue** in various tokens (ETH, USDC, etc.)
2. **Revenue distributed directly** to staking pool (70% allocation)
3. **Stakers earn pro-rata** based on weighted stake amount
4. **Tokens unlock linearly** over the week

#### Revenue Sources
```
Game entry fees → 70% to staking
Marketplace fees → 70% to staking  
Lootbox purchases → 70% to staking
P2P rentals → 70% to staking
Protocol rentals → 70% to staking
```

#### Weighted Staking
```solidity
// Stake multipliers based on lock period
1 week: 1.0x multiplier
26 weeks: 1.5x multiplier  
52 weeks: 2.0x multiplier

// Weighted stake calculation
weightedStake = stakeAmount * multiplier
```

#### Distribution Process
```solidity
// 1. Calculate user's weighted stake share
uint256 userWeightedStake = stakeAmount * multiplier;
uint256 userShare = epochRevenue * userWeightedStake / totalWeightedStake;

// 2. Calculate linear availability  
uint256 elapsed = block.timestamp - epochStart;
uint256 availableAmount = userShare * elapsed / EPOCH_DURATION;

// 3. Direct token distribution (no conversion)
// User receives actual revenue tokens (ETH, USDC, etc.)
```

---

## Linear Payout Mechanics

### Calculation Formula
```solidity
function calculateLinearPayout(
    uint256 totalAmount,
    uint256 epochStart,
    uint256 currentTime
) internal pure returns (uint256) {
    uint256 epochEnd = epochStart + EPOCH_DURATION;
    
    if (currentTime >= epochEnd) {
        return totalAmount; // 100% unlocked
    } else if (currentTime > epochStart) {
        uint256 elapsed = currentTime - epochStart;
        return totalAmount * elapsed / EPOCH_DURATION; // Linear unlock
    } else {
        return 0; // Not started yet
    }
}
```

### Payout Timeline Examples

#### Example 1: 1000 SHIP Rewards
```
Day 1 (0 hours): 0 SHIP available
Day 1 (12 hours): ~83 SHIP available (12/168 hours)
Day 2 (24 hours): ~143 SHIP available (24/168 hours) 
Day 4 (72 hours): ~429 SHIP available (72/168 hours)
Day 7 (168 hours): 1000 SHIP available (100%)
```

#### Example 2: 500 USDC Revenue
```
Day 1: 0 USDC → ~71 USDC (0% → 14.3%)
Day 2: ~71 USDC → ~143 USDC (14.3% → 28.6%)
Day 3: ~143 USDC → ~214 USDC (28.6% → 42.9%)
Day 7: 500 USDC available (100%)
```

---

## Claiming Mechanics

### SHIP Emission Claims

#### Single Stake Claim
```solidity
// Claim rewards for specific stake
uint256 rewards = stakingPool.claimRewards(stakeId);

// Process:
// 1. Calculate available rewards across all epochs
// 2. Update user's claimed amounts per epoch
// 3. Transfer liquid SHIP immediately
// 4. Create vesting entry for 70% portion
```

#### All Stakes Claim
```solidity
// Claim rewards for all user stakes
uint256 totalRewards = stakingPool.claimAllRewards();

// Processes all stakes simultaneously
```

#### Credit-Based Claim
```solidity
// Claim emissions based on credits (alternative method)
tokenomicsCore.claimEmissions(playerAddress);

// Direct credit → token conversion with linear unlock
```

### Multi-Token Revenue Claims

#### Single Token Claim
```solidity
// Claim specific revenue token
uint256 claimed = stakingPool.claimRevenue(tokenAddress);

// Process:
// 1. Calculate claimable amount across all epochs
// 2. Update claimed tracking per epoch
// 3. Transfer tokens directly (no conversion)
```

#### View Claimable Amounts
```solidity
// Check claimable amount before claiming
uint256 claimable = stakingPool.calculateClaimableRevenue(user, token);

// Get all supported revenue tokens
address[] memory tokens = stakingPool.getSupportedRevenueTokens();
```

---

## Epoch Processing

### Automated Processing

#### SHIP Emissions
```solidity
// Called weekly by automation (Gelato)
function processWeeklyEmissions(uint256 epoch) external {
    // 1. Calculate dynamic emissions for epoch
    uint256 emissions = calculateDynamicEmissions(epoch);
    
    // 2. Setup epoch info for linear payout
    emissionEpochInfo[epoch] = EmissionEpochInfo({
        totalEmissions: emissions,
        startTime: epochStartTime,
        totalCredits: totalActiveCredits
    });
    
    // 3. Mark epoch as processed
    epochProcessed[epoch] = true;
}
```

#### Revenue Distribution
```solidity
// Called when revenue is recorded
function addRevenueToPool(address token, uint256 amount) external {
    // 1. Setup revenue pool for current epoch
    uint256 currentEpoch = getCurrentEpoch();
    revenuePools[token].epochDeposits[currentEpoch] += amount;
    
    // 2. Revenue becomes available with linear unlock
}
```

### Manual Triggers

#### Force Epoch Update
```solidity
// Emergency function to advance epoch
function forceEpochUpdate() external onlyOwner {
    _updateEpoch();
}
```

#### Process Past Epochs
```solidity
// Process missed epochs (if automation fails)
for (uint256 i = lastProcessed; i <= currentEpoch; i++) {
    processWeeklyEmissions(i);
}
```

---

## User Experience Flow

### For SHIP Stakers

#### Week 1 Setup
1. **Stake SHIP tokens** with chosen lock period
2. **Weighted stake calculated** based on lock multiplier
3. **Wait for epoch processing** (weekly automation)

#### Ongoing Rewards
1. **Check pending rewards** using view functions
2. **Claim partial rewards** throughout the week
3. **Track linear unlock progress** via frontend
4. **Claim vested tokens** after 1-week vesting

#### Multiple Epochs
1. **Accumulate rewards** from multiple epochs
2. **Claim efficiently** with batch processing
3. **Monitor different unlock schedules** per epoch

### For Game Players

#### Earning Credits
1. **Play games** to earn credits (1-30 per game)
2. **Retire ships** for ongoing credit income
3. **Watch credit decay** over 5-epoch lifecycle

#### Claiming Emissions
1. **Wait for epoch processing** of earned credits
2. **Claim proportional share** of weekly emissions  
3. **Receive 30% liquid** + 70% vested over 1 week
4. **Monitor decay** of older credits

### For Revenue Recipients

#### Multi-Token Income
1. **Automatic revenue allocation** (70% to staking)
2. **Linear unlock** of revenue tokens over week
3. **Claim in original tokens** (no conversion)
4. **Multiple revenue streams** simultaneously

---

## Technical Implementation

### Storage Optimization

#### Epoch Data Structure
```solidity
// Efficient packed storage for epoch info
struct EpochRewardInfo {
    uint256 totalRewards;        // Total rewards for epoch
    uint256 startTime;           // Epoch start timestamp  
    uint256 totalWeightedStake;  // Weighted stake snapshot
    // Dynamic mapping for user claims
}
```

#### Batch Processing
```solidity
// Process multiple epochs in single transaction
function batchClaimRewards(uint256[] calldata epochs) external {
    for (uint256 i = 0; i < epochs.length; i++) {
        // Process epoch rewards
    }
}
```

### Gas Optimization

#### View Function Efficiency
- **Pre-calculate common values** to reduce computation
- **Cache epoch data** for repeated access
- **Batch epoch processing** in view functions

#### Claim Optimization
- **Update multiple epochs** in single transaction
- **Minimize storage writes** with efficient data structures
- **Batch token transfers** when possible

### Security Considerations

#### Epoch Validation
```solidity
// Ensure epoch boundaries are respected
require(epoch <= currentEpoch, "Future epoch");
require(epochProcessed[epoch], "Epoch not processed");
```

#### Linear Payout Security
```solidity
// Prevent manipulation of time-based calculations
uint256 clampedTime = min(block.timestamp, epochEnd);
```

#### Revenue Token Safety
```solidity
// Whitelist revenue tokens to prevent malicious tokens
require(isRevenueToken[token], "Token not supported");
```

---

## Monitoring and Analytics

### Key Metrics

#### Emission Metrics
- **Weekly emission amounts** (base + revenue bonus)
- **Credit distribution** across players
- **Claim frequency** and timing patterns
- **Vesting token accumulation**

#### Revenue Metrics  
- **Multi-token revenue volumes** per epoch
- **Distribution efficiency** across stakers
- **Claim patterns** for different tokens
- **Linear unlock utilization**

#### User Behavior
- **Claim timing preferences** (early vs. late week)
- **Multi-epoch claim patterns**
- **Stake duration preferences**
- **Revenue token preferences**

### Dashboard Recommendations

#### For Users
- **Real-time unlock progress** for each epoch
- **Projected weekly income** from multiple sources
- **Optimal claim timing** suggestions
- **Historical earnings** tracking

#### For Admins
- **Epoch processing status** monitoring
- **Revenue distribution health** checks
- **Gas usage optimization** tracking
- **System performance** metrics

---

## Troubleshooting Guide

### Common Issues

#### Claims Not Available
```solidity
// Check epoch processing status
bool processed = epochProcessed[epochNumber];

// Verify linear unlock progress
uint256 elapsed = block.timestamp - epochStartTime;
uint256 progress = (elapsed * 100) / EPOCH_DURATION;
```

#### Revenue Token Issues
```solidity
// Verify token is supported
bool supported = isRevenueToken[tokenAddress];

// Check revenue pool status
RevenuePool memory pool = revenuePools[tokenAddress];
```

#### Epoch Synchronization
```solidity
// Force epoch update if needed
function forceEpochUpdate() external onlyOwner;

// Check current epoch calculation
uint256 epoch = getCurrentEpoch();
```

### Emergency Procedures

#### Pause System
```solidity
// Pause all claims during emergency
function pause() external onlyOwner;
```

#### Recover Stuck Tokens
```solidity
// Emergency token recovery
function emergencyTokenRecovery(address token, uint256 amount) external onlyOwner;
```

#### Manual Epoch Processing
```solidity
// Process epochs manually if automation fails
function processWeeklyEmissions(uint256 epoch) external onlyOwner;
```

---

## Best Practices

### For Users
1. **Regular Claiming**: Claim rewards weekly to optimize gas usage
2. **Monitor Progress**: Track linear unlock progress for optimal timing
3. **Multi-Token Strategy**: Claim different revenue tokens based on preferences
4. **Stake Duration**: Consider longer locks for higher multipliers

### For Developers
1. **Batch Operations**: Process multiple epochs together when possible
2. **Gas Estimation**: Account for variable gas costs based on epoch count
3. **Error Handling**: Handle epoch boundaries and processing states
4. **State Validation**: Always verify epoch processing before calculations

### For Admins
1. **Automation Monitoring**: Ensure weekly epoch processing runs reliably
2. **Revenue Token Management**: Carefully vet new revenue tokens
3. **Emergency Preparedness**: Have manual processing procedures ready
4. **Performance Monitoring**: Track gas usage and system efficiency