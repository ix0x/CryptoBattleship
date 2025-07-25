// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface imports
interface IBattleshipToken {
    function mint(address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IGameConfig {
    function getCreditsByGameSize(uint8 gameSize) external view returns (uint256 winner, uint256 loser);
    function getWeeklyEmissionRate() external view returns (uint256);
    function getGameFeePercentage() external view returns (uint256);
}

interface IStakingPool {
    function addRevenueToPool(uint256 amount) external;
    function addRevenueToPool(address token, uint256 amount) external;
}

interface IShipNFTManager {
    function balanceOf(address owner) external view returns (uint256);
    // For retired ship tracking, we'll use ship balance or add a specific function later
}

/**
 * @title TokenomicsCore
 * @dev Core tokenomics contract managing credits, emissions, and revenue distribution
 * 
 * CRITICAL ECONOMIC FUNCTIONS:
 * - Credit tracking with 4-week expiry system
 * - Weekly token emissions based on credit ratios
 * - Revenue collection and distribution
 * - Vesting system for sustainable tokenomics
 */
contract TokenomicsCore is Ownable, ReentrancyGuard, Pausable {

    // =============================================================================
    // CONSTANTS AND IMMUTABLES
    // =============================================================================
    
    uint256 public constant EPOCH_DURATION = 7 days;           // 1 week epochs
    uint256 public constant FULL_CREDIT_EPOCHS = 2;            // 2 epochs full value
    uint256 public constant DECAY_EPOCHS = 3;                  // 3 epochs decay period
    uint256 public constant TOTAL_CREDIT_LIFETIME = 5;         // 2 full + 3 decay = 5 epochs
    uint256 public constant VESTING_DURATION = 1;              // 1 epoch vesting
    uint256 public constant LIQUID_PERCENTAGE = 30;            // 30% liquid, 70% vested
    uint256 public constant MAX_EMISSION_RATE = 1000000 ether; // 1M tokens max per week
    uint256 public constant RETIRED_SHIP_CREDIT = 1 ether;     // 1 credit per retired ship per epoch
    
    // Revenue distribution percentages
    uint256 public constant STAKING_REVENUE_PERCENT = 70;      // 70% to staking
    uint256 public constant TEAM_REVENUE_PERCENT = 20;         // 20% to team
    uint256 public constant LIQUIDITY_REVENUE_PERCENT = 10;    // 10% to liquidity
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    // Contract references
    IBattleshipToken public battleshipToken;
    IGameConfig public gameConfig;
    IStakingPool public stakingPool;
    IShipNFTManager public shipNFTManager;
    address public teamTreasury;
    address public liquidityPool;
    
    // Epoch tracking
    uint256 public genesisTimestamp;
    uint256 public currentEpoch;
    
    // Emission cap system
    bool public emissionCapEnabled;
    uint256 public maxEmissionPercentage = 10;                  // Default 10% max per player
    
    // Admin roles
    mapping(address => bool) public automationAdmins;          // Gelato automation contracts
    
    // Credit tracking
    struct CreditEntry {
        uint256 amount;
        uint256 epoch;
        bool claimed;
    }
    
    mapping(address => CreditEntry[]) public playerCredits;     // Player => Credit entries
    mapping(uint256 => uint256) public epochTotalCredits;       // Epoch => Total credits
    mapping(uint256 => uint256) public epochEmissions;          // Epoch => Tokens emitted
    mapping(uint256 => bool) public epochProcessed;             // Epoch => Processed flag
    
    // Vesting tracking
    struct VestingEntry {
        uint256 amount;
        uint256 startEpoch;
        uint256 claimed;
    }
    
    mapping(address => VestingEntry[]) public playerVesting;    // Player => Vesting entries
    
    // Epoch-based emissions with linear payout
    struct EmissionEpochInfo {
        uint256 totalEmissions;                                 // Total emissions for epoch
        uint256 startTime;                                      // Epoch start time
        uint256 totalCredits;                                   // Total credits for epoch
        mapping(address => uint256) playerClaimed;              // player => claimed amount
    }
    
    mapping(uint256 => EmissionEpochInfo) public emissionEpochInfo; // epoch => emission info
    
    // Revenue tracking
    mapping(uint256 => uint256) public epochGameRevenue;        // Epoch => Game fee revenue
    mapping(uint256 => uint256) public epochLootboxRevenue;     // Epoch => Lootbox revenue
    mapping(uint256 => uint256) public epochTotalRevenue;       // Epoch => Total revenue
    
    // Dynamic emission parameters
    uint256 public emissionRevenueMultiplier = 10;              // 10% of previous week revenue
    mapping(uint256 => uint256) public epochRevenueTotals;      // Track total revenue per epoch for dynamic emissions
    
    // Emergency controls
    mapping(address => bool) public authorizedMinters;         // Authorized to award credits
    bool public emergencyStop;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event CreditsAwarded(address indexed player, uint256 amount, uint256 epoch);
    event EmissionsProcessed(uint256 indexed epoch, uint256 totalEmissions, uint256 totalCredits);
    event EmissionsClaimed(address indexed player, uint256 liquid, uint256 vested);
    event VestingClaimed(address indexed player, uint256 amount);
    event RevenueRecorded(uint256 indexed epoch, uint256 gameRevenue, uint256 lootboxRevenue);
    event RevenueDistributed(uint256 indexed epoch, uint256 stakingAmount, uint256 teamAmount, uint256 liquidityAmount);
    event EpochAdvanced(uint256 indexed newEpoch, uint256 timestamp);
    event EmergencyStopToggled(bool stopped);
    event ContractUpdated(string contractName, address newAddress);
    event EmissionCapUpdated(bool enabled, uint256 percentage);
    event AutomationAdminUpdated(address indexed admin, bool authorized);
    event DynamicEmissionCalculated(uint256 indexed epoch, uint256 baseEmission, uint256 revenueBonus, uint256 totalEmission);
    event MultiTokenRevenueDistributed(address indexed token, uint256 stakingAmount, uint256 teamAmount, uint256 liquidityAmount);
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _battleshipToken,
        address _gameConfig,
        address _shipNFTManager,
        address _teamTreasury
    ) Ownable(msg.sender) {
        require(_battleshipToken != address(0), "TokenomicsCore: Invalid token address");
        require(_gameConfig != address(0), "TokenomicsCore: Invalid config address");
        require(_shipNFTManager != address(0), "TokenomicsCore: Invalid ship NFT manager address");
        require(_teamTreasury != address(0), "TokenomicsCore: Invalid treasury address");
        
        battleshipToken = IBattleshipToken(_battleshipToken);
        gameConfig = IGameConfig(_gameConfig);
        shipNFTManager = IShipNFTManager(_shipNFTManager);
        teamTreasury = _teamTreasury;
        
        genesisTimestamp = block.timestamp;
        currentEpoch = 1;
        
        // Initially authorize owner to award credits
        authorizedMinters[msg.sender] = true;
        automationAdmins[msg.sender] = true;
    }
    
    // =============================================================================
    // SECTION 5.1: CREDIT TRACKING SYSTEM
    // =============================================================================
    
    /**
     * @dev Function1: Award credits to player from game results
     * Only authorized contracts can award credits
     * @param player Address to award credits to
     * @param amount Amount of credits to award
     */
    function awardCredits(address player, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(authorizedMinters[msg.sender], "TokenomicsCore: Not authorized to award credits");
        require(player != address(0), "TokenomicsCore: Invalid player address");
        require(amount > 0, "TokenomicsCore: Invalid credit amount");
        require(!emergencyStop, "TokenomicsCore: Emergency stop active");
        
        // Update epoch if needed
        _updateEpoch();
        
        // Add credit entry for player
        playerCredits[player].push(CreditEntry({
            amount: amount,
            epoch: currentEpoch,
            claimed: false
        }));
        
        // Update epoch totals
        epochTotalCredits[currentEpoch] += amount;
        
        emit CreditsAwarded(player, amount, currentEpoch);
    }
    
    /**
     * @dev Function2: Award credits for retired ships
     * Called automatically each epoch for retired ship holders
     * @param player Address to award credits to
     */
    function awardRetiredShipCredits(address player) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(automationAdmins[msg.sender] || msg.sender == owner(), "TokenomicsCore: Not authorized for automation");
        require(player != address(0), "TokenomicsCore: Invalid player address");
        require(!emergencyStop, "TokenomicsCore: Emergency stop active");
        
        // Update epoch if needed
        _updateEpoch();
        
        // Get ship balance as proxy for retired ship tracking
        // TODO: Add proper retired ship tracking function to ShipNFTManager
        uint256 retiredShipCount = shipNFTManager.balanceOf(player);
        if (retiredShipCount > 0) {
            uint256 creditAmount = retiredShipCount * RETIRED_SHIP_CREDIT;
            
            // Add credit entry for player
            playerCredits[player].push(CreditEntry({
                amount: creditAmount,
                epoch: currentEpoch,
                claimed: false
            }));
            
            // Update epoch totals
            epochTotalCredits[currentEpoch] += creditAmount;
            
            emit CreditsAwarded(player, creditAmount, currentEpoch);
        }
    }
    
