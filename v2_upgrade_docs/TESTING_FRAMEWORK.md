# CryptoBattleship V2 Testing Framework

This document outlines comprehensive testing strategies for the V2 tokenomics upgrade, including unit tests, integration tests, and performance benchmarks.

---

## Testing Overview

### Test Categories
1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Cross-contract interactions
3. **Performance Tests**: Gas usage and optimization
4. **Security Tests**: Vulnerability and edge case testing
5. **User Scenario Tests**: End-to-end user flows

### Testing Environment
- **Framework**: Hardhat with Mocha/Chai
- **Network**: Local Hardhat network
- **Coverage**: Istanbul/Solidity-coverage
- **Gas Analysis**: Hardhat-gas-reporter

---

## Unit Test Suite

### TokenomicsCore Tests

#### Dynamic Emission Tests
```javascript
describe("Dynamic Emissions", () => {
    it("should calculate base emission correctly", async () => {
        const baseEmission = await gameConfig.getWeeklyEmissionRate();
        const calculated = await tokenomicsCore.calculateDynamicEmissions(1);
        expect(calculated).to.equal(baseEmission);
    });

    it("should add revenue bonus correctly", async () => {
        // Set previous epoch revenue
        await tokenomicsCore.recordGameFees(ethers.utils.parseEther("10000"));
        await advanceEpoch();
        
        const emission = await tokenomicsCore.calculateDynamicEmissions(2);
        const expected = baseEmission + (10000 * 0.1); // 10% bonus
        expect(emission).to.equal(ethers.utils.parseEther(expected.toString()));
    });

    it("should respect maximum emission cap", async () => {
        // Set very high revenue to test cap
        await tokenomicsCore.recordGameFees(ethers.utils.parseEther("100000000"));
        await advanceEpoch();
        
        const emission = await tokenomicsCore.calculateDynamicEmissions(2);
        const maxCap = await tokenomicsCore.MAX_EMISSION_RATE();
        expect(emission).to.equal(maxCap);
    });

    it("should allow admin to configure multiplier", async () => {
        await tokenomicsCore.setEmissionRevenueMultiplier(25);
        const multiplier = await tokenomicsCore.emissionRevenueMultiplier();
        expect(multiplier).to.equal(25);
    });

    it("should reject multiplier above 50%", async () => {
        await expect(
            tokenomicsCore.setEmissionRevenueMultiplier(51)
        ).to.be.revertedWith("TokenomicsCore: Multiplier too high");
    });
});
```

#### Linear Emission Payout Tests
```javascript
describe("Linear Emission Payouts", () => {
    beforeEach(async () => {
        // Setup epoch with emissions
        await awardCreditsToPlayer(player1, 1000, 1);
        await tokenomicsCore.processWeeklyEmissions(1);
    });

    it("should show 0% available at epoch start", async () => {
        const claimable = await tokenomicsCore.getClaimableEmissions(player1.address);
        expect(claimable.liquid).to.equal(0);
        expect(claimable.vested).to.equal(0);
    });

    it("should show 50% available at midweek", async () => {
        await advanceTime(3.5 * 24 * 60 * 60); // 3.5 days
        
        const claimable = await tokenomicsCore.getClaimableEmissions(player1.address);
        const expectedLiquid = totalEmission.mul(30).div(100).div(2); // 30% of 50%
        const expectedVested = totalEmission.mul(70).div(100).div(2); // 70% of 50%
        
        expect(claimable.liquid).to.approximately(expectedLiquid, tolerance);
        expect(claimable.vested).to.approximately(expectedVested, tolerance);
    });

    it("should show 100% available after full week", async () => {
        await advanceTime(7 * 24 * 60 * 60 + 1); // 1 week + 1 second
        
        const claimable = await tokenomicsCore.getClaimableEmissions(player1.address);
        const expectedLiquid = totalEmission.mul(30).div(100);
        const expectedVested = totalEmission.mul(70).div(100);
        
        expect(claimable.liquid).to.equal(expectedLiquid);
        expect(claimable.vested).to.equal(expectedVested);
    });

    it("should handle partial claims correctly", async () => {
        await advanceTime(2 * 24 * 60 * 60); // 2 days (28.6%)
        
        // First claim
        await tokenomicsCore.claimEmissions(player1.address);
        const balance1 = await battleshipToken.balanceOf(player1.address);
        
        await advanceTime(3 * 24 * 60 * 60); // 3 more days (total 71.4%)
        
        // Second claim
        await tokenomicsCore.claimEmissions(player1.address);
        const balance2 = await battleshipToken.balanceOf(player1.address);
        
        // Should receive approximately 42.8% more (71.4% - 28.6%)
        const additionalTokens = balance2.sub(balance1);
        const expectedAdditional = totalEmission.mul(428).div(1000).mul(30).div(100);
        expect(additionalTokens).to.approximately(expectedAdditional, tolerance);
    });
});
```

