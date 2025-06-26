# CryptoBattleship V2 Migration Checklist

This document provides a comprehensive checklist for migrating from V1 to V2 tokenomics system.

---

## Pre-Deployment Checklist

### Smart Contract Preparation

#### ✅ Contract Compilation
- [ ] Compile all updated contracts with Solidity 0.8.19
- [ ] Verify no compilation errors or warnings
- [ ] Run gas reporter on all functions
- [ ] Confirm contract size limits (24KB)

#### ✅ Security Review
- [ ] Review all new functions for security vulnerabilities
- [ ] Verify access controls on admin functions
- [ ] Test reentrancy protection on claim functions
- [ ] Validate input sanitization on new parameters

#### ✅ Testing Suite
- [ ] Unit tests for all new functions
- [ ] Integration tests for cross-contract interactions
- [ ] Linear payout calculation tests
- [ ] Edge case testing (zero values, max values)
- [ ] Gas usage optimization tests

### Configuration Parameters

#### ✅ TokenomicsCore Settings
- [ ] Set initial `emissionRevenueMultiplier` (recommended: 10%)
- [ ] Verify `MAX_EMISSION_RATE` (1M SHIP cap)
- [ ] Configure `LIQUID_PERCENTAGE` (30% immediate)
- [ ] Set `VESTING_DURATION` (1 epoch)

#### ✅ StakingPool Settings  
- [ ] Define initial supported revenue tokens
- [ ] Set up epoch tracking variables
- [ ] Configure emergency controls
- [ ] Verify multiplier calculations (1x-2x)

#### ✅ Admin Roles
- [ ] Set up multisig wallets for admin functions
- [ ] Configure automation admin roles (Gelato)
- [ ] Verify emergency pause controls
- [ ] Set up team treasury addresses

---

## Deployment Sequence

### Phase 1: Core Contract Deployment

#### Step 1: Deploy Supporting Contracts
```bash
# Deploy in order (dependencies)
1. GameConfig.sol (unchanged)
2. BattleshipToken.sol (unchanged)
3. NFTManager.sol (unchanged)
```

#### Step 2: Deploy Updated Core Contracts
```bash
# Deploy updated contracts
4. TokenomicsCore.sol (V2)
5. StakingPool.sol (V2)
6. MarketplaceCore.sol (unchanged)
7. LootboxSystem.sol (unchanged)
8. BattleshipGame.sol (unchanged)
```

#### Step 3: Verify Deployments
- [ ] Confirm all contract addresses
- [ ] Verify contract source code on block explorer
- [ ] Test basic functionality (view functions)
- [ ] Check constructor parameters

### Phase 2: Configuration Setup

#### Step 1: Configure TokenomicsCore
```solidity
// Set contract references
tokenomicsCore.updateContract("StakingPool", stakingPoolAddress);
tokenomicsCore.updateContract("TeamTreasury", treasuryAddress);
tokenomicsCore.updateContract("LiquidityPool", liquidityAddress);

// Configure dynamic emissions
tokenomicsCore.setEmissionRevenueMultiplier(10); // 10%

// Authorize revenue recording contracts
tokenomicsCore.setAuthorizedMinter(marketplaceAddress, true);
tokenomicsCore.setAuthorizedMinter(lootboxAddress, true);
tokenomicsCore.setAuthorizedMinter(gameAddress, true);
```

#### Step 2: Configure StakingPool
```solidity
// Set contract references
stakingPool.updateContract("TokenomicsCore", tokenomicsCoreAddress);
stakingPool.updateContract("BattleshipToken", tokenAddress);

// Add supported revenue tokens
stakingPool.addRevenueToken(WETH_ADDRESS);
stakingPool.addRevenueToken(USDC_ADDRESS);
stakingPool.addRevenueToken(USDT_ADDRESS);
```

#### Step 3: Configure Cross-Contract References
```solidity
// Update all contracts to reference new addresses
gameConfig.updateContract("TokenomicsCore", newTokenomicsCoreAddress);
battleshipGame.updateContract("TokenomicsCore", newTokenomicsCoreAddress);
marketplace.updateContract("TokenomicsCore", newTokenomicsCoreAddress);
lootboxSystem.updateContract("TokenomicsCore", newTokenomicsCoreAddress);
```

### Phase 3: Data Migration (if needed)

#### Step 1: Existing Stake Migration
- [ ] Export existing stake data from V1
- [ ] Verify stake amounts and lock periods
- [ ] Migrate stakes to V2 contract (if required)
- [ ] Validate migrated data accuracy

#### Step 2: Credit Migration  
- [ ] Export player credit data
- [ ] Recalculate credit decay for new epoch system
- [ ] Import credits to V2 system
- [ ] Verify credit totals match

