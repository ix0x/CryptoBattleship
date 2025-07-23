// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Interface imports
interface IBattleshipToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ITokenomicsCore {
    function recordLootboxRevenue(uint256 amount) external;
}

interface IShipNFTManager {
    enum ShipType { DESTROYER, SUBMARINE, CRUISER, BATTLESHIP, CARRIER }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    function mintShip(address recipient, ShipType shipType, Rarity rarity) external returns (uint256 tokenId);
}

interface IActionNFTManager {
    enum ActionCategory { OFFENSIVE, DEFENSIVE }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    function mintAction(address recipient, ActionCategory category, Rarity rarity) external returns (uint256 tokenId);
}

interface ICaptainAndCrewNFTManager {
    enum CaptainAbility { DAMAGE_BOOST, SPEED_BOOST, DEFENSE_BOOST, VISION_BOOST, LUCK_BOOST }
    enum CrewType { GUNNER, ENGINEER, NAVIGATOR, MEDIC }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    function mintCaptain(address recipient, CaptainAbility ability, Rarity rarity) external returns (uint256 tokenId);
    function mintCrew(address recipient, CrewType crewType, Rarity rarity) external returns (uint256 tokenId);
}

interface IGameConfig {
    function getLootboxActionChance() external view returns (uint256);
    function getLootboxCaptainChance() external view returns (uint256);
    function getLootboxCrewChance() external view returns (uint256);
}

/**
 * @title LootboxSystem
 * @dev Lootbox mechanics with multi-token payments and revenue distribution
 * 
 * LOOTBOX CONTENTS:
 * - 1 Ship (guaranteed, random type and rarity)
 * - 60% chance for Action NFT  
 * - 40% chance for second Action NFT
 * - 5% chance for Captain NFT
 * - 30% chance for Crew NFT
 * 
 * REVENUE DISTRIBUTION:
 * - 70% to staking rewards pool
 * - 20% to team treasury  
 * - 10% to liquidity pool
 */
