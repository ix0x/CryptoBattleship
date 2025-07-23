# CryptoBattleship Smart Contract Standards

## Overview
This document defines all interfaces, function signatures, and data structures that must be consistent across contracts to ensure proper inter-contract communication.

---

## Core Data Structures

### Game Types
```solidity
enum GameSize { SHRIMP, FISH, SHARK, WHALE }
enum GameStatus { WAITING, ACTIVE, COMPLETED, CANCELLED }
enum CellState { EMPTY, SHIP, HIT, MISS, SUNK, SHIELDED, SCANNING, SPECIAL }
enum ShipType { DESTROYER, SUBMARINE, CRUISER, BATTLESHIP, CARRIER }
enum ShipRotation { HORIZONTAL, VERTICAL, DIAGONAL_RIGHT, DIAGONAL_LEFT }

struct ShipStats {
    uint8 health;
    uint8 speed;
    uint8 shields;
    uint8 size;
}

struct GameInfo {
    address player1;
    address player2;
    GameSize size;
    GameStatus status;
    uint256 entryFee;
    uint256 startTime;
    uint256 lastMoveTime;
    address currentTurn;
    uint8 skipCount;
}
```

### NFT Types
```solidity
enum NFTType { SHIP, ACTION, CAPTAIN, CREW }
enum ActionType { OFFENSIVE, DEFENSIVE }
enum CrewType { GUNNER, ENGINEER, NAVIGATOR, MEDIC }
enum CaptainAbility { SCAN_BOOST, DAMAGE_BOOST, SPEED_BOOST, SHIELDS, REVEAL, DODGE, BERSERKER, DEFENDER }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

struct NFTMetadata {
    NFTType nftType;
    Rarity rarity;
    uint8 usesRemaining; // For actions only
    uint8 stamina; // For crew only
    bool isRental;
}

struct ShipVariant {
    string name;
    bool isActive;
    bool isRetired;
    uint256 seasonId;
    uint8 svgThemeId;
    bool hasAnimations;
    uint256 retiredAt;
    uint8 boosterPoints;
}

struct VariantStatMods {
    int8 healthMod;
    int8 speedMod;
    int8 firepowerMod;
    int8 sizeMod;
}

struct Season {
    uint256 seasonId;
    string name;
    uint256 startTime;
    uint256 endTime;
    uint256[] activeVariants;
    bool isActive;
}
```

### Economy Types
```solidity
struct CreditInfo {
    uint256 amount;
    uint256 earnedEpoch;
    uint256 expiryEpoch;
}

struct EmissionInfo {
    uint256 totalCredits;
    uint256 emissionAmount;
    uint256 liquidAmount;
    uint256 vestedAmount;
}
```

---

## Interface Standards

### IGameConfig - Configuration Management
```solidity
interface IGameConfig {
    // Game Parameters
    function getGridSize() external view returns (uint8);
    function getTurnTimer() external view returns (uint256);
    function getMaxSkipTurns() external view returns (uint8);
    function getShipDestructionChance() external view returns (uint256);
    
    // Ship Configuration
    function getShipStats(ShipType shipType) external view returns (ShipStats memory);
    function getFleetRequirements() external view returns (uint8[5] memory);
    
    // Default Attack Configuration
    function getDefaultAttackDamage() external view returns (uint8);
    function getDefaultAttackPattern() external view returns (uint8[] memory);
    
    // NFT Configuration
    function getActionUsesByRarity(uint8 rarity) external view returns (uint8);
    function getCaptainDefaultAttackToggle(CaptainAbility ability) external view returns (bool);
    function getCrewDefaultAttackToggle(CrewType crewType) external view returns (bool);
    
    // Economy Configuration
    function getCreditsByGameSize(GameSize size) external view returns (uint256 winner, uint256 loser);
    function getGameFeePercentage() external view returns (uint256);
    function getWeeklyEmissionRate() external view returns (uint256);
    
    // Admin Functions
    function updateGameParameter(bytes32 key, uint256 value) external;
    function pause() external;
    function unpause() external;
}
```

### IBattleshipToken - ERC20 Token
```solidity
interface IBattleshipToken {
    // Standard ERC20
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    
    // Minting (restricted to TokenomicsCore)
    function mint(address to, uint256 amount) external;
    function setMinter(address minter) external;
    
    // Emergency functions
    function pause() external;
    function unpause() external;
}
```