#### Step 3: Revenue History
- [ ] Export historical revenue data
- [ ] Set up initial epoch revenue totals
- [ ] Configure dynamic emission baseline
- [ ] Verify revenue tracking accuracy

---

## Post-Deployment Verification

### Functionality Testing

#### ✅ Core Functions
- [ ] Test SHIP token staking (new signature)
- [ ] Verify lock period multiplier calculations
- [ ] Test reward claiming (new linear system)
- [ ] Validate epoch processing automation

#### ✅ Dynamic Emissions
- [ ] Test emission calculation with various revenue amounts
- [ ] Verify emission cap enforcement (1M SHIP)
- [ ] Test revenue multiplier adjustments
- [ ] Validate epoch processing triggers

#### ✅ Multi-Token Revenue
- [ ] Test revenue token addition
- [ ] Verify revenue distribution (70/20/10 split)
- [ ] Test linear payout calculations
- [ ] Validate cross-token claiming

#### ✅ Linear Payout System
- [ ] Test time-based reward unlocking
- [ ] Verify partial claim functionality
- [ ] Test multiple epoch claims
- [ ] Validate epoch boundary handling

### Security Verification

#### ✅ Access Controls
- [ ] Verify only authorized addresses can call admin functions
- [ ] Test emergency pause functionality
- [ ] Validate multisig controls work correctly
- [ ] Confirm automation admin restrictions

#### ✅ Economic Security
- [ ] Test emission cap enforcement
- [ ] Verify reward calculation accuracy
- [ ] Test edge cases (zero rewards, max values)
- [ ] Validate linear unlock math precision

#### ✅ Integration Security
- [ ] Test cross-contract communication
- [ ] Verify state synchronization
- [ ] Test reentrancy protection
- [ ] Validate error handling

---

## Frontend Updates

### Component Updates

#### ✅ Staking Interface
- [ ] Update stake creation UI (remove auto-compound)
- [ ] Add lock period multiplier display
- [ ] Show linear reward unlock progress
- [ ] Display multiple epoch rewards

#### ✅ Reward Dashboard
- [ ] Add multi-token revenue display
- [ ] Show linear unlock timers
- [ ] Display claimable amounts per token
- [ ] Add epoch progress indicators

#### ✅ Admin Panel
- [ ] Add dynamic emission configuration
- [ ] Revenue token management interface
- [ ] Epoch processing monitoring
- [ ] Emergency controls dashboard

### API Integration

#### ✅ New Function Calls
```javascript
// Update function signatures
const stakeId = await stakingPool.stake(amount, lockWeeks); // removed autoCompound
const rewards = await stakingPool.claimRewards(stakeId); // removed compound

// Add new function calls
const supportedTokens = await stakingPool.getSupportedRevenueTokens();
const claimableUSDC = await stakingPool.calculateClaimableRevenue(user, USDC);
const dynamicEmission = await tokenomicsCore.calculateDynamicEmissions(epoch);
```

#### ✅ Event Handling
```javascript
// Update event listeners for new signatures
stakingPool.on('Staked', (user, stakeId, amount, lockWeeks, multiplier) => {
    // Handle new event signature (removed autoCompound)
});

// Add new event listeners
stakingPool.on('RevenueClaimed', (user, token, amount) => {
    // Handle revenue token claims
});

tokenomicsCore.on('MultiTokenRevenueDistributed', (token, staking, team, liquidity) => {
    // Handle revenue distribution events
});
```

### User Experience

#### ✅ Progressive Disclosure
- [ ] Show basic staking first, advanced features later
- [ ] Gradual introduction of multi-token rewards
- [ ] Clear explanation of linear unlock system
- [ ] Help tooltips for new concepts

#### ✅ Real-Time Updates
- [ ] Live progress bars for linear unlocks
- [ ] Dynamic reward calculations
- [ ] Multi-token balance updates
- [ ] Epoch countdown timers

---

## Monitoring Setup

### Analytics Dashboard

#### ✅ System Health Metrics
- [ ] Epoch processing status monitoring
- [ ] Dynamic emission tracking
- [ ] Revenue distribution monitoring
- [ ] Linear payout efficiency

#### ✅ User Behavior Analytics
- [ ] Claim timing patterns
- [ ] Multi-token preferences
- [ ] Stake duration analysis
- [ ] Reward optimization patterns

#### ✅ Economic Metrics
- [ ] Total emissions per epoch
- [ ] Revenue growth correlation
- [ ] Token distribution health
- [ ] Liquidity impact analysis

### Alerting System

#### ✅ Critical Alerts
- [ ] Failed epoch processing
- [ ] Abnormal emission amounts
- [ ] Contract pause events
- [ ] Revenue distribution failures