contract LootboxSystem is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // =============================================================================
    // CONSTANTS AND IMMUTABLES
    // =============================================================================
    
    uint256 public constant MAX_LOOTBOX_PRICE = 1000000 ether;  // Max price protection
    uint256 public constant MIN_LOOTBOX_PRICE = 1 ether;       // Min price protection
    
    // Drop rate constants (out of 10000 for precision)
    uint256 public constant SHIP_GUARANTEE = 10000;            // 100% ship guarantee
    uint256 public constant ACTION_BASE_CHANCE = 6000;         // 60% for first action
    uint256 public constant ACTION_BONUS_CHANCE = 4000;        // 40% for second action
    uint256 public constant CAPTAIN_CHANCE = 500;              // 5% captain chance
    uint256 public constant CREW_CHANCE = 3000;                // 30% crew chance
    
    // Configurable rarity distribution (out of 10000) - can be updated by admin
    uint256 public commonRate = 5000;                          // 50%
    uint256 public uncommonRate = 3000;                        // 30%
    uint256 public rareRate = 1500;                            // 15%
    uint256 public epicRate = 400;                             // 4%
    uint256 public legendaryRate = 100;                        // 1%
    
    // Legacy constants for backward compatibility
    uint256 public constant COMMON_RATE = 5000;                // 50%
    uint256 public constant UNCOMMON_RATE = 3000;              // 30%
    uint256 public constant RARE_RATE = 1500;                  // 15%
    uint256 public constant EPIC_RATE = 400;                   // 4%
    uint256 public constant LEGENDARY_RATE = 100;              // 1%
    
    // Configurable drop chances for different NFT types
    uint256 public shipDropRate = 10000;                       // Ships (100% guaranteed)
    uint256 public actionDropRate = 6000;                      // Actions (60% base chance)  
    uint256 public bonusActionDropRate = 4000;                 // Bonus actions (40% chance)
    uint256 public captainDropRate = 500;                      // Captains (5% chance)
    uint256 public crewDropRate = 3000;                        // Crew (30% chance)
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    // Contract references
    IBattleshipToken public battleshipToken;
    ITokenomicsCore public tokenomicsCore;
    IShipNFTManager public shipNFTManager;
    IActionNFTManager public actionNFTManager;
    ICaptainAndCrewNFTManager public captainAndCrewNFTManager;
    IGameConfig public gameConfig;
    
    // Lootbox configuration
    mapping(address => uint256) public lootboxPrices;          // Token => Price
    mapping(address => bool) public acceptedTokens;           // Token => Accepted
    address[] public paymentTokens;                           // Array of accepted tokens
    
    // Lootbox tracking
    uint256 public nextLootboxId = 1;
    mapping(uint256 => address) public lootboxOwners;         // LootboxId => Owner
    mapping(uint256 => bool) public lootboxOpened;            // LootboxId => Opened
    mapping(uint256 => uint256) public lootboxPurchaseTime;   // LootboxId => Timestamp
    
    // Revenue tracking
    uint256 public totalRevenue;
    mapping(address => uint256) public revenueByToken;        // Token => Revenue amount
    mapping(uint256 => uint256) public dailyRevenue;          // Day => Revenue
    
    // Statistics
    uint256 public totalLootboxesSold;
    uint256 public totalLootboxesOpened;
    mapping(address => uint256) public playerPurchases;       // Player => Purchase count
    
    // Random seed for drop generation
    uint256 private randomSeed;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event LootboxPurchased(
        address indexed buyer, 
        uint256 indexed lootboxId, 
        address indexed paymentToken, 
        uint256 amount
    );
    
    event LootboxOpened(
        address indexed opener, 
        uint256 indexed lootboxId, 
        uint256[] nftIds,
        uint8[] nftTypes,
        uint8[] rarities
    );
    
    event RevenueDistributed(
        uint256 stakingAmount, 
        uint256 teamAmount, 
        uint256 liquidityAmount
    );
    
    event PaymentTokenUpdated(address indexed token, uint256 price, bool accepted);
    event ContractUpdated(string contractName, address newAddress);
    event RandomSeedUpdated(uint256 newSeed);
    event DropRatesUpdated(uint256[4] shipRates, uint256[4] actionRates, uint256 captainRate, uint256 crewRate);
    event RarityRatesUpdated(uint256 common, uint256 uncommon, uint256 rare, uint256 epic, uint256 legendary);
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _battleshipToken,
        address _tokenomicsCore,
        address _shipNFTManager,
        address _actionNFTManager,
        address _captainAndCrewNFTManager,
        address _gameConfig
    ) Ownable(msg.sender) {
        require(_battleshipToken != address(0), "LootboxSystem: Invalid token address");
        require(_tokenomicsCore != address(0), "LootboxSystem: Invalid tokenomics address");
        require(_shipNFTManager != address(0), "LootboxSystem: Invalid ship NFT manager address");
        require(_actionNFTManager != address(0), "LootboxSystem: Invalid action NFT manager address");
        require(_captainAndCrewNFTManager != address(0), "LootboxSystem: Invalid captain and crew NFT manager address");
        require(_gameConfig != address(0), "LootboxSystem: Invalid config address");
        
        battleshipToken = IBattleshipToken(_battleshipToken);
        tokenomicsCore = ITokenomicsCore(_tokenomicsCore);
        shipNFTManager = IShipNFTManager(_shipNFTManager);
        actionNFTManager = IActionNFTManager(_actionNFTManager);
        captainAndCrewNFTManager = ICaptainAndCrewNFTManager(_captainAndCrewNFTManager);
        gameConfig = IGameConfig(_gameConfig);
        
        // Initialize random seed
        randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender)));
        
        // Set default SHIP token price (10 SHIP tokens per lootbox)
        lootboxPrices[_battleshipToken] = 10 ether;
        acceptedTokens[_battleshipToken] = true;
        paymentTokens.push(_battleshipToken);
    }
    
    // =============================================================================
    // SECTION 6.1: PAYMENT AND PRICING SYSTEM
    // =============================================================================
    
    /**
     * @dev Function1: Buy lootbox with specified token
     * Supports multiple payment tokens
     * @param paymentToken Token to pay with
     * @param amount Amount of tokens to pay
     * @return lootboxId Generated lootbox ID
     */
    function buyLootbox(address paymentToken, uint256 amount) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (uint256 lootboxId) 
    {
        require(acceptedTokens[paymentToken], "LootboxSystem: Payment token not accepted");
        require(amount >= lootboxPrices[paymentToken], "LootboxSystem: Insufficient payment");
        
        lootboxId = nextLootboxId++;
        
        // Handle payment based on token type
        if (paymentToken == address(0)) {
            // ETH payment
            require(msg.value >= amount, "LootboxSystem: Insufficient ETH");
            require(amount == lootboxPrices[address(0)], "LootboxSystem: Exact ETH amount required");
            
            // Refund excess ETH
            if (msg.value > amount) {
                payable(msg.sender).transfer(msg.value - amount);
            }
        } else {
            // ERC20 payment
            require(msg.value == 0, "LootboxSystem: No ETH should be sent for ERC20 payment");
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        }
        
        // Record lootbox
        lootboxOwners[lootboxId] = msg.sender;
        lootboxPurchaseTime[lootboxId] = block.timestamp;
        
        // Update statistics
        totalLootboxesSold++;
        playerPurchases[msg.sender]++;
        totalRevenue = totalRevenue.add(amount);
        revenueByToken[paymentToken] = revenueByToken[paymentToken].add(amount);
        
        uint256 currentDay = block.timestamp / 1 days;
        dailyRevenue[currentDay] = dailyRevenue[currentDay].add(amount);
        
        // Record revenue with TokenomicsCore
        tokenomicsCore.recordLootboxRevenue(amount);
        
        emit LootboxPurchased(msg.sender, lootboxId, paymentToken, amount);
        
        return lootboxId;
    }
    
    /**
     * @dev Function2: Set lootbox price for a token
     * Only owner can update pricing
     * @param token Token address (address(0) for ETH)
     * @param price Price in token units
     */
    function setLootboxPrice(address token, uint256 price) 
        external 
        onlyOwner 
    {
        require(price >= MIN_LOOTBOX_PRICE && price <= MAX_LOOTBOX_PRICE, 
                "LootboxSystem: Price out of range");
        
        bool wasAccepted = acceptedTokens[token];
        lootboxPrices[token] = price;
        acceptedTokens[token] = true;
        
        // Add to payment tokens array if new
        if (!wasAccepted) {
            paymentTokens.push(token);
        }
        
        emit PaymentTokenUpdated(token, price, true);
    }
    
    /**
     * @dev Function3: Remove accepted payment token
     * @param token Token to remove
     */
    function removePaymentToken(address token) external onlyOwner {
        require(acceptedTokens[token], "LootboxSystem: Token not accepted");
        require(paymentTokens.length > 1, "LootboxSystem: Cannot remove last payment token");
        
        acceptedTokens[token] = false;
        lootboxPrices[token] = 0;
        
        // Remove from array
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == token) {
                paymentTokens[i] = paymentTokens[paymentTokens.length - 1];
                paymentTokens.pop();
                break;
            }
        }
        
        emit PaymentTokenUpdated(token, 0, false);
    }
    
    /**
     * @dev Function4: Get all accepted payment tokens and prices
     * @return tokens Array of token addresses
     * @return prices Array of prices
     */
    function getPaymentTokens() 
        external 
        view 
        returns (address[] memory tokens, uint256[] memory prices) 
    {
        uint256 activeCount = 0;
        
        // Count active tokens
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (acceptedTokens[paymentTokens[i]]) {
                activeCount++;
            }
        }
        
        tokens = new address[](activeCount);
        prices = new uint256[](activeCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (acceptedTokens[paymentTokens[i]]) {
                tokens[index] = paymentTokens[i];
                prices[index] = lootboxPrices[paymentTokens[i]];
                index++;
            }
        }
    }
    
    // =============================================================================
    // SECTION 6.2: LOOTBOX OPENING MECHANICS
    // =============================================================================
    
    /**
     * @dev Function1: Open lootbox and mint NFTs
     * Generates random NFTs based on drop rates
     * @param lootboxId Lootbox ID to open
     * @return nftIds Array of minted NFT IDs
     */
    function openLootbox(uint256 lootboxId) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory nftIds) 
    {
        require(lootboxOwners[lootboxId] == msg.sender, "LootboxSystem: Not lootbox owner");
        require(!lootboxOpened[lootboxId], "LootboxSystem: Lootbox already opened");
        require(lootboxId < nextLootboxId, "LootboxSystem: Invalid lootbox ID");
        
        // Mark as opened
        lootboxOpened[lootboxId] = true;
        totalLootboxesOpened++;
        
        // Generate drops
        (uint256[] memory mintedNFTs, uint8[] memory nftTypes, uint8[] memory rarities) = _generateDrops(lootboxId, msg.sender);
        
        emit LootboxOpened(msg.sender, lootboxId, mintedNFTs, nftTypes, rarities);
        
        return mintedNFTs;
    }
    
    /**
     * @dev Function2: Generate random drops for lootbox
     * Internal function handling all RNG and minting
     */
    function _generateDrops(uint256 lootboxId, address recipient) 
        internal 
        returns (
            uint256[] memory nftIds,
            uint8[] memory nftTypes,
            uint8[] memory rarities
        ) 
    {
        // Calculate maximum possible drops (1 ship + 2 actions + 1 captain + 1 crew)
        uint256[] memory tempIds = new uint256[](5);
        uint8[] memory tempTypes = new uint8[](5);
        uint8[] memory tempRarities = new uint8[](5);
        uint256 dropCount = 0;
        
        // Update random seed
        _updateRandomSeed(lootboxId);
        
        // 1. GUARANTEED SHIP DROP
        (uint256 shipId, IShipNFTManager.ShipType shipType, IShipNFTManager.Rarity shipRarity) = _mintRandomShip(recipient);
        tempIds[dropCount] = shipId;
        tempTypes[dropCount] = 0; // Ship = 0
        tempRarities[dropCount] = uint8(shipRarity);
        dropCount++;
        
        // 2. FIRST ACTION DROP (configurable chance)
        if (_rollDrop(actionDropRate)) {
            (uint256 actionId, IActionNFTManager.Rarity actionRarity) = _mintRandomAction(recipient);
            tempIds[dropCount] = actionId;
            tempTypes[dropCount] = 1; // Action = 1
            tempRarities[dropCount] = uint8(actionRarity);
            dropCount++;
        }
        
        // 3. SECOND ACTION DROP (configurable chance)
        if (_rollDrop(bonusActionDropRate)) {
            (uint256 actionId, IActionNFTManager.Rarity actionRarity) = _mintRandomAction(recipient);
            tempIds[dropCount] = actionId;
            tempTypes[dropCount] = 1; // Action = 1
            tempRarities[dropCount] = uint8(actionRarity);
            dropCount++;
        }
        
        // 4. CAPTAIN DROP (configurable chance)
        if (_rollDrop(captainDropRate)) {
            (uint256 captainId, ICaptainAndCrewNFTManager.Rarity captainRarity) = _mintRandomCaptain(recipient);
            tempIds[dropCount] = captainId;
            tempTypes[dropCount] = 2; // Captain = 2
            tempRarities[dropCount] = uint8(captainRarity);
            dropCount++;
        }
        
        // 5. CREW DROP (configurable chance)
        if (_rollDrop(crewDropRate)) {
            (uint256 crewId, ICaptainAndCrewNFTManager.Rarity crewRarity) = _mintRandomCrew(recipient);
            tempIds[dropCount] = crewId;
            tempTypes[dropCount] = 3; // Crew = 3
            tempRarities[dropCount] = uint8(crewRarity);
            dropCount++;
        }
        
        // Create final arrays with exact size
        nftIds = new uint256[](dropCount);
        nftTypes = new uint8[](dropCount);
        rarities = new uint8[](dropCount);
        
        for (uint256 i = 0; i < dropCount; i++) {
            nftIds[i] = tempIds[i];
            nftTypes[i] = tempTypes[i];
            rarities[i] = tempRarities[i];
        }
    }
    
    /**
     * @dev Function3: Random ship generation and minting
     */
    function _mintRandomShip(address recipient) 
        internal 
        returns (uint256 nftId, IShipNFTManager.ShipType shipType, IShipNFTManager.Rarity rarity) 
    {
        // Random ship type (0-4)
        shipType = IShipNFTManager.ShipType(_random() % 5);
        
        // Random rarity
        rarity = _generateShipRarity();
        
        // Mint ship
        nftId = shipNFTManager.mintShip(recipient, shipType, rarity);
    }
    
    /**
     * @dev Function4: Random action generation and minting (Updated for template system)
     */
    function _mintRandomAction(address recipient) 
        internal 
        returns (uint256 nftId, IActionNFTManager.Rarity rarity) 
    {
        // Random action category (offensive vs defensive)
        IActionNFTManager.ActionCategory category = _random() % 2 == 0 ? 
            IActionNFTManager.ActionCategory.OFFENSIVE : 
            IActionNFTManager.ActionCategory.DEFENSIVE;
        
        // Generate rarity
        rarity = _generateActionRarity();
        
        // Mint action using template system (templates are automatically selected)
        nftId = actionNFTManager.mintAction(recipient, category, rarity);
    }
    
    /**
     * @dev Random captain generation and minting
     */
    function _mintRandomCaptain(address recipient) 
        internal 
        returns (uint256 nftId, ICaptainAndCrewNFTManager.Rarity rarity) 
    {
        // Random captain ability (0-4)
        ICaptainAndCrewNFTManager.CaptainAbility ability = ICaptainAndCrewNFTManager.CaptainAbility(_random() % 5);
        
        // Random rarity (captains tend to be higher rarity)
        rarity = _generateCaptainRarity();
        
        nftId = captainAndCrewNFTManager.mintCaptain(recipient, ability, rarity);
    }
    
    /**
     * @dev Random crew generation and minting
     */
    function _mintRandomCrew(address recipient) 
        internal 
        returns (uint256 nftId, ICaptainAndCrewNFTManager.Rarity rarity) 
    {
        // Random crew type (0-3)
        ICaptainAndCrewNFTManager.CrewType crewType = ICaptainAndCrewNFTManager.CrewType(_random() % 4);
        
        // Random rarity
        rarity = _generateCrewRarity();
        
        nftId = captainAndCrewNFTManager.mintCrew(recipient, crewType, rarity);
    }
    
    /**
     * @dev Generate ship rarity based on configurable drop rates
     */
    function _generateShipRarity() internal returns (IShipNFTManager.Rarity) {
        uint256 roll = _random() % 10000;
        
        if (roll < legendaryRate) {
            return IShipNFTManager.Rarity.LEGENDARY;
        } else if (roll < legendaryRate + epicRate) {
            return IShipNFTManager.Rarity.EPIC;
        } else if (roll < legendaryRate + epicRate + rareRate) {
            return IShipNFTManager.Rarity.RARE;
        } else if (roll < legendaryRate + epicRate + rareRate + uncommonRate) {
            return IShipNFTManager.Rarity.UNCOMMON;
        } else {
            return IShipNFTManager.Rarity.COMMON;
        }
    }
    
    /**
     * @dev Generate action rarity based on configurable drop rates
     */
    function _generateActionRarity() internal returns (IActionNFTManager.Rarity) {
        uint256 roll = _random() % 10000;
        
        if (roll < legendaryRate) {
            return IActionNFTManager.Rarity.LEGENDARY;
        } else if (roll < legendaryRate + epicRate) {
            return IActionNFTManager.Rarity.EPIC;
        } else if (roll < legendaryRate + epicRate + rareRate) {
            return IActionNFTManager.Rarity.RARE;
        } else if (roll < legendaryRate + epicRate + rareRate + uncommonRate) {
            return IActionNFTManager.Rarity.UNCOMMON;
        } else {
            return IActionNFTManager.Rarity.COMMON;
        }
    }
    
    /**
     * @dev Generate crew rarity based on configurable drop rates
     */
    function _generateCrewRarity() internal returns (ICaptainAndCrewNFTManager.Rarity) {
        uint256 roll = _random() % 10000;
        
        if (roll < legendaryRate) {
            return ICaptainAndCrewNFTManager.Rarity.LEGENDARY;
        } else if (roll < legendaryRate + epicRate) {
            return ICaptainAndCrewNFTManager.Rarity.EPIC;
        } else if (roll < legendaryRate + epicRate + rareRate) {
            return ICaptainAndCrewNFTManager.Rarity.RARE;
        } else if (roll < legendaryRate + epicRate + rareRate + uncommonRate) {
            return ICaptainAndCrewNFTManager.Rarity.UNCOMMON;
        } else {
            return ICaptainAndCrewNFTManager.Rarity.COMMON;
        }
    }
    
    /**
     * @dev Generate captain rarity (higher rates for rare captains)
     */
    function _generateCaptainRarity() internal returns (ICaptainAndCrewNFTManager.Rarity) {
        uint256 roll = _random() % 10000;
        
        // Captains have 2x chance for rare+ rarities
        if (roll < legendaryRate * 2) {
            return ICaptainAndCrewNFTManager.Rarity.LEGENDARY;
        } else if (roll < (legendaryRate + epicRate) * 2) {
            return ICaptainAndCrewNFTManager.Rarity.EPIC;
        } else if (roll < (legendaryRate + epicRate + rareRate) * 2) {
            return ICaptainAndCrewNFTManager.Rarity.RARE;
        } else if (roll < (legendaryRate + epicRate + rareRate + uncommonRate)) {
            return ICaptainAndCrewNFTManager.Rarity.UNCOMMON;
        } else {
            return ICaptainAndCrewNFTManager.Rarity.COMMON;
        }
    }
    
    /**
     * @dev Roll for drop chance
     * @param chance Chance out of 10000 (e.g., 6000 = 60%)
     */
    function _rollDrop(uint256 chance) internal returns (bool) {
        return (_random() % 10000) < chance;
    }
    
    /**
     * @dev Generate random number and update seed
     */
    function _random() internal returns (uint256) {
        randomSeed = uint256(keccak256(abi.encodePacked(
            randomSeed,
            block.timestamp,
            block.difficulty,
            msg.sender,
            gasleft()
        )));
        return randomSeed;
    }
    
    /**
     * @dev Update random seed with lootbox-specific data
     */
    function _updateRandomSeed(uint256 lootboxId) internal {
        randomSeed = uint256(keccak256(abi.encodePacked(
            randomSeed,
            lootboxId,
            lootboxPurchaseTime[lootboxId],
            block.timestamp,
            block.difficulty
        )));
    }
    
    // =============================================================================
    // SECTION 6.3: REVENUE DISTRIBUTION
    // =============================================================================
    
    /**
     * @dev Function1: Get revenue split configuration
     * Returns the percentage distribution
     * @return staking Percentage to staking (70%)
     * @return team Percentage to team (20%)
     * @return liquidity Percentage to liquidity (10%)
     */
    function getRevenueSplit() 
        external 
        pure 
        returns (uint256 staking, uint256 team, uint256 liquidity) 
    {
        return (70, 20, 10);
    }
    
    /**
     * @dev Function2: Distribute accumulated revenue
     * Revenue distribution is handled by TokenomicsCore
     * This function provides transparency into revenue flow
     */
    function distributeRevenue() external view {
        // Revenue distribution is automatically handled by TokenomicsCore
        // when recordLootboxRevenue() is called during purchases
        
        // This function exists for interface compatibility and transparency
        // The actual distribution happens in TokenomicsCore.distributeRevenue()
        
        (uint256 staking, uint256 team, uint256 liquidity) = this.getRevenueSplit();
        emit RevenueDistributed(
            totalRevenue.mul(staking).div(100),
            totalRevenue.mul(team).div(100),
            totalRevenue.mul(liquidity).div(100)
        );
    }
    
    /**
     * @dev Function3: Get revenue statistics
     * @return total Total revenue across all tokens
     * @return daily Revenue for current day
     * @return tokenRevenues Revenue by each payment token
     */
    function getRevenueStats() 
        external 
        view 
        returns (
            uint256 total,
            uint256 daily,
            address[] memory tokens,
            uint256[] memory tokenRevenues
        ) 
    {
        total = totalRevenue;
        
        uint256 currentDay = block.timestamp / 1 days;
        daily = dailyRevenue[currentDay];
        
        // Get active payment tokens and their revenues
        (tokens, ) = this.getPaymentTokens();
        tokenRevenues = new uint256[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenRevenues[i] = revenueByToken[tokens[i]];
        }
    }
    
    /**
     * @dev Function4: Emergency revenue withdrawal
     * Only for stuck funds, revenue should flow through TokenomicsCore
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) 
        external 
        onlyOwner 
    {
        require(amount > 0, "LootboxSystem: Invalid amount");
        
        if (token == address(0)) {
            // ETH withdrawal
            require(address(this).balance >= amount, "LootboxSystem: Insufficient ETH balance");
            payable(owner()).transfer(amount);
        } else {
            // ERC20 withdrawal
            IERC20(token).safeTransfer(owner(), amount);
        }
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
        require(newAddress != address(0), "LootboxSystem: Invalid address");
        
        bytes32 nameHash = keccak256(abi.encodePacked(contractName));
        
        if (nameHash == keccak256(abi.encodePacked("BattleshipToken"))) {
            battleshipToken = IBattleshipToken(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("TokenomicsCore"))) {
            tokenomicsCore = ITokenomicsCore(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("ShipNFTManager"))) {
            shipNFTManager = IShipNFTManager(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("ActionNFTManager"))) {
            actionNFTManager = IActionNFTManager(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("CaptainAndCrewNFTManager"))) {
            captainAndCrewNFTManager = ICaptainAndCrewNFTManager(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("GameConfig"))) {
            gameConfig = IGameConfig(newAddress);
        } else {
            revert("LootboxSystem: Unknown contract name");
        }
        
        emit ContractUpdated(contractName, newAddress);
    }
    
    /**
     * @dev Update random seed manually (emergency use)
     * @param newSeed New random seed
     */
    function updateRandomSeed(uint256 newSeed) external onlyOwner {
        randomSeed = newSeed;
        emit RandomSeedUpdated(newSeed);
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
     * @dev Update drop rates for NFT types (ILootboxSystem interface compliance)
     * @param shipRates Array of 4 ship-related rates [guaranteed, bonus1, bonus2, bonus3]
     * @param actionRates Array of 4 action-related rates [base, bonus, special1, special2]  
     * @param captainRate Captain drop rate out of 10000
     * @param crewRate Crew drop rate out of 10000
     */
    function updateDropRates(
        uint256[4] memory shipRates,
        uint256[4] memory actionRates, 
        uint256 captainRate,
        uint256 crewRate
    ) external onlyOwner {
        require(shipRates[0] <= 10000, "LootboxSystem: Invalid ship rate");
        require(actionRates[0] <= 10000, "LootboxSystem: Invalid action rate");
        require(actionRates[1] <= 10000, "LootboxSystem: Invalid bonus action rate");
        require(captainRate <= 10000, "LootboxSystem: Invalid captain rate");
        require(crewRate <= 10000, "LootboxSystem: Invalid crew rate");
        
        // Update configurable drop rates
        shipDropRate = shipRates[0];           // Ships (should stay 10000 for guaranteed)
        actionDropRate = actionRates[0];       // First action chance
        bonusActionDropRate = actionRates[1];  // Second action chance
        captainDropRate = captainRate;         // Captain chance
        crewDropRate = crewRate;               // Crew chance
        
        emit DropRatesUpdated(shipRates, actionRates, captainRate, crewRate);
    }
    
    /**
     * @dev Update rarity distribution rates
     * @param common Common rarity rate out of 10000
     * @param uncommon Uncommon rarity rate out of 10000
     * @param rare Rare rarity rate out of 10000
     * @param epic Epic rarity rate out of 10000
     * @param legendary Legendary rarity rate out of 10000
     */
    function updateRarityRates(
        uint256 common,
        uint256 uncommon,
        uint256 rare,
        uint256 epic,
        uint256 legendary
    ) external onlyOwner {
        require(common + uncommon + rare + epic + legendary == 10000, 
                "LootboxSystem: Rates must sum to 10000");
        require(legendary > 0, "LootboxSystem: Legendary rate must be > 0");
        
        commonRate = common;
        uncommonRate = uncommon;
        rareRate = rare;
        epicRate = epic;
        legendaryRate = legendary;
        
        emit RarityRatesUpdated(common, uncommon, rare, epic, legendary);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS FOR FRONTEND
    // =============================================================================
    
    /**
     * @dev Get lootbox information
     * @param lootboxId Lootbox ID to check
     * @return owner Owner of the lootbox
     * @return purchaseTime When lootbox was purchased
     * @return opened Whether lootbox has been opened
     */
    function getLootboxInfo(uint256 lootboxId) 
        external 
        view 
        returns (address owner, uint256 purchaseTime, bool opened) 
    {
        owner = lootboxOwners[lootboxId];
        purchaseTime = lootboxPurchaseTime[lootboxId];
        opened = lootboxOpened[lootboxId];
    }
    
    /**
     * @dev Get player's lootbox history
     * @param player Player address
     * @return ownedBoxes Array of lootbox IDs owned by player
     * @return openedBoxes Array of lootbox IDs opened by player
     */
    function getPlayerLootboxes(address player) 
        external 
        view 
        returns (uint256[] memory ownedBoxes, uint256[] memory openedBoxes) 
    {
        uint256 totalOwned = 0;
        uint256 totalOpened = 0;
        
        // Count player's lootboxes
        for (uint256 i = 1; i < nextLootboxId; i++) {
            if (lootboxOwners[i] == player) {
                totalOwned++;
                if (lootboxOpened[i]) {
                    totalOpened++;
                }
            }
        }
        
        ownedBoxes = new uint256[](totalOwned);
        openedBoxes = new uint256[](totalOpened);
        
        uint256 ownedIndex = 0;
        uint256 openedIndex = 0;
        
        for (uint256 i = 1; i < nextLootboxId; i++) {
            if (lootboxOwners[i] == player) {
                ownedBoxes[ownedIndex] = i;
                ownedIndex++;
                
                if (lootboxOpened[i]) {
                    openedBoxes[openedIndex] = i;
                    openedIndex++;
                }
            }
        }
    }
    
    /**
     * @dev Get system statistics
     * @return totalSold Total lootboxes sold
     * @return totalOpened Total lootboxes opened
     * @return totalRevenue_ Total revenue generated
     * @return currentPrice Price in SHIP tokens
     */
    function getSystemStats() 
        external 
        view 
        returns (
            uint256 totalSold,
            uint256 totalOpened,
            uint256 totalRevenue_,
            uint256 currentPrice
        ) 
    {
        totalSold = totalLootboxesSold;
        totalOpened = totalLootboxesOpened;
        totalRevenue_ = totalRevenue;
        currentPrice = lootboxPrices[address(battleshipToken)];
    }
    
    /**
     * @dev Preview potential drops (for UI display)
     * Shows drop chances without actually rolling
     * @return shipChance Ship drop chance (always 100%)
     * @return actionChance First action drop chance  
     * @return bonusActionChance Second action drop chance
     * @return captainChance Captain drop chance
     * @return crewChance Crew drop chance
     */
    function getDropChances() 
        external 
        view 
        returns (
            uint256 shipChance,
            uint256 actionChance, 
            uint256 bonusActionChance,
            uint256 captainChance,
            uint256 crewChance
        ) 
    {
        shipChance = shipDropRate; // Configurable ship drop rate
        actionChance = actionDropRate; // Configurable action drop rate
        bonusActionChance = bonusActionDropRate; // Configurable bonus action rate
        captainChance = captainDropRate; // Configurable captain rate
        crewChance = crewDropRate; // Configurable crew rate
    }
    
    /**
     * @dev Get rarity distribution rates
     * @return common Common drop rate
     * @return uncommon Uncommon drop rate  
     * @return rare Rare drop rate
     * @return epic Epic drop rate
     * @return legendary Legendary drop rate
     */
    function getRarityRates() 
        external 
        view 
        returns (
            uint256 common,
            uint256 uncommon,
            uint256 rare,
            uint256 epic,
            uint256 legendary
        ) 
    {
        common = commonRate; // Configurable common rate
        uncommon = uncommonRate; // Configurable uncommon rate
        rare = rareRate; // Configurable rare rate
        epic = epicRate; // Configurable epic rate
        legendary = legendaryRate; // Configurable legendary rate
    }
    
    // =============================================================================
    // RECEIVE FUNCTION FOR ETH PAYMENTS
    // =============================================================================
    
    /**
     * @dev Receive ETH payments
     * Automatically purchases lootbox if exact amount sent
     */
    receive() external payable {
        require(acceptedTokens[address(0)], "LootboxSystem: ETH payments not accepted");
        require(msg.value == lootboxPrices[address(0)], "LootboxSystem: Incorrect ETH amount");
        
        // Automatically purchase lootbox
        this.buyLootbox(address(0), msg.value);
    }
} 