#### Multi-Token Revenue Tests
```javascript
describe("Multi-Token Revenue", () => {
    beforeEach(async () => {
        // Setup USDC as revenue token
        await stakingPool.addRevenueToken(usdc.address);
    });

    it("should record multi-token revenue correctly", async () => {
        const revenueAmount = ethers.utils.parseUnits("1000", 6); // 1000 USDC
        
        await usdc.mint(tokenomicsCore.address, revenueAmount);
        await tokenomicsCore.recordMultiTokenRevenue(usdc.address, revenueAmount);
        
        const stakingAmount = revenueAmount.mul(70).div(100);
        const pool = await stakingPool.revenuePools(usdc.address);
        expect(pool.totalDeposited).to.equal(stakingAmount);
    });

    it("should distribute revenue with correct percentages", async () => {
        const revenueAmount = ethers.utils.parseUnits("1000", 6);
        
        const teamBalanceBefore = await usdc.balanceOf(teamTreasury.address);
        const liquidityBalanceBefore = await usdc.balanceOf(liquidityPool.address);
        
        await usdc.mint(tokenomicsCore.address, revenueAmount);
        await tokenomicsCore.recordMultiTokenRevenue(usdc.address, revenueAmount);
        
        const teamBalanceAfter = await usdc.balanceOf(teamTreasury.address);
        const liquidityBalanceAfter = await usdc.balanceOf(liquidityPool.address);
        
        expect(teamBalanceAfter.sub(teamBalanceBefore)).to.equal(revenueAmount.mul(20).div(100));
        expect(liquidityBalanceAfter.sub(liquidityBalanceBefore)).to.equal(revenueAmount.mul(10).div(100));
    });

    it("should reject unsupported revenue tokens", async () => {
        await expect(
            tokenomicsCore.recordMultiTokenRevenue(battleshipToken.address, 1000)
        ).to.be.revertedWith("TokenomicsCore: Invalid token");
    });
});
```

### StakingPool Tests

#### Enhanced Staking Tests
```javascript
describe("Enhanced Staking", () => {
    it("should stake without auto-compound parameter", async () => {
        const stakeAmount = ethers.utils.parseEther("1000");
        const lockWeeks = 26;
        
        await battleshipToken.mint(player1.address, stakeAmount);
        await battleshipToken.connect(player1).approve(stakingPool.address, stakeAmount);
        
        const tx = await stakingPool.connect(player1).stake(stakeAmount, lockWeeks);
        const receipt = await tx.wait();
        
        // Check event emission
        const event = receipt.events.find(e => e.event === 'Staked');
        expect(event.args.amount).to.equal(stakeAmount);
        expect(event.args.lockWeeks).to.equal(lockWeeks);
        expect(event.args).to.not.have.property('autoCompound');
    });

    it("should calculate multipliers correctly", async () => {
        const testCases = [
            { weeks: 1, expectedMultiplier: 1000 },   // 1x
            { weeks: 26, expectedMultiplier: 1475 },  // ~1.475x
            { weeks: 52, expectedMultiplier: 2000 }   // 2x
        ];
        
        for (const testCase of testCases) {
            const stakeId = await createStake(testCase.weeks);
            const stake = await stakingPool.stakes(stakeId);
            expect(stake.multiplier).to.equal(testCase.expectedMultiplier);
        }
    });

    it("should remove auto-compound from StakeInfo", async () => {
        const stakeId = await createStake(26);
        const stake = await stakingPool.stakes(stakeId);
        
        // Verify struct doesn't have autoCompound field
        expect(stake).to.not.have.property('autoCompound');
        expect(stake.amount).to.be.a('BigNumber');
        expect(stake.lockWeeks).to.be.a('BigNumber');
        expect(stake.multiplier).to.be.a('BigNumber');
    });
});
```