    /**
     * @dev Function3: Get player's active credits with decay calculation
     * Credits have 2 epochs full value, then decay over 3 epochs
     * @param player Address to check
     * @return totalCredits Total active credits (with decay applied)
     */
    function getPlayerCredits(address player) external view returns (uint256 totalCredits) {
        CreditEntry[] storage credits = playerCredits[player];
        
        for (uint256 i = 0; i < credits.length; i++) {
            if (!credits[i].claimed) {
                uint256 creditValue = _calculateCreditValue(credits[i].amount, credits[i].epoch);
                totalCredits += creditValue;
            }
        }
    }
    
    /**
     * @dev Calculate credit value with decay
     * @param originalAmount Original credit amount
     * @param creditEpoch Epoch when credit was awarded
     * @return currentValue Current value with decay applied
     */
    function _calculateCreditValue(uint256 originalAmount, uint256 creditEpoch) internal view returns (uint256) {
        if (creditEpoch > currentEpoch) return 0; // Future credits invalid
        
        uint256 ageInEpochs = currentEpoch - creditEpoch;
        
        if (ageInEpochs < FULL_CREDIT_EPOCHS) {
            // Full value for first 2 epochs
            return originalAmount;
        } else if (ageInEpochs < TOTAL_CREDIT_LIFETIME) {
            // Decay over next 3 epochs
            uint256 decayEpochs = ageInEpochs - FULL_CREDIT_EPOCHS;
            uint256 decayPercentage = (decayEpochs * 100) / DECAY_EPOCHS;
            uint256 remainingPercentage = uint256(100) - decayPercentage;
            return (originalAmount * remainingPercentage) / 100;
        } else {
            // Fully expired
            return 0;
        }
    }
    