### IBattleshipGame - Main Game Logic
```solidity
interface IBattleshipGame {
    // Game Management
    function createGame(GameSize size, uint256 entryFee) external payable returns (uint256 gameId);
    function joinGame(uint256 gameId, uint256[] calldata shipIds, uint256 captainId, uint256[] calldata crewIds) external payable;
    function placeShips(uint256 gameId, uint8[] calldata positions, ShipRotation[] calldata rotations) external;
    
    // Game Actions
    function moveShip(uint256 gameId, uint8 shipIndex, uint8 newPosition) external;
    function rotateShip(uint256 gameId, uint8 shipIndex, ShipRotation rotation) external;
    function defaultAttack(uint256 gameId, uint8 targetCell) external;
    function useActionNFT(uint256 gameId, uint256 actionId, uint8[] calldata targetCells) external;
    
    // Game State
    function getGameInfo(uint256 gameId) external view returns (GameInfo memory);
    function getPlayerGrid(uint256 gameId, address player) external view returns (uint256[2] memory);
    function getVisibleGrid(uint256 gameId, address player) external view returns (uint256[2] memory);
    function getCurrentTurn(uint256 gameId) external view returns (address);
    function getActionsRemaining(uint256 gameId, address player) external view returns (uint8 moves, uint8 attacks, uint8 defenses);
    
    // Events
    event GameCreated(uint256 indexed gameId, address indexed creator, GameSize size, uint256 entryFee);
    event GameJoined(uint256 indexed gameId, address indexed player);
    event GameStarted(uint256 indexed gameId);
    event GameCompleted(uint256 indexed gameId, address indexed winner, address indexed loser);
    event ShipDestroyed(uint256 indexed gameId, address indexed player, uint256 indexed shipId);
}
```

### INFTManager - Unified NFT Management
```solidity
interface INFTManager {
    // NFT Information
    function getNFTMetadata(uint256 tokenId) external view returns (NFTMetadata memory);
    function getShipStats(uint256 tokenId) external view returns (ShipStats memory);
    function getActionPattern(uint256 tokenId) external view returns (uint8[] memory);
    function getCaptainAbility(uint256 tokenId) external view returns (CaptainAbility);
    function getCrewType(uint256 tokenId) external view returns (CrewType);
    
    // NFT Usage
    function useAction(uint256 tokenId) external;
    function useCrewStamina(uint256 tokenId, uint8 amount) external;
    function destroyShip(uint256 tokenId) external;
    function resetWeeklyStamina() external;
    
    // Minting (restricted to authorized contracts)
    function mintShip(address to, ShipType shipType, uint256 variantId, Rarity rarity) external returns (uint256);
    function mintShip(address to, ShipType shipType, Rarity rarity) external returns (uint256); // Backward compatibility
    function mintAction(address to, ActionType actionType, uint8 pattern, Rarity rarity) external returns (uint256);
    function mintCaptain(address to, CaptainAbility ability, Rarity rarity) external returns (uint256);
    function mintCrew(address to, CrewType crewType, Rarity rarity) external returns (uint256);
    
    // Variant System
    function createVariant(string calldata name, uint256 seasonId, uint8 svgThemeId, bool hasAnimations, VariantStatMods calldata statMods) external returns (uint256);
    function retireVariant(uint256 variantId, uint8 boosterPoints) external;
    function startSeason(string calldata name, uint256[] calldata activeVariantIds) external returns (uint256);
    function canMintVariant(uint256 variantId) external view returns (bool);
    function getVariant(uint256 variantId) external view returns (ShipVariant memory);
    function getVariantStatMods(uint256 variantId) external view returns (VariantStatMods memory);
    function getCurrentSeason() external view returns (Season memory);
    function getAvailableVariants() external view returns (uint256[] memory);
    function getShipVariant(uint256 tokenId) external view returns (uint256 variantId, string memory variantName);
    function getFinalShipStats(uint256 tokenId) external view returns (ShipStats memory);
    
    // Rental System
    function createRentalShip(ShipType shipType) external returns (uint256);
    function returnRentalShip(uint256 tokenId) external;
    
    // SVG and Metadata
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function updateSVGVersion(uint8 newVersion) external;
    
    // Events
    event NFTMinted(uint256 indexed tokenId, address indexed to, NFTType nftType, Rarity rarity);
    event ShipMinted(uint256 indexed tokenId, address indexed owner, ShipType shipType, uint256 variantId, Rarity rarity);
    event ActionUsed(uint256 indexed tokenId, uint8 usesRemaining);
    event ShipDestroyed(uint256 indexed tokenId);
    event StaminaReset();
    
    // Variant System Events
    event VariantCreated(uint256 indexed variantId, string name);
    event VariantRetired(uint256 indexed variantId, uint8 boosterPoints);
    event SeasonStarted(uint256 indexed seasonId, string name, uint256[] activeVariants);
    event SeasonEnded(uint256 indexed seasonId);
}
```