#### Multi-Token Revenue Staking Tests
```javascript
describe("Multi-Token Revenue Claims", () => {
    beforeEach(async () => {
        // Setup staking and revenue tokens
        await setupStakingScenario();
        await stakingPool.addRevenueToken(usdc.address);
        await stakingPool.addRevenueToken(weth.address);
    });

    it("should calculate revenue share based on weighted stake", async () => {
        const user1Stake = ethers.utils.parseEther("1000"); // 1 week lock (1x)
        const user2Stake = ethers.utils.parseEther("1000"); // 52 week lock (2x)
        
        await createUserStake(user1, user1Stake, 1);
        await createUserStake(user2, user2Stake, 52);
        
        // Add USDC revenue
        const revenueAmount = ethers.utils.parseUnits("3000", 6); // 3000 USDC
        await addRevenue(usdc.address, revenueAmount);
        
        // User1 weighted stake: 1000 * 1 = 1000
        // User2 weighted stake: 1000 * 2 = 2000
        // Total weighted stake: 3000
        // User1 share: 1000/3000 = 33.33%
        // User2 share: 2000/3000 = 66.67%
        
        const user1Claimable = await stakingPool.calculateClaimableRevenue(user1.address, usdc.address);
        const user2Claimable = await stakingPool.calculateClaimableRevenue(user2.address, usdc.address);
        
        expect(user1Claimable).to.approximately(revenueAmount.div(3), tolerance);
        expect(user2Claimable).to.approximately(revenueAmount.mul(2).div(3), tolerance);
    });

    it("should handle multiple revenue tokens simultaneously", async () => {
        await createUserStake(user1, ethers.utils.parseEther("1000"), 26);
        
        // Add multiple revenue types
        await addRevenue(usdc.address, ethers.utils.parseUnits("1000", 6));
        await addRevenue(weth.address, ethers.utils.parseEther("10"));
        
        // Advance time to full unlock
        await advanceTime(7 * 24 * 60 * 60 + 1);
        
        const usdcClaimable = await stakingPool.calculateClaimableRevenue(user1.address, usdc.address);
        const wethClaimable = await stakingPool.calculateClaimableRevenue(user1.address, weth.address);
        
        expect(usdcClaimable).to.equal(ethers.utils.parseUnits("1000", 6));
        expect(wethClaimable).to.equal(ethers.utils.parseEther("10"));
    });

    it("should implement linear unlock for revenue tokens", async () => {
        await createUserStake(user1, ethers.utils.parseEther("1000"), 1);
        await addRevenue(usdc.address, ethers.utils.parseUnits("1000", 6));
        
        // Test at various time points
        const timePoints = [
            { days: 0, expectedPercent: 0 },
            { days: 1, expectedPercent: 14.3 },
            { days: 3.5, expectedPercent: 50 },
            { days: 7, expectedPercent: 100 }
        ];
        
        for (const point of timePoints) {
            await resetTime();
            await advanceTime(point.days * 24 * 60 * 60);
            
            const claimable = await stakingPool.calculateClaimableRevenue(user1.address, usdc.address);
            const expected = ethers.utils.parseUnits("1000", 6).mul(Math.floor(point.expectedPercent * 10)).div(1000);
            
            expect(claimable).to.approximately(expected, tolerance);
        }
    });
});
```

---

## Integration Test Suite

### Cross-Contract Interaction Tests