    /**
     * @dev Function4: Get total active credits across all players
     * Used for emission calculations (includes decay)
     * @return totalCredits Total active credits in system
     */
    function getTotalActiveCredits() external view returns (uint256 totalCredits) {
        for (uint256 epoch = 1; epoch <= currentEpoch; epoch++) {
            if (epochTotalCredits[epoch] > 0) {
                // Calculate decay for this epoch's credits
                uint256 ageInEpochs = currentEpoch - epoch;
                
                if (ageInEpochs < FULL_CREDIT_EPOCHS) {
                    // Full value
                    totalCredits = totalCredits + epochTotalCredits[epoch];
                } else if (ageInEpochs < TOTAL_CREDIT_LIFETIME) {
                    // Decay value
                    uint256 decayEpochs = ageInEpochs - FULL_CREDIT_EPOCHS;
                    uint256 decayPercentage = (decayEpochs * 100) / DECAY_EPOCHS;
                    uint256 remainingPercentage = uint256(100) - decayPercentage;
                    uint256 decayedValue = (epochTotalCredits[epoch] * remainingPercentage) / 100;
                    totalCredits = totalCredits + decayedValue;
                }
                // Fully expired credits add 0
            }
        }
    }
    
    /**
     * @dev Function4: Get current epoch number
     * Epochs start at 1 and increment weekly
     * @return epoch Current epoch number
     */
    function getCurrentEpoch() external view returns (uint256 epoch) {
        return _calculateCurrentEpoch();
    }
    
    /**
     * @dev Internal function to calculate current epoch
     */
    function _calculateCurrentEpoch() internal view returns (uint256) {
        return ((block.timestamp - genesisTimestamp) / EPOCH_DURATION) + 1;
    }
    
    /**
     * @dev Internal function to update epoch if needed
     */
    function _updateEpoch() internal {
        uint256 newEpoch = _calculateCurrentEpoch();
        if (newEpoch > currentEpoch) {
            currentEpoch = newEpoch;
            emit EpochAdvanced(newEpoch, block.timestamp);
        }
    }
    
    // =============================================================================
    // SECTION 5.2: TOKEN EMISSION SYSTEM
    // =============================================================================
    
    /**
     * @dev Function1: Process weekly emissions for an epoch
     * Calculates and distributes tokens based on credit ratios with linear payout
     * Can be called by automation admins (Gelato)
     * @param epoch Epoch to process emissions for
     */
    function processWeeklyEmissions(uint256 epoch) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(automationAdmins[msg.sender] || msg.sender == owner(), "TokenomicsCore: Not authorized for automation");
        require(epoch > 0 && epoch <= currentEpoch, "TokenomicsCore: Invalid epoch");
        require(!epochProcessed[epoch], "TokenomicsCore: Epoch already processed");
        require(epoch < currentEpoch || block.timestamp >= genesisTimestamp + (epoch * EPOCH_DURATION), 
                "TokenomicsCore: Epoch not yet finished");
        
        // Calculate dynamic emissions for this epoch
        uint256 emissionRate = calculateDynamicEmissions(epoch);
        require(emissionRate <= MAX_EMISSION_RATE, "TokenomicsCore: Emission rate too high");
        