#### ✅ Performance Alerts
- [ ] High gas usage warnings
- [ ] Slow claim processing
- [ ] Frontend performance issues
- [ ] API response time alerts

---

## Emergency Procedures

### Incident Response

#### ✅ Pause Procedures
```solidity
// Emergency pause sequence
1. stakingPool.pause()
2. tokenomicsCore.pause()
3. Coordinate with other contract admins
```

#### ✅ Recovery Procedures
```solidity
// Recovery sequence
1. Identify and fix issue
2. Test fix on testnet
3. Deploy fix (if contract upgrade needed)
4. Resume operations: unpause()
```

#### ✅ Communication Plan
- [ ] User notification system ready
- [ ] Social media communication plan
- [ ] Documentation update procedures
- [ ] Support team briefing materials

### Rollback Plan

#### ✅ Contract Rollback
- [ ] V1 contract addresses stored
- [ ] Frontend rollback deployment ready
- [ ] Database rollback procedures
- [ ] User communication plan

#### ✅ Data Recovery
- [ ] Backup all V2 data before rollback
- [ ] Plan for partial data migration
- [ ] User balance preservation
- [ ] Minimize user impact

---

## Go-Live Checklist

### Final Verification

#### ✅ All Systems Check
- [ ] Smart contracts deployed and verified
- [ ] Frontend updated and tested
- [ ] Backend APIs updated
- [ ] Monitoring systems active

#### ✅ Team Readiness
- [ ] Development team on standby
- [ ] Support team trained on new features
- [ ] Community management prepared
- [ ] Documentation published

#### ✅ User Communication
- [ ] Migration announcement published
- [ ] User guides updated
- [ ] FAQ prepared for new features
- [ ] Video tutorials created

### Launch Sequence

#### ✅ Soft Launch (24 hours)
- [ ] Enable V2 contracts with limited access
- [ ] Monitor system performance
- [ ] Gather initial user feedback
- [ ] Verify all integrations work

#### ✅ Full Launch
- [ ] Open access to all users
- [ ] Announce V2 features publicly
- [ ] Monitor system under full load
- [ ] Provide immediate user support

#### ✅ Post-Launch (48 hours)
- [ ] Monitor all metrics closely
- [ ] Address any issues immediately
- [ ] Gather user feedback
- [ ] Plan optimization updates

---

## Success Metrics

### Technical Metrics
- [ ] **System Uptime**: >99.9% availability
- [ ] **Gas Efficiency**: <20% increase in gas costs
- [ ] **Claim Success Rate**: >99% successful claims
- [ ] **Epoch Processing**: 100% automated success

### User Metrics  
- [ ] **User Adoption**: >80% migration to V2 features
- [ ] **Satisfaction**: Positive user feedback on new features
- [ ] **Engagement**: Increased claiming frequency
- [ ] **Support Load**: <10% increase in support tickets

### Economic Metrics
- [ ] **Emission Accuracy**: Dynamic emissions working correctly
- [ ] **Revenue Growth**: Positive correlation with emission increases  
- [ ] **Token Distribution**: Healthy reward distribution
- [ ] **Liquidity Health**: No negative impact on token liquidity

---

## Post-Migration Optimization

### Performance Tuning
- [ ] Optimize gas usage based on real usage patterns
- [ ] Improve frontend loading times
- [ ] Streamline claim processes
- [ ] Enhance user experience flows

### Feature Enhancement
- [ ] Add advanced analytics for users
- [ ] Implement batch claim optimizations
- [ ] Add more revenue token support
- [ ] Enhance mobile experience

### Documentation Updates
- [ ] Update all technical documentation
- [ ] Create user success stories
- [ ] Publish performance metrics
- [ ] Plan future enhancement roadmap

---

## Completion Sign-Off

### Technical Team
- [ ] **Smart Contract Developer**: Contracts deployed and verified ✅
- [ ] **Frontend Developer**: UI updated and tested ✅
- [ ] **Backend Developer**: APIs updated and monitored ✅
- [ ] **DevOps Engineer**: Infrastructure ready and monitored ✅

### Business Team
- [ ] **Product Manager**: Features meet requirements ✅
- [ ] **Community Manager**: Users informed and supported ✅
- [ ] **Marketing**: Launch communications executed ✅
- [ ] **Support**: Team trained and ready ✅

### Final Approval
- [ ] **Technical Lead**: All technical requirements met ✅
- [ ] **Project Manager**: Timeline and deliverables achieved ✅
- [ ] **CEO/Founder**: Business objectives satisfied ✅

**Migration Complete**: ✅ V2 Tokenomics Successfully Deployed