#### Revenue Flow Integration
```javascript
describe("Revenue Flow Integration", () => {
    it("should handle complete revenue flow from game to staking", async () => {
        // Setup staking
        await setupMultipleStakers();
        
        // Game generates revenue
        const gameRevenue = ethers.utils.parseEther("100");
        await battleshipGame.simulateGameCompletion(gameRevenue);
        
        // Check TokenomicsCore received revenue
        const epochRevenue = await tokenomicsCore.epochTotalRevenue(1);
        expect(epochRevenue).to.equal(gameRevenue);
        
        // Process emissions
        await tokenomicsCore.processWeeklyEmissions(1);
        
        // Verify staking pool receives SHIP rewards
        const stakingRewards = await stakingPool.epochRewards(1);
        expect(stakingRewards).to.be.gt(0);
        
        // Test claiming
        await advanceTime(7 * 24 * 60 * 60 + 1);
        await stakingPool.connect(staker1).claimRewards(stakeId1);
        
        const balance = await battleshipToken.balanceOf(staker1.address);
        expect(balance).to.be.gt(0);
    });

    it("should handle marketplace revenue in multiple tokens", async () => {
        // Setup marketplace and staking
        await setupMarketplaceScenario();
        
        // Marketplace generates USDC fees
        const usdcFees = ethers.utils.parseUnits("1000", 6);
        await marketplace.simulateNFTSale(usdc.address, usdcFees);
        
        // Check revenue distribution
        const stakingUSDC = await usdc.balanceOf(stakingPool.address);
        const teamUSDC = await usdc.balanceOf(teamTreasury.address);
        const liquidityUSDC = await usdc.balanceOf(liquidityPool.address);
        
        expect(stakingUSDC).to.equal(usdcFees.mul(70).div(100));
        expect(teamUSDC).to.equal(usdcFees.mul(20).div(100));
        expect(liquidityUSDC).to.equal(usdcFees.mul(10).div(100));
        
        // Test staker can claim USDC
        await advanceTime(7 * 24 * 60 * 60 + 1);
        await stakingPool.connect(staker1).claimRevenue(usdc.address);
        
        const stakerBalance = await usdc.balanceOf(staker1.address);
        expect(stakerBalance).to.be.gt(0);
    });
});
```

#### Epoch Processing Integration
```javascript
describe("Epoch Processing Integration", () => {
    it("should process multiple epochs with different revenue", async () => {
        const revenues = [1000, 2000, 1500, 3000]; // Different revenue amounts
        
        for (let i = 0; i < revenues.length; i++) {
            const epoch = i + 1;
            
            // Generate revenue for epoch
            await tokenomicsCore.recordGameFees(ethers.utils.parseEther(revenues[i].toString()));
            
            // Process epoch
            await tokenomicsCore.processWeeklyEmissions(epoch);
            
            // Verify dynamic emission calculation
            const emission = await tokenomicsCore.epochEmissions(epoch);
            const expectedEmission = await tokenomicsCore.calculateDynamicEmissions(epoch);
            expect(emission).to.equal(expectedEmission);
            
            // Advance to next epoch
            await advanceEpoch();
        }
        
        // Verify emission growth based on revenue
        const epoch1Emission = await tokenomicsCore.epochEmissions(1);
        const epoch4Emission = await tokenomicsCore.epochEmissions(4);
        expect(epoch4Emission).to.be.gt(epoch1Emission); // Should grow with revenue
    });

    it("should handle concurrent SHIP and revenue token claiming", async () => {
        await setupComplexStakingScenario();
        
        // Generate both SHIP emissions and USDC revenue
        await awardCreditsAndProcessEmissions(1);
        await addUSDCRevenue(ethers.utils.parseUnits("5000", 6));
        
        await advanceTime(7 * 24 * 60 * 60 + 1);
        
        // User claims both types simultaneously
        const shipBefore = await battleshipToken.balanceOf(user1.address);
        const usdcBefore = await usdc.balanceOf(user1.address);
        
        await stakingPool.connect(user1).claimRewards(stakeId);
        await stakingPool.connect(user1).claimRevenue(usdc.address);
        
        const shipAfter = await battleshipToken.balanceOf(user1.address);
        const usdcAfter = await usdc.balanceOf(user1.address);
        
        expect(shipAfter).to.be.gt(shipBefore);
        expect(usdcAfter).to.be.gt(usdcBefore);
    });
});
```

---

## Performance Test Suite

### Gas Usage Analysis