        uint256 totalCredits = this.getTotalActiveCredits();
        require(totalCredits > 0, "TokenomicsCore: No active credits for epoch");
        
        // Setup emission epoch info for linear payout
        emissionEpochInfo[epoch].totalEmissions = emissionRate;
        emissionEpochInfo[epoch].startTime = genesisTimestamp + ((epoch - 1) * EPOCH_DURATION);
        emissionEpochInfo[epoch].totalCredits = totalCredits;
        
        // Mark epoch as processed
        epochProcessed[epoch] = true;
        epochEmissions[epoch] = emissionRate;
        
        emit EmissionsProcessed(epoch, emissionRate, totalCredits);
    }
    
    /**
     * @dev Function2: Get emission info for an epoch
     * @param epoch Epoch to check
     * @return totalCredits Total credits for epoch
     * @return emissionAmount Tokens emitted for epoch
     * @return liquidAmount Liquid tokens available
     * @return vestedAmount Vested tokens amount
     */
    function getEmissionInfo(uint256 epoch) 
        external 
        view 
        returns (
            uint256 totalCredits,
            uint256 emissionAmount,
            uint256 liquidAmount,
            uint256 vestedAmount
        ) 
    {
        totalCredits = epochTotalCredits[epoch]; // Simplified for compilation
        emissionAmount = epochEmissions[epoch];
        liquidAmount = (emissionAmount * LIQUID_PERCENTAGE) / 100;
        vestedAmount = emissionAmount - liquidAmount;
    }
    
    /**
     * @dev Function3: Claim emissions for a player with linear payout
     * Distributes tokens based on time elapsed in each epoch
     * @param player Address to claim for
     */
    function claimEmissions(address player) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(player != address(0), "TokenomicsCore: Invalid player address");
        
        uint256 totalLiquid = 0;
        uint256 totalVested = 0;
        
        // Process all processed epochs
        for (uint256 epoch = 1; epoch <= currentEpoch; epoch++) {
            if (epochProcessed[epoch]) {
                EmissionEpochInfo storage epochInfo = emissionEpochInfo[epoch];
                
                if (epochInfo.totalEmissions > 0 && epochInfo.totalCredits > 0) {
                    // Calculate player's total credits for this epoch
                    uint256 playerCredits = _getPlayerCreditsForEpoch(player, epoch);
                    
                    if (playerCredits > 0) {
                        // Calculate player's share of epoch emissions
                        uint256 playerShare = (epochInfo.totalEmissions * playerCredits) / epochInfo.totalCredits;
                        
                        // Apply emission cap if enabled
                        if (emissionCapEnabled) {
                            uint256 maxAllowed = (epochInfo.totalEmissions * maxEmissionPercentage) / 100;
                            if (playerShare > maxAllowed) {
                                playerShare = maxAllowed;
                            }
                        }
                        
                        // Calculate available amount (linear over week)
                        uint256 epochStart = epochInfo.startTime;
                        uint256 epochEnd = epochStart + EPOCH_DURATION;
                        uint256 timeNow = block.timestamp;
                        
                        uint256 availableAmount;
                        if (timeNow >= epochEnd) {
                            // Full week has passed, all emissions available
                            availableAmount = playerShare;
                        } else if (timeNow > epochStart) {
                            // Partial week, linear distribution
                            uint256 elapsed = timeNow - epochStart;
                            availableAmount = playerShare * elapsed / EPOCH_DURATION;
                        } else {
                            // Epoch hasn't started yet
                            availableAmount = 0;
                        }
                        
                        // Claim unclaimed portion
                        uint256 alreadyClaimed = epochInfo.playerClaimed[player];
                        if (availableAmount > alreadyClaimed) {
                            uint256 claimableAmount = availableAmount - alreadyClaimed;
                            epochInfo.playerClaimed[player] = availableAmount;
                            
                            // Split into liquid and vested
                            uint256 liquidShare = claimableAmount * LIQUID_PERCENTAGE / 100;
                            uint256 vestedShare = claimableAmount - liquidShare;
                            
                            totalLiquid = totalLiquid + liquidShare;
                            totalVested = totalVested + vestedShare;
                        }
                    }
                }
            }
        }
        
        require(totalLiquid > 0 || totalVested > 0, "TokenomicsCore: No emissions to claim");
        
        // Mint and transfer liquid tokens
        if (totalLiquid > 0) {
            battleshipToken.mint(player, totalLiquid);
        }
        
        // Create vesting entry (vests over 1 epoch)
        if (totalVested > 0) {
            playerVesting[player].push(VestingEntry({
                amount: totalVested,
                startEpoch: currentEpoch,
                claimed: 0
            }));
        }
        
        emit EmissionsClaimed(player, totalLiquid, totalVested);
    }
    
    /**
     * @dev Get player's credits for a specific epoch with decay applied
     * @param player Player address
     * @param epoch Epoch to check
     * @return totalCredits Total credits for epoch
     */
    function _getPlayerCreditsForEpoch(address player, uint256 epoch) internal view returns (uint256 totalCredits) {
        CreditEntry[] storage credits = playerCredits[player];
        
        for (uint256 i = 0; i < credits.length; i++) {
            if (credits[i].epoch == epoch) {
                totalCredits = totalCredits + _calculateCreditValue(credits[i].amount, credits[i].epoch);
            }
        }
    }
    
    /**
     * @dev Function4: Get claimable emissions for a player with linear payout
     * @param player Address to check
     * @return liquid Liquid tokens available
     * @return vested Vested tokens amount
     */
    function getClaimableEmissions(address player) 
        external 
        view 
        returns (uint256 liquid, uint256 vested) 
    {
        // Process all processed epochs
        for (uint256 epoch = 1; epoch <= currentEpoch; epoch++) {
            if (epochProcessed[epoch]) {
                EmissionEpochInfo storage epochInfo = emissionEpochInfo[epoch];
                
                if (epochInfo.totalEmissions > 0 && epochInfo.totalCredits > 0) {
                    // Calculate player's total credits for this epoch
                    uint256 playerCredits = _getPlayerCreditsForEpoch(player, epoch);
                    
                    if (playerCredits > 0) {
                        // Calculate player's share of epoch emissions
                        uint256 playerShare = (epochInfo.totalEmissions * playerCredits) / epochInfo.totalCredits;
                        
                        // Apply emission cap if enabled
                        if (emissionCapEnabled) {
                            uint256 maxAllowed = (epochInfo.totalEmissions * maxEmissionPercentage) / 100;
                            if (playerShare > maxAllowed) {
                                playerShare = maxAllowed;
                            }
                        }
                        
                        // Calculate available amount (linear over week)
                        uint256 epochStart = epochInfo.startTime;
                        uint256 epochEnd = epochStart + EPOCH_DURATION;
                        uint256 timeNow = block.timestamp;
                        
                        uint256 availableAmount;
                        if (timeNow >= epochEnd) {
                            // Full week has passed, all emissions available
                            availableAmount = playerShare;
                        } else if (timeNow > epochStart) {
                            // Partial week, linear distribution
                            uint256 elapsed = timeNow - epochStart;
                            availableAmount = playerShare * elapsed / EPOCH_DURATION;
                        } else {
                            // Epoch hasn't started yet
                            availableAmount = 0;
                        }
                        
                        // Calculate claimable amount
                        uint256 alreadyClaimed = epochInfo.playerClaimed[player];
                        if (availableAmount > alreadyClaimed) {
                            uint256 claimableAmount = availableAmount - alreadyClaimed;
                            
                            // Split into liquid and vested
                            uint256 liquidShare = claimableAmount * LIQUID_PERCENTAGE / 100;
                            uint256 vestedShare = claimableAmount - liquidShare;
                            
                            liquid = liquid + liquidShare;
                            vested = vested + vestedShare;
                        }
                    }
                }
            }
        }
    }
    
    // =============================================================================
    // EMISSION CAP AND AUTOMATION ADMIN FUNCTIONS
    // =============================================================================
    
    /**
     * @dev Set emission cap parameters
     * @param enabled Whether to enable emission cap
     * @param percentage Maximum percentage per player (1-100)
     */
    function setEmissionCap(bool enabled, uint256 percentage) 
        external 
        onlyOwner 
    {
        require(percentage > 0 && percentage <= 100, "TokenomicsCore: Invalid percentage");
        
        emissionCapEnabled = enabled;
        maxEmissionPercentage = percentage;
        
        emit EmissionCapUpdated(enabled, percentage);
    }
    
    /**
     * @dev Calculate dynamic emissions based on previous week's revenue
     * @param epoch Current epoch to calculate emissions for
     * @return totalEmission Total emission amount (base + revenue bonus)
     */
    function calculateDynamicEmissions(uint256 epoch) 
        public 
        view 
        returns (uint256 totalEmission) 
    {
        uint256 baseEmission = gameConfig.getWeeklyEmissionRate();
        uint256 revenueBonus = 0;
        
        if (epoch > 1) {
            uint256 previousEpochRevenue = epochRevenueTotals[epoch - 1];
            revenueBonus = (previousEpochRevenue * emissionRevenueMultiplier) / 100;
        }
        
        totalEmission = baseEmission + revenueBonus;
        
        // Cap at maximum emission rate
        if (totalEmission > MAX_EMISSION_RATE) {
            totalEmission = MAX_EMISSION_RATE;
        }
        
        return totalEmission;
    }
    
    /**
     * @dev Set dynamic emission parameters
     * @param multiplier Percentage of previous week revenue to add to emissions (0-50)
     */
    function setEmissionRevenueMultiplier(uint256 multiplier) 
        external 
        onlyOwner 
    {
        require(multiplier <= 50, "TokenomicsCore: Multiplier too high");
        emissionRevenueMultiplier = multiplier;
    }
    
    /**
     * @dev Add automation admin (for Gelato)
     * @param admin Address to add as automation admin
     */
    function addAutomationAdmin(address admin) external onlyOwner {
        require(admin != address(0), "TokenomicsCore: Invalid admin address");
        automationAdmins[admin] = true;
        emit AutomationAdminUpdated(admin, true);
    }
    
    /**
     * @dev Remove automation admin
     * @param admin Address to remove as automation admin
     */
    function removeAutomationAdmin(address admin) external onlyOwner {
        automationAdmins[admin] = false;
        emit AutomationAdminUpdated(admin, false);
    }
    
    // =============================================================================
    // VESTING SYSTEM
    // =============================================================================
    
    /**
     * @dev Claim available vested tokens
     * Tokens vest linearly over 4 weeks
     * @param player Address to claim for
     */
    function claimVestedTokens(address player) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(player != address(0), "TokenomicsCore: Invalid player address");
        
        uint256 totalClaimable = 0;
        VestingEntry[] storage vestingEntries = playerVesting[player];
        
        for (uint256 i = 0; i < vestingEntries.length; i++) {
            uint256 claimable = _calculateVestedAmount(vestingEntries[i]);
            if (claimable > 0) {
                totalClaimable = totalClaimable + claimable;
                vestingEntries[i].claimed = vestingEntries[i].claimed + claimable;
            }
        }
        
        require(totalClaimable > 0, "TokenomicsCore: No vested tokens to claim");
        
        // Mint and transfer vested tokens
        battleshipToken.mint(player, totalClaimable);
        
        emit VestingClaimed(player, totalClaimable);
    }
    
    /**
     * @dev Get claimable vested tokens for a player
     * @param player Address to check
     * @return claimable Amount of vested tokens available
     */
    function getClaimableVestedTokens(address player) external view returns (uint256 claimable) {
        VestingEntry[] storage vestingEntries = playerVesting[player];
        
        for (uint256 i = 0; i < vestingEntries.length; i++) {
            claimable = claimable + _calculateVestedAmount(vestingEntries[i]);
        }
    }
    
    /**
     * @dev Internal function to calculate vested amount for an entry
     */
    function _calculateVestedAmount(VestingEntry storage entry) internal view returns (uint256) {
        uint256 epochsPassed = currentEpoch > entry.startEpoch ? currentEpoch - entry.startEpoch : 0;
        
        if (epochsPassed >= VESTING_DURATION) {
            // Fully vested
            return entry.amount - entry.claimed;
        } else {
            // Partially vested
            uint256 vestedAmount = (entry.amount * epochsPassed) / VESTING_DURATION;
            return vestedAmount > entry.claimed ? vestedAmount - entry.claimed : 0;
        }
    }
    
    // =============================================================================
    // SECTION 5.3: REVENUE TRACKING AND DISTRIBUTION
    // =============================================================================
    
    /**
     * @dev Function1: Record game fee revenue
     * Called by BattleshipGame when games complete
     * @param amount Revenue amount to record
     */
    function recordGameFees(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(authorizedMinters[msg.sender], "TokenomicsCore: Not authorized");
        require(amount > 0, "TokenomicsCore: Invalid amount");
        
        _updateEpoch();
        
        epochGameRevenue[currentEpoch] += amount;
        epochTotalRevenue[currentEpoch] += amount;
        epochRevenueTotals[currentEpoch] += amount;
        
        emit RevenueRecorded(currentEpoch, epochGameRevenue[currentEpoch], epochLootboxRevenue[currentEpoch]);
    }
    
    /**
     * @dev Function2: Record lootbox revenue
     * Called by LootboxSystem when lootboxes are purchased
     * @param amount Revenue amount to record
     */
    function recordLootboxRevenue(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(authorizedMinters[msg.sender], "TokenomicsCore: Not authorized");
        require(amount > 0, "TokenomicsCore: Invalid amount");
        
        _updateEpoch();
        
        epochLootboxRevenue[currentEpoch] += amount;
        epochTotalRevenue[currentEpoch] += amount;
        epochRevenueTotals[currentEpoch] += amount;
        
        emit RevenueRecorded(currentEpoch, epochGameRevenue[currentEpoch], epochLootboxRevenue[currentEpoch]);
    }
    
    /**
     * @dev Function2b: Record marketplace revenue
     * Called by MarketplaceCore when NFTs are traded
     * @param amount Revenue amount to record
     */
    function recordMarketplaceRevenue(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(authorizedMinters[msg.sender], "TokenomicsCore: Not authorized");
        require(amount > 0, "TokenomicsCore: Invalid amount");
        
        _updateEpoch();
        
        // Add marketplace revenue to lootbox revenue for distribution
        // (Future: could track separately if needed)
        epochLootboxRevenue[currentEpoch] += amount;
        epochTotalRevenue[currentEpoch] += amount;
        epochRevenueTotals[currentEpoch] += amount;
        
        emit RevenueRecorded(currentEpoch, epochGameRevenue[currentEpoch], epochLootboxRevenue[currentEpoch]);
    }
    
    /**
     * @dev Record multi-token revenue and distribute directly to staking
     * @param token Revenue token address
     * @param amount Revenue amount to record
     */
    function recordMultiTokenRevenue(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(authorizedMinters[msg.sender], "TokenomicsCore: Not authorized");
        require(token != address(0), "TokenomicsCore: Invalid token");
        require(amount > 0, "TokenomicsCore: Invalid amount");
        
        _updateEpoch();
        
        // Transfer tokens to this contract first
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Calculate distribution (keep same percentages)
        uint256 stakingAmount = (amount * STAKING_REVENUE_PERCENT) / 100;
        uint256 teamAmount = (amount * TEAM_REVENUE_PERCENT) / 100;
        uint256 liquidityAmount = (amount * LIQUIDITY_REVENUE_PERCENT) / 100;
        
        // Send staking portion directly to staking pool
        if (stakingAmount > 0 && address(stakingPool) != address(0)) {
            IERC20(token).approve(address(stakingPool), stakingAmount);
            stakingPool.addRevenueToPool(token, stakingAmount);
        }
        
        // Send team portion to treasury
        if (teamAmount > 0) {
            IERC20(token).transfer(teamTreasury, teamAmount);
        }
        
        // Send liquidity portion to liquidity pool
        if (liquidityAmount > 0 && liquidityPool != address(0)) {
            IERC20(token).transfer(liquidityPool, liquidityAmount);
        }
        
        emit MultiTokenRevenueDistributed(token, stakingAmount, teamAmount, liquidityAmount);
    }
    
    /**
     * @dev Function3: Get weekly revenue totals
     * @return gameRevenue Game fee revenue for current epoch
     * @return lootboxRevenue Lootbox revenue for current epoch
     * @return totalRevenue Total revenue for current epoch
     */
    function getWeeklyRevenue() 
        external 
        view 
        returns (
            uint256 gameRevenue,
            uint256 lootboxRevenue,
            uint256 totalRevenue
        ) 
    {
        gameRevenue = epochGameRevenue[currentEpoch];
        lootboxRevenue = epochLootboxRevenue[currentEpoch];
        totalRevenue = epochTotalRevenue[currentEpoch];
    }
    
    /**
     * @dev Function4: Distribute revenue according to tokenomics
     * 70% to staking, 20% to team, 10% to liquidity
     * @param epoch Epoch to distribute revenue for
     */
    function distributeRevenue(uint256 epoch) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyOwner 
    {
        require(epoch > 0 && epoch < currentEpoch, "TokenomicsCore: Invalid epoch");
        require(epochTotalRevenue[epoch] > 0, "TokenomicsCore: No revenue to distribute");
        
        uint256 totalRevenue = epochTotalRevenue[epoch];
        
        // Calculate distribution amounts
        uint256 stakingAmount = (totalRevenue * STAKING_REVENUE_PERCENT) / 100;
        uint256 teamAmount = (totalRevenue * TEAM_REVENUE_PERCENT) / 100;
        uint256 liquidityAmount = (totalRevenue * LIQUIDITY_REVENUE_PERCENT) / 100;
        
        // Distribute to staking pool
        if (stakingAmount > 0 && address(stakingPool) != address(0)) {
            battleshipToken.mint(address(this), stakingAmount);
            battleshipToken.transfer(address(stakingPool), stakingAmount);
            stakingPool.addRevenueToPool(stakingAmount);
        }
        
        // Distribute to team treasury
        if (teamAmount > 0) {
            battleshipToken.mint(teamTreasury, teamAmount);
        }
        
        // Distribute to liquidity pool
        if (liquidityAmount > 0 && liquidityPool != address(0)) {
            battleshipToken.mint(liquidityPool, liquidityAmount);
        }
        
        // Clear epoch revenue to prevent double distribution
        epochTotalRevenue[epoch] = 0;
        epochGameRevenue[epoch] = 0;
        epochLootboxRevenue[epoch] = 0;
        
        emit RevenueDistributed(epoch, stakingAmount, teamAmount, liquidityAmount);
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
        require(newAddress != address(0), "TokenomicsCore: Invalid address");
        
        bytes32 nameHash = keccak256(abi.encodePacked(contractName));
        
        if (nameHash == keccak256(abi.encodePacked("BattleshipToken"))) {
            battleshipToken = IBattleshipToken(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("GameConfig"))) {
            gameConfig = IGameConfig(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("StakingPool"))) {
            stakingPool = IStakingPool(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("ShipNFTManager"))) {
            shipNFTManager = IShipNFTManager(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("TeamTreasury"))) {
            teamTreasury = newAddress;
        } else if (nameHash == keccak256(abi.encodePacked("LiquidityPool"))) {
            liquidityPool = newAddress;
        } else {
            revert("TokenomicsCore: Unknown contract name");
        }
        
        emit ContractUpdated(contractName, newAddress);
    }
    
    /**
     * @dev Set authorization for credit minting
     * @param minter Address to authorize/deauthorize
     * @param authorized Whether address is authorized
     */
    function setAuthorizedMinter(address minter, bool authorized) 
        external 
        onlyOwner 
    {
        require(minter != address(0), "TokenomicsCore: Invalid minter address");
        authorizedMinters[minter] = authorized;
    }
    
    /**
     * @dev Emergency stop toggle
     * @param stopped Whether to stop all operations
     */
    function setEmergencyStop(bool stopped) external onlyOwner {
        emergencyStop = stopped;
        emit EmergencyStopToggled(stopped);
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
     * @dev Force epoch update
     * Emergency function to manually advance epoch
     */
    function forceEpochUpdate() external onlyOwner {
        _updateEpoch();
    }
    
    /**
     * @dev Emergency token recovery
     * Only for tokens accidentally sent to contract
     * @param token Token address to recover
     * @param amount Amount to recover
     */
    function emergencyTokenRecovery(address token, uint256 amount) 
        external 
        onlyOwner 
    {
        require(token != address(battleshipToken), "TokenomicsCore: Cannot recover SHIP tokens");
        require(token != address(0), "TokenomicsCore: Invalid token address");
        
        IBattleshipToken(token).transfer(owner(), amount);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS FOR FRONTEND
    // =============================================================================
    
    /**
     * @dev Get player's credit history
     * @param player Address to check
     * @return credits Array of credit entries
     */
    function getPlayerCreditHistory(address player) 
        external 
        view 
        returns (CreditEntry[] memory credits) 
    {
        return playerCredits[player];
    }
    
    /**
     * @dev Get player's vesting history
     * @param player Address to check
     * @return vesting Array of vesting entries
     */
    function getPlayerVestingHistory(address player) 
        external 
        view 
        returns (VestingEntry[] memory vesting) 
    {
        return playerVesting[player];
    }
    
    /**
     * @dev Get epoch statistics
     * @param epoch Epoch to check
     * @return totalCredits Total credits for epoch
     * @return emissions Tokens emitted for epoch
     * @return gameRevenue Game revenue for epoch
     * @return lootboxRevenue Lootbox revenue for epoch
     * @return processed Whether epoch is processed
     */
    function getEpochStats(uint256 epoch) 
        external 
        view 
        returns (
            uint256 totalCredits,
            uint256 emissions,
            uint256 gameRevenue,
            uint256 lootboxRevenue,
            bool processed
        ) 
    {
        totalCredits = epochTotalCredits[epoch];
        emissions = epochEmissions[epoch];
        gameRevenue = epochGameRevenue[epoch];
        lootboxRevenue = epochLootboxRevenue[epoch];
        processed = epochProcessed[epoch];
    }
    
    /**
     * @dev Get system overview
     * @return currentEpoch_ Current epoch number
     * @return epochStartTime Time when current epoch started
     * @return totalActiveCredits Total active credits in system
     * @return nextEpochTime Time when next epoch begins
     */
    function getSystemOverview() 
        external 
        view 
        returns (
            uint256 currentEpoch_,
            uint256 epochStartTime,
            uint256 totalActiveCredits,
            uint256 nextEpochTime
        ) 
    {
        currentEpoch_ = currentEpoch;
        epochStartTime = genesisTimestamp + ((currentEpoch - 1) * EPOCH_DURATION);
        totalActiveCredits = this.getTotalActiveCredits();
        nextEpochTime = epochStartTime + EPOCH_DURATION;
    }
} 