### ITokenomicsCore - Credit and Emission Management
```solidity
interface ITokenomicsCore {
    // Credit Management
    function awardCredits(address player, uint256 amount) external;
    function getPlayerCredits(address player) external view returns (uint256);
    function getTotalActiveCredits() external view returns (uint256);
    function getCurrentEpoch() external view returns (uint256);
    
    // Emission Management
    function processWeeklyEmissions() external;
    function getEmissionInfo(uint256 epoch) external view returns (EmissionInfo memory);
    function claimEmissions(address player) external;
    function getClaimableEmissions(address player) external view returns (uint256 liquid, uint256 vested);
    
    // Revenue Tracking
    function recordGameFees(uint256 amount) external;
    function recordLootboxRevenue(uint256 amount) external;
    function getWeeklyRevenue() external view returns (uint256);
    
    // Events
    event CreditsAwarded(address indexed player, uint256 amount, uint256 epoch);
    event EmissionsProcessed(uint256 indexed epoch, uint256 totalEmissions);
    event EmissionsClaimed(address indexed player, uint256 liquid, uint256 vested);
}
```

### ILootboxSystem - Lootbox Management
```solidity
interface ILootboxSystem {
    // Lootbox Purchase
    function buyLootbox(address paymentToken, uint256 amount) external;
    function openLootbox(uint256 lootboxId) external returns (uint256[] memory nftIds);
    
    // Configuration
    function setLootboxPrice(address token, uint256 price) external;
    function updateDropRates(uint8[4] memory shipRates, uint8[4] memory actionRates, uint8 captainRate) external;
    
    // Revenue Distribution
    function distributeRevenue() external;
    function getRevenueSplit() external view returns (uint256 staking, uint256 team, uint256 liquidity);
    
    // Events
    event LootboxPurchased(address indexed buyer, uint256 indexed lootboxId, address paymentToken, uint256 amount);
    event LootboxOpened(address indexed opener, uint256 indexed lootboxId, uint256[] nftIds);
    event RevenueDistributed(uint256 stakingAmount, uint256 teamAmount, uint256 liquidityAmount);
}
```

### IStakingPool - Staking and Rewards
```solidity
interface IStakingPool {
    // Staking Functions
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function getStakedAmount(address user) external view returns (uint256);
    function getTotalStaked() external view returns (uint256);
    
    // Reward Functions
    function claimRewards() external;
    function compoundRewards() external;
    function getClaimableRewards(address user) external view returns (uint256);
    function addRevenueToPool(uint256 amount) external;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsCompounded(address indexed user, uint256 amount);
}
```

### IRentalMarketplace - Ship Rental System
```solidity
interface IRentalMarketplace {
    // Protocol Rentals
    function rentProtocolShip(ShipType shipType) external payable returns (uint256);
    function returnRentalShip(uint256 shipId) external;
    function getProtocolRentalPrice(ShipType shipType) external view returns (uint256);
    
    // P2P Rentals (Future)
    function listShipForRent(uint256 shipId, uint256 pricePerGame) external;
    function rentPlayerShip(uint256 shipId) external payable returns (uint256);
    function unlistShip(uint256 shipId) external;
    
    // Events
    event ShipRented(address indexed renter, uint256 indexed shipId, uint256 price);
    event ShipReturned(address indexed renter, uint256 indexed shipId);
    event ShipListed(address indexed owner, uint256 indexed shipId, uint256 price);
}
```

---

## Cross-Contract Communication Standards

### Function Call Patterns
1. **Authorization**: All contracts check caller permissions before executing sensitive functions
2. **Event Emission**: All state changes emit events for frontend tracking
3. **Error Handling**: All functions revert with descriptive error messages
4. **Gas Optimization**: Batch operations where possible to reduce transaction costs

### Data Validation Standards
1. **Address Validation**: Always check for zero addresses
2. **Range Validation**: Ensure all numeric inputs are within valid ranges
3. **State Validation**: Verify contract state before executing operations
4. **Permission Validation**: Check user permissions and NFT ownership

### Event Standards
All events must include:
- `indexed` parameters for filtering (max 3 per event)
- Timestamp information where relevant
- Clear, descriptive event names
- Comprehensive data for frontend consumption

---

## Security Standards

### Access Control
- Use OpenZeppelin's AccessControl or Ownable patterns
- Implement role-based permissions where appropriate
- Multi-sig support for critical admin functions

### Emergency Controls
- Pause functionality for critical contracts
- Emergency fund recovery mechanisms
- Circuit breakers for unusual activity

### Reentrancy Protection
- Use OpenZeppelin's ReentrancyGuard
- Follow checks-effects-interactions pattern
- External calls only at function end

---

## Frontend Integration Standards

### View Functions
All contracts must provide comprehensive view functions for:
- User dashboard data
- Game state information
- NFT metadata and stats
- Reward and balance information

### Event Indexing
Events must be designed for efficient frontend indexing:
- Use indexed parameters for filtering
- Include all necessary data in event payload
- Emit events for all state changes

### Batch Operations
Provide batch functions where applicable:
- Batch NFT transfers
- Batch reward claims
- Batch game actions (where gas permits)

---

## Version Control
- **Current Version**: 1.0.0
- **Last Updated**: Initial Creation
- **Next Review**: After first contract implementation

This document will be updated as contracts are developed and new requirements are identified. 