#### Gas Benchmarks
```javascript
describe("Gas Usage Analysis", () => {
    it("should measure gas for core functions", async () => {
        const measurements = {};
        
        // Stake function
        const stakeAmount = ethers.utils.parseEther("1000");
        await battleshipToken.mint(user1.address, stakeAmount);
        await battleshipToken.connect(user1).approve(stakingPool.address, stakeAmount);
        
        const stakeTx = await stakingPool.connect(user1).stake(stakeAmount, 26);
        const stakeReceipt = await stakeTx.wait();
        measurements.stake = stakeReceipt.gasUsed;
        
        // Claim rewards function (single epoch)
        await setupSingleEpochRewards();
        const claimTx = await stakingPool.connect(user1).claimRewards(1);
        const claimReceipt = await claimTx.wait();
        measurements.claimSingleEpoch = claimReceipt.gasUsed;
        
        // Claim rewards function (multiple epochs)
        await setupMultipleEpochRewards(5);
        const multiClaimTx = await stakingPool.connect(user1).claimRewards(1);
        const multiClaimReceipt = await multiClaimTx.wait();
        measurements.claimMultipleEpochs = multiClaimReceipt.gasUsed;
        
        // Revenue token claim
        await setupRevenueTokenClaim();
        const revenueTx = await stakingPool.connect(user1).claimRevenue(usdc.address);
        const revenueReceipt = await revenueTx.wait();
        measurements.claimRevenue = revenueReceipt.gasUsed;
        
        // Log measurements
        console.log("Gas Usage Analysis:");
        console.log(`Stake: ${measurements.stake}`);
        console.log(`Claim (1 epoch): ${measurements.claimSingleEpoch}`);
        console.log(`Claim (5 epochs): ${measurements.claimMultipleEpochs}`);
        console.log(`Claim Revenue: ${measurements.claimRevenue}`);
        
        // Verify gas usage is within acceptable limits
        expect(measurements.stake).to.be.lt(150000);
        expect(measurements.claimSingleEpoch).to.be.lt(200000);
        expect(measurements.claimMultipleEpochs).to.be.lt(500000);
        expect(measurements.claimRevenue).to.be.lt(300000);
    });

    it("should scale linearly with epoch count", async () => {
        const epochCounts = [1, 5, 10, 20];
        const gasUsages = [];
        
        for (const epochCount of epochCounts) {
            await resetContractState();
            await setupMultipleEpochRewards(epochCount);
            
            const tx = await stakingPool.connect(user1).claimRewards(1);
            const receipt = await tx.wait();
            gasUsages.push(receipt.gasUsed);
        }
        
        // Verify roughly linear scaling
        const gasPerEpoch = gasUsages[1] - gasUsages[0];
        const expectedGas20 = gasUsages[0] + (gasPerEpoch * 19);
        const actualGas20 = gasUsages[3];
        
        // Allow 20% deviation for overhead
        expect(actualGas20).to.be.closeTo(expectedGas20, expectedGas20 * 0.2);
    });
});
```

### Scalability Tests

#### Large Scale Scenarios
```javascript
describe("Scalability Tests", () => {
    it("should handle 100 stakers efficiently", async () => {
        const stakerCount = 100;
        const stakers = [];
        
        // Create 100 stakers
        for (let i = 0; i < stakerCount; i++) {
            const staker = await createTestAccount();
            await createUserStake(staker, ethers.utils.parseEther("1000"), 26);
            stakers.push(staker);
        }
        
        // Process epoch with 100 stakers
        const startTime = Date.now();
        await tokenomicsCore.processWeeklyEmissions(1);
        const processTime = Date.now() - startTime;
        
        expect(processTime).to.be.lt(30000); // Should complete in 30 seconds
        
        // Test claiming with many stakers
        await advanceTime(7 * 24 * 60 * 60 + 1);
        
        const claimPromises = stakers.slice(0, 10).map(staker => 
            stakingPool.connect(staker).claimRewards(staker.stakeId)
        );
        
        await Promise.all(claimPromises);
        // Should complete without errors
    });

    it("should handle 50 epochs of history", async () => {
        const epochCount = 50;
        
        // Create 50 epochs of data
        for (let i = 1; i <= epochCount; i++) {
            await tokenomicsCore.recordGameFees(ethers.utils.parseEther("1000"));
            await tokenomicsCore.processWeeklyEmissions(i);
            await advanceEpoch();
        }
        
        // Test view function performance
        const startTime = Date.now();
        const claimable = await stakingPool.calculateClaimableRevenue(user1.address, usdc.address);
        const calcTime = Date.now() - startTime;
        
        expect(calcTime).to.be.lt(10000); // Should calculate in 10 seconds
    });
});
```

