// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface imports
interface IBattleshipToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ITokenomicsCore {
    function distributeStakingRewards() external returns (uint256 rewardAmount);
    function getStakingRewardPool() external view returns (uint256);
    function getCurrentEpoch() external view returns (uint256);
}

/**
 * @title StakingPool
 * @dev SHIP token staking with flexible lock periods and compound rewards
 * 
 * STAKING MECHANICS:
 * - Flexible staking periods (1 week to 52 weeks)
 * - Higher multipliers for longer lock periods
 * - Compound staking available
 * - Early withdrawal with penalties
 * 
 * REWARD DISTRIBUTION:
 * - Weekly rewards from TokenomicsCore (70% of protocol revenue)
 * - Pro-rata distribution based on weighted stakes
 * - Automatic compound option
 * - Vesting for large withdrawals
 */
contract StakingPool is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // =============================================================================
    // CONSTANTS AND IMMUTABLES
    // =============================================================================
    
    uint256 public constant MIN_STAKE_AMOUNT = 1 ether;        // 1 SHIP minimum
    uint256 public constant MAX_STAKE_AMOUNT = 1000000 ether;  // 1M SHIP maximum
    uint256 public constant MIN_LOCK_WEEKS = 1;                // 1 week minimum
    uint256 public constant MAX_LOCK_WEEKS = 52;               // 1 year maximum
    uint256 public constant SECONDS_PER_WEEK = 604800;        // 7 days
    
    // Multiplier system (base 1000 = 1x)
    uint256 public constant BASE_MULTIPLIER = 1000;           // 1x for 1 week
    uint256 public constant MAX_MULTIPLIER = 2000;            // 2x for 52 weeks
    uint256 public constant MULTIPLIER_STEP = 19;             // ~0.02x per week
    
    // Penalty system
    uint256 public constant EARLY_WITHDRAWAL_PENALTY = 25;    // 25% penalty
    uint256 public constant PENALTY_REDUCTION_WEEKS = 4;      // Penalty reduces over time
    
    // =============================================================================
    // STRUCTS
    // =============================================================================
    
    struct StakeInfo {
        uint256 amount;                    // Staked amount
        uint256 lockWeeks;                 // Lock period in weeks
        uint256 startTime;                 // Stake start timestamp
        uint256 lastRewardClaim;           // Last reward claim timestamp
        uint256 multiplier;                // Stake multiplier (1000 = 1x)
        uint256 totalRewardsClaimed;       // Total rewards claimed
    }
    
    struct PoolStats {
        uint256 totalStaked;               // Total SHIP staked
        uint256 totalWeightedStake;        // Total weighted stake (with multipliers)
        uint256 totalRewardsDistributed;   // Total rewards distributed
        uint256 totalRewardsClaimed;       // Total rewards claimed by users
        uint256 currentEpoch;              // Current reward epoch
        uint256 lastDistribution;          // Last distribution timestamp
    }
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    // Contract references
    IBattleshipToken public battleshipToken;
    ITokenomicsCore public tokenomicsCore;
    
    // Pool state
    PoolStats public poolStats;
    uint256 public nextStakeId = 1;
    
    // Staking data
    mapping(address => uint256[]) public userStakeIds;        // User => StakeIds
    mapping(uint256 => StakeInfo) public stakes;              // StakeId => StakeInfo
    mapping(uint256 => address) public stakeOwners;           // StakeId => Owner
    
    // Reward tracking
    mapping(uint256 => uint256) public epochRewards;          // Epoch => Reward amount
    mapping(uint256 => uint256) public epochWeightedStake;    // Epoch => Weighted stake
    mapping(address => uint256) public userTotalRewards;      // User => Total rewards
    mapping(uint256 => mapping(uint256 => bool)) public stakeRewardsClaimed; // StakeId => Epoch => Claimed
    
    // Multi-token revenue system
    struct RevenuePool {
        uint256 totalDeposited;
        uint256 totalClaimed;
        mapping(uint256 => uint256) epochDeposits;             // epoch => amount
        mapping(address => mapping(uint256 => uint256)) userClaims; // user => epoch => claimed
    }
    
    mapping(address => RevenuePool) public revenuePools;      // token => pool
    address[] public revenueTokens;                           // supported revenue tokens
    mapping(address => bool) public isRevenueToken;           // token => supported
    
    // Epoch-based reward distribution
    struct EpochRewardInfo {
        uint256 totalRewards;                                  // Total rewards for epoch
        uint256 startTime;                                     // Epoch start time
        uint256 totalWeightedStake;                            // Total weighted stake for epoch
        mapping(address => uint256) userClaimed;               // user => claimed amount
    }
    
    mapping(uint256 => EpochRewardInfo) public epochRewardInfo; // epoch => reward info
    uint256 public currentRewardEpoch = 1;                     // Current reward epoch
    
    // Emergency and configuration
    bool public emergencyWithdrawEnabled = false;
    uint256 public emergencyWithdrawPenalty = 50;             // 50% penalty during emergency
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 lockWeeks,
        uint256 multiplier
    );
    
    event Unstaked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 penalty
    );
    
    event RewardsClaimed(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        bool compounded
    );
    
    event RevenueDeposited(
        address indexed token,
        uint256 indexed epoch,
        uint256 amount
    );
    
    event RevenueClaimed(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    
    event RevenueTokenAdded(
        address indexed token
    );
    
    event RewardsDistributed(
        uint256 indexed epoch,
        uint256 totalRewards,
        uint256 totalWeightedStake
    );
    
    
    event EmergencyWithdrawEnabled(bool enabled, uint256 penalty);
    event ContractUpdated(string contractName, address newAddress);
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _battleshipToken,
        address _tokenomicsCore
    ) Ownable(msg.sender) {
        require(_battleshipToken != address(0), "StakingPool: Invalid token address");
        require(_tokenomicsCore != address(0), "StakingPool: Invalid tokenomics address");
        
        battleshipToken = IBattleshipToken(_battleshipToken);
        tokenomicsCore = ITokenomicsCore(_tokenomicsCore);
        
        // Initialize pool stats
        poolStats.currentEpoch = 1;
        poolStats.lastDistribution = block.timestamp;
    }
    
    // =============================================================================
    // SECTION 7.1: STAKING MECHANICS AND REWARDS CALCULATION
    // =============================================================================
    
    /**
     * @dev Function1: Stake SHIP tokens with lock period
     * @param amount Amount of SHIP to stake
     * @param lockWeeks Lock period in weeks (1-52)
     * @return stakeId Generated stake ID
     */
    function stake(uint256 amount, uint256 lockWeeks) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 stakeId) 
    {
        require(amount >= MIN_STAKE_AMOUNT, "StakingPool: Amount below minimum");
        require(amount <= MAX_STAKE_AMOUNT, "StakingPool: Amount above maximum");
        require(lockWeeks >= MIN_LOCK_WEEKS && lockWeeks <= MAX_LOCK_WEEKS, 
                "StakingPool: Invalid lock period");
        
        // Transfer tokens to contract
        battleshipToken.transferFrom(msg.sender, address(this), amount);
        
        // Calculate multiplier based on lock period
        uint256 multiplier = _calculateMultiplier(lockWeeks);
        uint256 weightedAmount = (amount * multiplier) / BASE_MULTIPLIER;
        
        // Create stake
        stakeId = nextStakeId++;
        stakes[stakeId] = StakeInfo({
            amount: amount,
            lockWeeks: lockWeeks,
            startTime: block.timestamp,
            lastRewardClaim: block.timestamp,
            multiplier: multiplier,
            totalRewardsClaimed: 0
        });
        
        stakeOwners[stakeId] = msg.sender;
        userStakeIds[msg.sender].push(stakeId);
        
        // Update pool stats
        poolStats.totalStaked += amount;
        poolStats.totalWeightedStake += weightedAmount;
        
        emit Staked(msg.sender, stakeId, amount, lockWeeks, multiplier);
        
        return stakeId;
    }
    
    /**
     * @dev Function2: Calculate staking multiplier based on lock period
     * @param lockWeeks Lock period in weeks
     * @return multiplier Multiplier value (1000 = 1x)
     */
    function _calculateMultiplier(uint256 lockWeeks) internal pure returns (uint256) {
        if (lockWeeks >= MAX_LOCK_WEEKS) {
            return MAX_MULTIPLIER;
        }
        
        // Linear increase: 1x at 1 week, 2x at 52 weeks
        return BASE_MULTIPLIER + ((lockWeeks - 1) * MULTIPLIER_STEP);
    }
    
    /**
     * @dev Function3: Calculate pending rewards for a stake with linear payout
     * @param stakeId Stake ID to check
     * @return pendingRewards Amount of pending rewards
     */
    function calculatePendingRewards(uint256 stakeId) 
        public 
        view 
        returns (uint256 pendingRewards) 
    {
        StakeInfo memory stakeInfo = stakes[stakeId];
        if (stakeInfo.amount == 0) return 0;
        
        address stakeOwner = stakeOwners[stakeId];
        uint256 weightedStake = (stakeInfo.amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
        uint256 totalPending = 0;
        
        // Calculate rewards from each completed epoch
        uint256 currentEpoch = _getCurrentEpoch();
        
        for (uint256 epoch = 1; epoch < currentEpoch; epoch++) {
            EpochRewardInfo storage epochInfo = epochRewardInfo[epoch];
            
            if (epochInfo.totalRewards > 0 && epochInfo.totalWeightedStake > 0) {
                // Check if user was staking during this epoch
                uint256 stakeEpoch = _getEpochFromTimestamp(stakeInfo.startTime);
                if (stakeEpoch <= epoch) {
                    // Calculate user's share of epoch rewards
                    uint256 userEpochReward = epochInfo.totalRewards
                        * weightedStake
                        / epochInfo.totalWeightedStake;
                    
                    // Calculate how much of this epoch's rewards are available (linear over week)
                    uint256 epochStart = epochInfo.startTime;
                    uint256 epochEnd = epochStart + SECONDS_PER_WEEK;
                    uint256 timeNow = block.timestamp;
                    
                    uint256 availableReward;
                    if (timeNow >= epochEnd) {
                        // Full week has passed, all rewards available
                        availableReward = userEpochReward;
                    } else if (timeNow > epochStart) {
                        // Partial week, linear distribution
                        uint256 elapsed = timeNow - epochStart;
                        availableReward = (userEpochReward * elapsed) / SECONDS_PER_WEEK;
                    } else {
                        // Epoch hasn't started yet
                        availableReward = 0;
                    }
                    
                    // Subtract already claimed amount
                    uint256 alreadyClaimed = epochInfo.userClaimed[stakeOwner];
                    if (availableReward > alreadyClaimed) {
                        totalPending += (availableReward - alreadyClaimed);
                    }
                }
            }
        }
        
        return totalPending;
    }
    
    /**
     * @dev Function4: Get epoch number from timestamp
     * @param timestamp Timestamp to convert
     * @return epoch Epoch number
     */
    function _getEpochFromTimestamp(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / SECONDS_PER_WEEK) + 1;
    }
    
    /**
     * @dev Function5: Check if stake is locked
     * @param stakeId Stake ID to check
     * @return locked Whether stake is still locked
     * @return unlockTime When stake unlocks
     */
    function isStakeLocked(uint256 stakeId) 
        public 
        view 
        returns (bool locked, uint256 unlockTime) 
    {
        StakeInfo memory stakeInfo = stakes[stakeId];
        unlockTime = stakeInfo.startTime + (stakeInfo.lockWeeks * SECONDS_PER_WEEK);
        locked = block.timestamp < unlockTime;
    }
    
    /**
     * @dev Function6: Calculate early withdrawal penalty
     * @param stakeId Stake ID
     * @return penalty Penalty percentage (0-25)
     */
    function calculateWithdrawalPenalty(uint256 stakeId) 
        public 
        view 
        returns (uint256 penalty) 
    {
        (bool locked, uint256 unlockTime) = isStakeLocked(stakeId);
        
        if (!locked) return 0;
        
        // Penalty reduces over time
        uint256 timeRemaining = unlockTime - block.timestamp;
        uint256 weeksRemaining = timeRemaining / SECONDS_PER_WEEK;
        
        if (weeksRemaining >= PENALTY_REDUCTION_WEEKS) {
            return EARLY_WITHDRAWAL_PENALTY;
        } else {
            // Linear reduction: 25% -> 0% over 4 weeks
            return (EARLY_WITHDRAWAL_PENALTY * weeksRemaining) / PENALTY_REDUCTION_WEEKS;
        }
    }
    
    // =============================================================================
    // SECTION 7.2: REWARD DISTRIBUTION AND CLAIMING
    // =============================================================================
    
    /**
     * @dev Function1: Distribute weekly rewards from TokenomicsCore
     * Called by TokenomicsCore or manually
     * @return rewardAmount Amount of rewards distributed
     */
    function distributeRewards() 
        external 
        nonReentrant 
        returns (uint256 rewardAmount) 
    {
        // Check if we need to advance epoch
        _updateRewardEpoch();
        
        // Get rewards from TokenomicsCore
        rewardAmount = tokenomicsCore.distributeStakingRewards();
        
        if (rewardAmount > 0 && poolStats.totalWeightedStake > 0) {
            // Setup epoch reward info
            epochRewardInfo[currentRewardEpoch].totalRewards = rewardAmount;
            epochRewardInfo[currentRewardEpoch].startTime = block.timestamp;
            epochRewardInfo[currentRewardEpoch].totalWeightedStake = poolStats.totalWeightedStake;
            
            // Update legacy tracking for compatibility
            epochRewards[currentRewardEpoch] = rewardAmount;
            epochWeightedStake[currentRewardEpoch] = poolStats.totalWeightedStake;
            
            // Update pool stats
            poolStats.totalRewardsDistributed += rewardAmount;
            poolStats.lastDistribution = block.timestamp;
            
            emit RewardsDistributed(currentRewardEpoch, rewardAmount, poolStats.totalWeightedStake);
            
            // Advance to next epoch for future distributions
            currentRewardEpoch += 1;
        }
        
        return rewardAmount;
    }
    
    /**
     * @dev Update reward epoch if needed
     */
    function _updateRewardEpoch() internal {
        uint256 expectedEpoch = _getCurrentEpoch();
        if (expectedEpoch > currentRewardEpoch) {
            currentRewardEpoch = expectedEpoch;
        }
    }
    
    /**
     * @dev Internal function to process rewards claim
     * @param stakeId Stake ID to claim rewards for
     * @param rewardAmount Amount of rewards to claim
     */
    function _processRewardsClaim(uint256 stakeId, uint256 rewardAmount) internal {
        if (rewardAmount == 0) return;
        
        StakeInfo storage stakeInfo = stakes[stakeId];
        uint256 weightedStake = (stakeInfo.amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
        uint256 currentEpoch = _getCurrentEpoch();
        
        // Process rewards from all completed epochs
        for (uint256 epoch = 1; epoch < currentEpoch; epoch++) {
            EpochRewardInfo storage epochInfo = epochRewardInfo[epoch];
            
            if (epochInfo.totalRewards > 0 && epochInfo.totalWeightedStake > 0) {
                uint256 stakeEpoch = _getEpochFromTimestamp(stakeInfo.startTime);
                if (stakeEpoch <= epoch && !stakeRewardsClaimed[stakeId][epoch]) {
                    uint256 stakeReward = (epochInfo.totalRewards * weightedStake) / epochInfo.totalWeightedStake;
                    if (stakeReward > 0) {
                        stakeRewardsClaimed[stakeId][epoch] = true;
                        stakeInfo.totalRewardsClaimed += stakeReward;
                        poolStats.totalRewardsClaimed += stakeReward;
                        
                        require(battleshipToken.transfer(stakeOwners[stakeId], stakeReward), "StakingPool: Reward transfer failed");
                    }
                }
            }
        }
    }
    
    /**
     * @dev Function2: Claim rewards for a specific stake
     * @param stakeId Stake ID to claim rewards for
     * @return rewardAmount Amount of rewards claimed
     */
    function claimRewards(uint256 stakeId) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 rewardAmount) 
    {
        require(stakeOwners[stakeId] == msg.sender, "StakingPool: Not stake owner");
        
        StakeInfo memory stakeInfo = stakes[stakeId];
        require(stakeInfo.amount > 0, "StakingPool: Stake not found");
        
        uint256 weightedStake = (stakeInfo.amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
        uint256 currentEpoch = _getCurrentEpoch();
        rewardAmount = 0;
        
        // Claim from all completed epochs
        for (uint256 epoch = 1; epoch < currentEpoch; epoch++) {
            EpochRewardInfo storage epochInfo = epochRewardInfo[epoch];
            
            if (epochInfo.totalRewards > 0 && epochInfo.totalWeightedStake > 0) {
                uint256 stakeEpoch = _getEpochFromTimestamp(stakeInfo.startTime);
                if (stakeEpoch <= epoch) {
                    // Calculate user's share of epoch rewards
                    uint256 userEpochReward = epochInfo.totalRewards
                        * weightedStake
                        / epochInfo.totalWeightedStake;
                    
                    // Calculate available reward (linear over week)
                    uint256 epochStart = epochInfo.startTime;
                    uint256 epochEnd = epochStart + SECONDS_PER_WEEK;
                    uint256 timeNow = block.timestamp;
                    
                    uint256 availableReward;
                    if (timeNow >= epochEnd) {
                        availableReward = userEpochReward;
                    } else if (timeNow > epochStart) {
                        uint256 elapsed = timeNow - epochStart;
                        availableReward = (userEpochReward * elapsed) / SECONDS_PER_WEEK;
                    } else {
                        availableReward = 0;
                    }
                    
                    // Claim unclaimed portion
                    uint256 alreadyClaimed = epochInfo.userClaimed[msg.sender];
                    if (availableReward > alreadyClaimed) {
                        uint256 claimableAmount = availableReward - alreadyClaimed;
                        epochInfo.userClaimed[msg.sender] = availableReward;
                        rewardAmount += claimableAmount;
                    }
                }
            }
        }
        
        require(rewardAmount > 0, "StakingPool: No rewards to claim");
        
        // Update stake info
        stakes[stakeId].lastRewardClaim = block.timestamp;
        stakes[stakeId].totalRewardsClaimed += rewardAmount;
        userTotalRewards[msg.sender] += rewardAmount;
        
        // Transfer rewards to user
        battleshipToken.transfer(msg.sender, rewardAmount);
        
        emit RewardsClaimed(msg.sender, stakeId, rewardAmount, false);
        
        return rewardAmount;
    }
    
    
    /**
     * @dev Function4: Claim rewards for all user stakes
     * @return totalRewards Total rewards claimed
     */
    function claimAllRewards() 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 totalRewards) 
    {
        uint256[] memory stakeIds = userStakeIds[msg.sender];
        require(stakeIds.length > 0, "StakingPool: No stakes found");
        
        for (uint256 i = 0; i < stakeIds.length; i++) {
            uint256 stakeId = stakeIds[i];
            uint256 pending = calculatePendingRewards(stakeId);
            
            if (pending > 0) {
                // Update stake info
                stakes[stakeId].lastRewardClaim = block.timestamp;
                stakes[stakeId].totalRewardsClaimed += pending;
                
                totalRewards += pending;
                
                emit RewardsClaimed(msg.sender, stakeId, pending, false);
            }
        }
        
        if (totalRewards > 0) {
            userTotalRewards[msg.sender] += totalRewards;
            battleshipToken.transfer(msg.sender, totalRewards);
        }
    }
    
    
    // =============================================================================
    // SECTION 7.3: STAKING POOL MANAGEMENT AND ANALYTICS
    // =============================================================================
    
    /**
     * @dev Function1: Unstake tokens (with or without penalty)
     * @param stakeId Stake ID to unstake
     * @param amount Amount to unstake (0 = full amount)
     * @return unstakedAmount Amount actually unstaked
     * @return penaltyAmount Penalty amount deducted
     */
    function unstake(uint256 stakeId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 unstakedAmount, uint256 penaltyAmount) 
    {
        require(stakeOwners[stakeId] == msg.sender, "StakingPool: Not stake owner");
        
        StakeInfo storage stakeInfo = stakes[stakeId];
        require(stakeInfo.amount > 0, "StakingPool: Stake not found");
        
        // Determine unstake amount
        if (amount == 0 || amount > stakeInfo.amount) {
            amount = stakeInfo.amount;
        }
        
        // Claim any pending rewards first
        uint256 pendingRewards = calculatePendingRewards(stakeId);
        if (pendingRewards > 0) {
            _processRewardsClaim(stakeId, pendingRewards);
        }
        
        // Calculate penalty
        uint256 penaltyRate = calculateWithdrawalPenalty(stakeId);
        penaltyAmount = (amount * penaltyRate) / 100;
        unstakedAmount = amount - penaltyAmount;
        
        // Update stake info
        uint256 weightedReduction = (amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
        stakeInfo.amount -= amount;
        
        // Update pool stats
        poolStats.totalStaked -= amount;
        poolStats.totalWeightedStake -= weightedReduction;
        
        // Transfer unstaked tokens directly to user
        battleshipToken.transfer(msg.sender, unstakedAmount);
        
        // Burn penalty tokens (remove from circulation)
        if (penaltyAmount > 0) {
            // Note: In production, you might want to redistribute penalties
            // For now, we keep them in the contract as additional rewards
        }
        
        emit Unstaked(msg.sender, stakeId, amount, penaltyAmount);
        
        return (unstakedAmount, penaltyAmount);
    }
    
    
    /**
     * @dev Function4: Emergency unstake (when enabled)
     * @param stakeId Stake ID to emergency unstake
     * @return unstakedAmount Amount unstaked after penalty
     */
    function emergencyUnstake(uint256 stakeId) 
        external 
        nonReentrant 
        returns (uint256 unstakedAmount) 
    {
        require(emergencyWithdrawEnabled, "StakingPool: Emergency withdraw not enabled");
        require(stakeOwners[stakeId] == msg.sender, "StakingPool: Not stake owner");
        
        StakeInfo storage stakeInfo = stakes[stakeId];
        require(stakeInfo.amount > 0, "StakingPool: Stake not found");
        
        uint256 amount = stakeInfo.amount;
        uint256 penaltyAmount = (amount * emergencyWithdrawPenalty) / 100;
        unstakedAmount = amount - penaltyAmount;
        
        // Update stake and pool stats
        uint256 weightedReduction = (amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
        stakeInfo.amount = 0;
        poolStats.totalStaked -= amount;
        poolStats.totalWeightedStake -= weightedReduction;
        
        // Transfer tokens
        battleshipToken.transfer(msg.sender, unstakedAmount);
        
        emit Unstaked(msg.sender, stakeId, amount, penaltyAmount);
        
        return unstakedAmount;
    }
    
    /**
     * @dev Function5: Get comprehensive pool statistics
     */
    function getPoolStats() 
        external 
        view 
        returns (
            uint256 totalStaked,
            uint256 totalWeightedStake,
            uint256 totalRewardsDistributed,
            uint256 currentEpoch,
            uint256 lastDistribution,
            uint256 averageMultiplier,
            uint256 totalStakers
        ) 
    {
        totalStaked = poolStats.totalStaked;
        totalWeightedStake = poolStats.totalWeightedStake;
        totalRewardsDistributed = poolStats.totalRewardsDistributed;
        currentEpoch = poolStats.currentEpoch;
        lastDistribution = poolStats.lastDistribution;
        
        // Calculate average multiplier
        if (totalStaked > 0) {
            averageMultiplier = (totalWeightedStake * BASE_MULTIPLIER) / totalStaked;
        } else {
            averageMultiplier = BASE_MULTIPLIER;
        }
        
        // Count total unique stakers
        totalStakers = _countTotalStakers();
    }
    
    /**
     * @dev Function6: Count total unique stakers
     * @return count Number of unique stakers
     */
    function _countTotalStakers() internal view returns (uint256 count) {
        // This is a simplified count - in production you might want to track this more efficiently
        for (uint256 i = 1; i < nextStakeId; i++) {
            if (stakes[i].amount > 0) {
                count++;
            }
        }
    }
    
    /**
     * @dev Function7: Get user staking summary
     * @param user User address
     * @return totalStaked Total amount staked by user
     * @return totalWeighted Total weighted stake
     * @return totalRewards Total rewards earned
     * @return activeStakes Number of active stakes
     * @return pendingRewards Total pending rewards
     */
    function getUserStakingSummary(address user) 
        external 
        view 
        returns (
            uint256 totalStaked,
            uint256 totalWeighted,
            uint256 totalRewards,
            uint256 activeStakes,
            uint256 pendingRewards
        ) 
    {
        uint256[] memory stakeIds = userStakeIds[user];
        totalRewards = userTotalRewards[user];
        
        for (uint256 i = 0; i < stakeIds.length; i++) {
            uint256 stakeId = stakeIds[i];
            StakeInfo memory stakeInfo = stakes[stakeId];
            
            if (stakeInfo.amount > 0) {
                totalStaked += stakeInfo.amount;
                totalWeighted += (stakeInfo.amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
                pendingRewards += calculatePendingRewards(stakeId);
                activeStakes++;
            }
        }
    }
    
    /**
     * @dev Function8: Get user stake details
     * @param user User address
     * @return stakeIds Array of stake IDs
     * @return amounts Array of stake amounts
     * @return lockWeeks Array of lock periods
     * @return multipliers Array of multipliers
     * @return unlockTimes Array of unlock timestamps
     */
    function getUserStakes(address user) 
        external 
        view 
        returns (
            uint256[] memory stakeIds,
            uint256[] memory amounts,
            uint256[] memory lockWeeks,
            uint256[] memory multipliers,
            uint256[] memory unlockTimes
        ) 
    {
        uint256[] memory userStakes = userStakeIds[user];
        uint256 activeCount = 0;
        
        // Count active stakes
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (stakes[userStakes[i]].amount > 0) {
                activeCount++;
            }
        }
        
        // Initialize arrays
        stakeIds = new uint256[](activeCount);
        amounts = new uint256[](activeCount);
        lockWeeks = new uint256[](activeCount);
        multipliers = new uint256[](activeCount);
        unlockTimes = new uint256[](activeCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < userStakes.length; i++) {
            uint256 stakeId = userStakes[i];
            StakeInfo memory stakeInfo = stakes[stakeId];
            
            if (stakeInfo.amount > 0) {
                stakeIds[index] = stakeId;
                amounts[index] = stakeInfo.amount;
                lockWeeks[index] = stakeInfo.lockWeeks;
                multipliers[index] = stakeInfo.multiplier;
                unlockTimes[index] = stakeInfo.startTime + (stakeInfo.lockWeeks * SECONDS_PER_WEEK);
                index++;
            }
        }
    }
    
    
    // =============================================================================
    // INTERFACE COMPATIBILITY FUNCTIONS (IStakingPool)
    // =============================================================================
    
    // Simple stake function removed to avoid compilation issues
    // Use stake(amount, lockWeeks) directly
    
    // Simple unstake function removed to avoid compilation issues  
    // Use unstake(stakeId, amount) directly
    
    /**
     * @dev Get total staked amount for a user (interface compatibility)
     * @param user User address
     * @return totalStaked Total amount staked by user
     */
    function getStakedAmount(address user) external view returns (uint256 totalStaked) {
        uint256[] memory userStakes = userStakeIds[user];
        
        for (uint256 i = 0; i < userStakes.length; i++) {
            totalStaked += stakes[userStakes[i]].amount;
        }
    }
    
    /**
     * @dev Get total staked amount in pool (interface compatibility)
     * @return totalStaked Total amount staked in pool
     */
    function getTotalStaked() external view returns (uint256 totalStaked) {
        return poolStats.totalStaked;
    }
    
    // Batch claim rewards function temporarily disabled for compilation
    // Use claimRewards(stakeId) directly for each stake
    /*
    function claimRewards() external {
        uint256[] memory userStakes = userStakeIds[msg.sender];
        
        for (uint256 i = 0; i < userStakes.length; i++) {
            uint256 stakeId = userStakes[i];
            if (calculatePendingRewards(stakeId) > 0) {
                claimRewards(stakeId);
            }
        }
    }
    */
    
    /**
     * @dev Get claimable rewards for user (interface compatibility)
     * @param user User address
     * @return claimableRewards Total claimable rewards
     */
    function getClaimableRewards(address user) external view returns (uint256 claimableRewards) {
        uint256[] memory userStakes = userStakeIds[user];
        
        for (uint256 i = 0; i < userStakes.length; i++) {
            claimableRewards += calculatePendingRewards(userStakes[i]);
        }
    }
    
    // Add revenue function temporarily disabled for compilation
    // Use distributeRewards() directly
    /*
    function addRevenueToPool(uint256 amount) external {
        require(msg.sender == address(tokenomicsCore) || msg.sender == owner(), 
                "StakingPool: Not authorized");
        
        if (amount > 0) {
            distributeRewards();
        }
    }
    */
    
    /**
     * @dev Add multi-token revenue to pool
     * @param token Revenue token address
     * @param amount Amount of revenue to add
     */
    function addRevenueToPool(address token, uint256 amount) external nonReentrant {
        require(msg.sender == address(tokenomicsCore) || msg.sender == owner(), 
                "StakingPool: Not authorized");
        require(isRevenueToken[token], "StakingPool: Token not supported");
        require(amount > 0, "StakingPool: Invalid amount");
        
        // Transfer tokens to pool
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update revenue pool
        uint256 currentEpoch = _getCurrentEpoch();
        revenuePools[token].totalDeposited += amount;
        revenuePools[token].epochDeposits[currentEpoch] += amount;
        
        emit RevenueDeposited(token, currentEpoch, amount);
    }
    
    /**
     * @dev Add supported revenue token
     * @param token Token address to add
     */
    function addRevenueToken(address token) external onlyOwner {
        require(token != address(0), "StakingPool: Invalid token");
        require(!isRevenueToken[token], "StakingPool: Token already supported");
        
        isRevenueToken[token] = true;
        revenueTokens.push(token);
        
        emit RevenueTokenAdded(token);
    }
    
    /**
     * @dev Calculate claimable revenue for user in specific token
     * @param user User address
     * @param token Revenue token address
     * @return claimable Claimable amount
     */
    function calculateClaimableRevenue(address user, address token) 
        external 
        view 
        returns (uint256 claimable) 
    {
        if (!isRevenueToken[token]) return 0;
        
        uint256[] memory stakeIds = userStakeIds[user];
        uint256 currentEpoch = _getCurrentEpoch();
        
        for (uint256 epoch = 1; epoch < currentEpoch; epoch++) {
            uint256 epochDeposit = revenuePools[token].epochDeposits[epoch];
            if (epochDeposit == 0) continue;
            
            uint256 userShare = 0;
            uint256 totalWeightedAtEpoch = epochWeightedStake[epoch];
            
            if (totalWeightedAtEpoch > 0) {
                // Calculate user's weighted stake at this epoch
                for (uint256 i = 0; i < stakeIds.length; i++) {
                    uint256 stakeId = stakeIds[i];
                    StakeInfo memory stakeInfo = stakes[stakeId];
                    
                    // Check if stake was active during this epoch
                    uint256 stakeEpoch = _getEpochFromTimestamp(stakeInfo.startTime);
                    if (stakeEpoch <= epoch) {
                        uint256 weightedStake = (stakeInfo.amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
                        userShare += weightedStake;
                    }
                }
                
                if (userShare > 0) {
                    uint256 epochReward = (epochDeposit * userShare) / totalWeightedAtEpoch;
                    uint256 alreadyClaimed = revenuePools[token].userClaims[user][epoch];
                    if (epochReward > alreadyClaimed) {
                        claimable += (epochReward - alreadyClaimed);
                    }
                }
            }
        }
    }
    
    /**
     * @dev Claim revenue in specific token
     * @param token Revenue token to claim
     * @return claimed Amount claimed
     */
    function claimRevenue(address token) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 claimed) 
    {
        require(isRevenueToken[token], "StakingPool: Token not supported");
        
        claimed = this.calculateClaimableRevenue(msg.sender, token);
        require(claimed > 0, "StakingPool: No revenue to claim");
        
        // Update claimed amounts
        uint256[] memory stakeIds = userStakeIds[msg.sender];
        uint256 currentEpoch = _getCurrentEpoch();
        
        for (uint256 epoch = 1; epoch < currentEpoch; epoch++) {
            uint256 epochDeposit = revenuePools[token].epochDeposits[epoch];
            if (epochDeposit == 0) continue;
            
            uint256 userShare = 0;
            uint256 totalWeightedAtEpoch = epochWeightedStake[epoch];
            
            if (totalWeightedAtEpoch > 0) {
                for (uint256 i = 0; i < stakeIds.length; i++) {
                    uint256 stakeId = stakeIds[i];
                    StakeInfo memory stakeInfo = stakes[stakeId];
                    
                    uint256 stakeEpoch = _getEpochFromTimestamp(stakeInfo.startTime);
                    if (stakeEpoch <= epoch) {
                        uint256 weightedStake = (stakeInfo.amount * stakeInfo.multiplier) / BASE_MULTIPLIER;
                        userShare += weightedStake;
                    }
                }
                
                if (userShare > 0) {
                    uint256 epochReward = (epochDeposit * userShare) / totalWeightedAtEpoch;
                    revenuePools[token].userClaims[msg.sender][epoch] = epochReward;
                }
            }
        }
        
        // Transfer tokens to user
        revenuePools[token].totalClaimed += claimed;
        IERC20(token).safeTransfer(msg.sender, claimed);
        
        emit RevenueClaimed(msg.sender, token, claimed);
    }
    
    /**
     * @dev Get current epoch
     * @return epoch Current epoch number
     */
    function _getCurrentEpoch() internal view returns (uint256) {
        return (block.timestamp / SECONDS_PER_WEEK) + 1;
    }
    
    /**
     * @dev Get supported revenue tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedRevenueTokens() external view returns (address[] memory) {
        return revenueTokens;
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================
    
    /**
     * @dev Update contract references
     * @param contractName Name of contract to update
     * @param newAddress New contract address
     */
    function updateContract(string calldata contractName, address newAddress) 
        external 
        onlyOwner 
    {
        require(newAddress != address(0), "StakingPool: Invalid address");
        
        bytes32 nameHash = keccak256(abi.encodePacked(contractName));
        
        if (nameHash == keccak256(abi.encodePacked("BattleshipToken"))) {
            battleshipToken = IBattleshipToken(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("TokenomicsCore"))) {
            tokenomicsCore = ITokenomicsCore(newAddress);
        } else {
            revert("StakingPool: Unknown contract name");
        }
        
        emit ContractUpdated(contractName, newAddress);
    }
    
    /**
     * @dev Enable/disable emergency withdrawals
     * @param enabled Whether to enable emergency withdrawals
     * @param penalty Penalty percentage for emergency withdrawals
     */
    function setEmergencyWithdraw(bool enabled, uint256 penalty) 
        external 
        onlyOwner 
    {
        require(penalty <= 100, "StakingPool: Invalid penalty percentage");
        
        emergencyWithdrawEnabled = enabled;
        emergencyWithdrawPenalty = penalty;
        
        emit EmergencyWithdrawEnabled(enabled, penalty);
    }
    
    /**
     * @dev Pause contract operations
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecoverToken(address token, uint256 amount) 
        external 
        onlyOwner 
    {
        require(amount > 0, "StakingPool: Invalid amount");
        IERC20(token).safeTransfer(owner(), amount);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS FOR FRONTEND
    // =============================================================================
    
    /**
     * @dev Get staking multiplier for a given lock period
     * @param lockWeeks Lock period in weeks
     * @return multiplier Multiplier value (1000 = 1x)
     */
    function getStakingMultiplier(uint256 lockWeeks) 
        external 
        pure 
        returns (uint256 multiplier) 
    {
        if (lockWeeks < MIN_LOCK_WEEKS || lockWeeks > MAX_LOCK_WEEKS) {
            return 0;
        }
        return _calculateMultiplier(lockWeeks);
    }
    
    /**
     * @dev Get current reward rate (rewards per week per weighted stake)
     * @return rewardRate Current reward rate
     */
    function getCurrentRewardRate() 
        external 
        view 
        returns (uint256 rewardRate) 
    {
        uint256 rewardPool = tokenomicsCore.getStakingRewardPool();
        
        if (poolStats.totalWeightedStake > 0) {
            rewardRate = (rewardPool * 1e18) / poolStats.totalWeightedStake;
        }
    }
    
    /**
     * @dev Estimate APY for a given lock period
     * @param lockWeeks Lock period in weeks
     * @return apy Estimated APY percentage (100 = 100%)
     */
    function estimateAPY(uint256 lockWeeks) 
        external 
        view 
        returns (uint256 apy) 
    {
        uint256 multiplier = _calculateMultiplier(lockWeeks);
        uint256 rewardRate = this.getCurrentRewardRate();
        
        if (rewardRate > 0) {
            // Calculate weekly return rate
            uint256 weeklyRate = (rewardRate * multiplier) / BASE_MULTIPLIER;
            // Annualize (52 weeks per year)
            apy = (weeklyRate * 52) / 1e16; // Convert to percentage
        }
    }
    
    /**
     * @dev Get system configuration
     * @return minStake Minimum stake amount
     * @return maxStake Maximum stake amount
     * @return minLockWeeks Minimum lock period
     * @return maxLockWeeks Maximum lock period
     * @return baseMultiplier Base multiplier
     * @return maxMultiplier Maximum multiplier
     */
    function getSystemConfig() 
        external 
        pure 
        returns (
            uint256 minStake,
            uint256 maxStake,
            uint256 minLockWeeks,
            uint256 maxLockWeeks,
            uint256 baseMultiplier,
            uint256 maxMultiplier
        ) 
    {
        minStake = MIN_STAKE_AMOUNT;
        maxStake = MAX_STAKE_AMOUNT;
        minLockWeeks = MIN_LOCK_WEEKS;
        maxLockWeeks = MAX_LOCK_WEEKS;
        baseMultiplier = BASE_MULTIPLIER;
        maxMultiplier = MAX_MULTIPLIER;
    }
} 