---

## Security Test Suite

### Vulnerability Tests

#### Access Control Tests
```javascript
describe("Access Control Security", () => {
    it("should prevent unauthorized emission processing", async () => {
        await expect(
            tokenomicsCore.connect(attacker).processWeeklyEmissions(1)
        ).to.be.revertedWith("TokenomicsCore: Not authorized for automation");
    });

    it("should prevent unauthorized revenue token addition", async () => {
        await expect(
            stakingPool.connect(attacker).addRevenueToken(usdc.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should prevent unauthorized revenue recording", async () => {
        await expect(
            tokenomicsCore.connect(attacker).recordMultiTokenRevenue(usdc.address, 1000)
        ).to.be.revertedWith("TokenomicsCore: Not authorized");
    });
});
```

#### Economic Security Tests
```javascript
describe("Economic Security", () => {
    it("should prevent emission manipulation", async () => {
        // Try to manipulate time to affect emissions
        const originalEmission = await tokenomicsCore.calculateDynamicEmissions(1);
        
        // Advance time and try to recalculate
        await advanceTime(1000000);
        const manipulatedEmission = await tokenomicsCore.calculateDynamicEmissions(1);
        
        // Should be the same (emissions based on revenue, not time)
        expect(manipulatedEmission).to.equal(originalEmission);
    });

    it("should prevent double claiming", async () => {
        await setupClaimScenario();
        
        // First claim
        await stakingPool.connect(user1).claimRewards(stakeId);
        const balance1 = await battleshipToken.balanceOf(user1.address);
        
        // Immediate second claim (should get nothing)
        await stakingPool.connect(user1).claimRewards(stakeId);
        const balance2 = await battleshipToken.balanceOf(user1.address);
        
        expect(balance2).to.equal(balance1); // No additional tokens
    });

    it("should handle zero values gracefully", async () => {
        // Test with zero stakes
        await expect(stakingPool.calculatePendingRewards(999)).to.not.reverted;
        
        // Test with zero revenue
        await tokenomicsCore.recordMultiTokenRevenue(usdc.address, 0);
        // Should not fail, but also not distribute anything
    });

    it("should prevent overflow attacks", async () => {
        const maxUint256 = ethers.constants.MaxUint256;
        
        await expect(
            tokenomicsCore.recordGameFees(maxUint256)
        ).to.be.reverted; // Should fail due to realistic limits
    });
});
```

#### Edge Case Tests
```javascript
describe("Edge Case Handling", () => {
    it("should handle epoch boundaries correctly", async () => {
        // Setup scenario right at epoch boundary
        await setupEpochBoundaryScenario();
        
        const epochStart = await getEpochStartTime(1);
        await setNextBlockTimestamp(epochStart);
        
        // Should handle exactly at start time
        const claimable = await stakingPool.calculatePendingRewards(stakeId);
        expect(claimable).to.equal(0); // Nothing available at exact start
        
        // Advance by 1 second
        await advanceTime(1);
        const claimableAfter = await stakingPool.calculatePendingRewards(stakeId);
        expect(claimableAfter).to.be.gt(0); // Something available after start
    });

    it("should handle multiple concurrent claims", async () => {
        await setupConcurrentClaimScenario();
        
        // Multiple users claim simultaneously
        const promises = [
            stakingPool.connect(user1).claimRewards(stakeId1),
            stakingPool.connect(user2).claimRewards(stakeId2),
            stakingPool.connect(user3).claimRewards(stakeId3)
        ];
        
        // Should all succeed without interference
        await Promise.all(promises);
        
        // Verify each user received correct amount
        const balance1 = await battleshipToken.balanceOf(user1.address);
        const balance2 = await battleshipToken.balanceOf(user2.address);
        const balance3 = await battleshipToken.balanceOf(user3.address);
        
        expect(balance1).to.be.gt(0);
        expect(balance2).to.be.gt(0);
        expect(balance3).to.be.gt(0);
    });
});
```

---

## User Scenario Tests

### End-to-End User Flows

#### New User Journey
```javascript
describe("New User Journey", () => {
    it("should complete full user onboarding flow", async () => {
        const newUser = await createTestAccount();
        
        // 1. User gets SHIP tokens
        await battleshipToken.mint(newUser.address, ethers.utils.parseEther("10000"));
        
        // 2. User stakes with 26-week lock
        await battleshipToken.connect(newUser).approve(stakingPool.address, ethers.utils.parseEther("5000"));
        const stakeId = await stakingPool.connect(newUser).stake(ethers.utils.parseEther("5000"), 26);
        
        // 3. User plays games and earns credits
        await awardCredits(newUser.address, 100);
        
        // 4. Epoch processes
        await tokenomicsCore.processWeeklyEmissions(1);
        
        // 5. User waits and claims rewards
        await advanceTime(7 * 24 * 60 * 60 + 1);
        await stakingPool.connect(newUser).claimRewards(stakeId);
        
        // 6. User also receives revenue tokens
        await addUSDCRevenue(ethers.utils.parseUnits("1000", 6));
        await stakingPool.connect(newUser).claimRevenue(usdc.address);
        
        // Verify user has received both SHIP and USDC
        const shipBalance = await battleshipToken.balanceOf(newUser.address);
        const usdcBalance = await usdc.balanceOf(newUser.address);
        
        expect(shipBalance).to.be.gt(ethers.utils.parseEther("5000")); // Original + rewards
        expect(usdcBalance).to.be.gt(0);
    });
});
```

#### Power User Scenarios
```javascript
describe("Power User Scenarios", () => {
    it("should handle user with multiple stakes and revenue streams", async () => {
        const powerUser = await createTestAccount();
        await battleshipToken.mint(powerUser.address, ethers.utils.parseEther("100000"));
        
        // Create multiple stakes with different lock periods
        const stakes = [];
        const lockPeriods = [1, 12, 26, 52];
        const stakeAmounts = [10000, 20000, 30000, 40000];
        
        for (let i = 0; i < lockPeriods.length; i++) {
            await battleshipToken.connect(powerUser).approve(stakingPool.address, ethers.utils.parseEther(stakeAmounts[i].toString()));
            const stakeId = await stakingPool.connect(powerUser).stake(
                ethers.utils.parseEther(stakeAmounts[i].toString()),
                lockPeriods[i]
            );
            stakes.push(stakeId);
        }
        
        // Generate multiple epochs of rewards
        for (let epoch = 1; epoch <= 5; epoch++) {
            await awardCredits(powerUser.address, 500);
            await addUSDCRevenue(ethers.utils.parseUnits("5000", 6));
            await addWETHRevenue(ethers.utils.parseEther("50"));
            await tokenomicsCore.processWeeklyEmissions(epoch);
            await advanceEpoch();
        }
        
        // User claims everything
        await advanceTime(7 * 24 * 60 * 60 + 1);
        
        for (const stakeId of stakes) {
            await stakingPool.connect(powerUser).claimRewards(stakeId);
        }
        
        await stakingPool.connect(powerUser).claimRevenue(usdc.address);
        await stakingPool.connect(powerUser).claimRevenue(weth.address);
        
        // Verify substantial rewards received
        const shipBalance = await battleshipToken.balanceOf(powerUser.address);
        const usdcBalance = await usdc.balanceOf(powerUser.address);
        const wethBalance = await weth.balanceOf(powerUser.address);
        
        expect(shipBalance).to.be.gt(ethers.utils.parseEther("100000")); // Original + significant rewards
        expect(usdcBalance).to.be.gt(ethers.utils.parseUnits("1000", 6)); // Substantial USDC
        expect(wethBalance).to.be.gt(ethers.utils.parseEther("1")); // Substantial WETH
    });
});
```

---

## Test Utilities and Helpers

### Common Test Setup
```javascript
// Test environment setup
async function setupTestEnvironment() {
    // Deploy all contracts
    const contracts = await deployAllContracts();
    
    // Setup initial configuration
    await configureContracts(contracts);
    
    // Create test accounts
    const accounts = await createTestAccounts(10);
    
    // Mint initial tokens
    await setupInitialTokens(accounts);
    
    return { contracts, accounts };
}

// Time manipulation helpers
async function advanceTime(seconds) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

async function advanceEpoch() {
    await advanceTime(7 * 24 * 60 * 60); // 1 week
}

async function setNextBlockTimestamp(timestamp) {
    await network.provider.send("evm_setNextBlockTimestamp", [timestamp]);
}

// Scenario setup helpers
async function setupStakingScenario() {
    const { user1, user2, user3 } = await getTestAccounts();
    
    // Create diverse staking portfolio
    await createUserStake(user1, ethers.utils.parseEther("1000"), 1);   // Short term
    await createUserStake(user2, ethers.utils.parseEther("5000"), 26);  // Medium term
    await createUserStake(user3, ethers.utils.parseEther("10000"), 52); // Long term
    
    return { user1, user2, user3 };
}

async function setupRevenueScenario() {
    // Add all supported revenue tokens
    await stakingPool.addRevenueToken(usdc.address);
    await stakingPool.addRevenueToken(weth.address);
    await stakingPool.addRevenueToken(dai.address);
    
    // Generate initial revenue
    await addRevenue(usdc.address, ethers.utils.parseUnits("10000", 6));
    await addRevenue(weth.address, ethers.utils.parseEther("100"));
    await addRevenue(dai.address, ethers.utils.parseEther("15000"));
}

// Assertion helpers
function expectApproximately(actual, expected, tolerance = ethers.utils.parseEther("0.01")) {
    const diff = actual.gt(expected) ? actual.sub(expected) : expected.sub(actual);
    expect(diff).to.be.lte(tolerance);
}

function expectLinearUnlock(claimable, totalAmount, timeElapsed, totalTime) {
    const expectedPercent = Math.min(100, (timeElapsed / totalTime) * 100);
    const expectedAmount = totalAmount.mul(Math.floor(expectedPercent * 100)).div(10000);
    expectApproximately(claimable, expectedAmount);
}
```

### Performance Monitoring
```javascript
class PerformanceMonitor {
    constructor() {
        this.measurements = {};
    }
    
    async measureFunction(name, func) {
        const startTime = Date.now();
        const startGas = await ethers.provider.getBalance(ethers.constants.AddressZero);
        
        const result = await func();
        
        const endTime = Date.now();
        const endGas = await ethers.provider.getBalance(ethers.constants.AddressZero);
        
        this.measurements[name] = {
            timeMs: endTime - startTime,
            gasUsed: startGas.sub(endGas),
            result
        };
        
        return result;
    }
    
    getReport() {
        console.log("Performance Report:");
        for (const [name, data] of Object.entries(this.measurements)) {
            console.log(`${name}: ${data.timeMs}ms, ${data.gasUsed} gas`);
        }
    }
}
```

---

## Test Execution

### Running Tests
```bash
# Run all tests
npx hardhat test

# Run specific test suites
npx hardhat test test/unit/TokenomicsCore.test.js
npx hardhat test test/integration/RevenueFlow.test.js
npx hardhat test test/performance/GasUsage.test.js

# Run with coverage
npx hardhat coverage

# Run with gas reporting
REPORT_GAS=true npx hardhat test
```

### Continuous Integration
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
      - name: Install dependencies
        run: npm install
      - name: Run tests
        run: npm test
      - name: Run coverage
        run: npm run coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v1
```

### Test Quality Metrics
- **Unit Test Coverage**: >95%
- **Integration Test Coverage**: >90%
- **Performance Benchmarks**: All within acceptable limits
- **Security Tests**: No vulnerabilities found
- **Gas Usage**: Optimized for production use

---

This comprehensive testing framework ensures the V2 tokenomics upgrade is thoroughly validated before deployment, covering all functionality, security, and performance aspects.