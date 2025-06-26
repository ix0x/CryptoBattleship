# CryptoBattleship Contract Functions Reference

This document provides a comprehensive overview of all functions available in the CryptoBattleship smart contract ecosystem. Each contract's functions are organized by category with detailed explanations of parameters, return values, and usage.

---

## Table of Contents

1. [GameConfig.sol](#gameconfig-contract)
2. [BattleshipToken.sol](#battleshiptoken-contract) 
3. [BattleshipGame.sol](#battleshipgame-contract)
4. [NFTManager.sol](#nftmanager-contract)
5. [LootboxSystem.sol](#lootboxsystem-contract)
6. [StakingPool.sol](#stakingpool-contract)
7. [MarketplaceCore.sol](#marketplacecore-contract)
8. [TokenomicsCore.sol](#tokenomicscore-contract)

---

## GameConfig Contract

The GameConfig contract manages all configurable parameters for the game mechanics, NFT systems, and tokenomics.

### Administrative Functions

#### `constructor(address _initialAdmin)`
- **Purpose**: Initializes the contract with an admin address
- **Parameters**: 
  - `_initialAdmin`: Address that will have admin privileges
- **Access**: Deploy-time only
- **Notes**: Sets default game parameters and transfers ownership

#### `pause()` / `unpause()`
- **Purpose**: Emergency pause/unpause all game functions
- **Access**: Owner only
- **Usage**: Emergency situations requiring immediate halt of operations

#### `transferOwnership(address newOwner)`
- **Purpose**: Transfer admin control to new address
- **Parameters**: `newOwner` - New admin address
- **Access**: Owner only

### Game Mechanics Configuration

#### `updateGameMechanics(uint8 _turnTimer, uint8 _skipTurnPenalty, uint8 _defaultAttackDamage)`
- **Purpose**: Update core game timing and combat parameters
- **Parameters**:
  - `_turnTimer`: Turn time limit in minutes (1-30)
  - `_skipTurnPenalty`: Credit penalty for skipping turns (0-100)
  - `_defaultAttackDamage`: Base damage for default attacks (1-5)
- **Access**: Owner only
- **Events**: Emits `GameMechanicsUpdated`

#### `updateTokenomics(uint256 _creditMultiplier, uint8 _destructionChance, bool _stakingEnabled)`
- **Purpose**: Configure economic parameters
- **Parameters**:
  - `_creditMultiplier`: Credit earning multiplier (50-200)
  - `_destructionChance`: Ship destruction probability (0-20)
  - `_stakingEnabled`: Whether staking rewards are active
- **Access**: Owner only

#### `updateNFTParameters(uint8[5] _actionUseCounts, bool[5] _captainToggles, bool[4] _crewToggles)`
- **Purpose**: Configure NFT usage parameters
- **Parameters**:
  - `_actionUseCounts`: Uses per rarity [Common, Uncommon, Rare, Epic, Legendary]
  - `_captainToggles`: Which captain abilities affect default attacks
  - `_crewToggles`: Which crew types affect default attacks
- **Access**: Owner only

### View Functions

#### `getTurnTimer()` → `uint256`
- **Purpose**: Get current turn time limit in seconds
- **Returns**: Turn timer in seconds (300-1800)

#### `getDefaultAttackDamage()` → `uint8`
- **Purpose**: Get base damage for default attacks
- **Returns**: Damage value (1-5)

#### `getActionUseCount(Rarity rarity)` → `uint8`
- **Purpose**: Get number of uses for Action NFTs by rarity
- **Parameters**: `rarity` - NFT rarity level
- **Returns**: Number of uses (1-10)

#### `getCaptainDefaultAttackToggle(CaptainAbility ability)` → `bool`
- **Purpose**: Check if captain ability affects default attacks
- **Parameters**: `ability` - Captain ability type
- **Returns**: True if ability affects default attacks

#### `getCrewDefaultAttackToggle(CrewType crewType)` → `bool`
- **Purpose**: Check if crew type affects default attacks  
- **Parameters**: `crewType` - Crew specialization type
- **Returns**: True if crew type affects default attacks

#### `getCreditEarningRate(GameSize size)` → `uint256`
- **Purpose**: Get credit earning rate for game size
- **Parameters**: `size` - Game size (SMALL, MEDIUM, LARGE)
- **Returns**: Credits earned per game

---

## BattleshipToken Contract

ERC20 token contract with minting controls and integration interfaces.

### Standard ERC20 Functions

#### `transfer(address to, uint256 amount)` → `bool`
- **Purpose**: Transfer tokens to another address
- **Parameters**: 
  - `to`: Recipient address
  - `amount`: Token amount to transfer
- **Returns**: Success boolean
- **Notes**: Respects pause state

#### `approve(address spender, uint256 amount)` → `bool`
- **Purpose**: Approve another address to spend tokens
- **Parameters**:
  - `spender`: Address to approve
  - `amount`: Amount to approve
- **Returns**: Success boolean

#### `transferFrom(address from, address to, uint256 amount)` → `bool`
- **Purpose**: Transfer tokens on behalf of another address
- **Parameters**:
  - `from`: Source address
  - `to`: Destination address  
  - `amount`: Amount to transfer
- **Returns**: Success boolean

### View Functions

#### `balanceOf(address account)` → `uint256`
- **Purpose**: Get token balance of an address
- **Parameters**: `account` - Address to check
- **Returns**: Token balance

#### `allowance(address owner, address spender)` → `uint256`
- **Purpose**: Get approved spending amount
- **Parameters**:
  - `owner`: Token owner
  - `spender`: Approved spender
- **Returns**: Approved amount

#### `totalSupply()` → `uint256`
- **Purpose**: Get total token supply
- **Returns**: Total supply (initially 10M tokens)

### Minting Functions

#### `mint(address to, uint256 amount)`
- **Purpose**: Mint new tokens
- **Parameters**:
  - `to`: Recipient address
  - `amount`: Amount to mint
- **Access**: Only TokenomicsCore contract
- **Events**: Emits `TokensMinted`

#### `setMinter(address newMinter, bool canMint)`
- **Purpose**: Grant/revoke minting privileges
- **Parameters**:
  - `newMinter`: Address to update
  - `canMint`: Whether address can mint
- **Access**: Owner only

### Integration Functions

#### `checkAllowanceForStaking(address owner, address spender)` → `uint256`
- **Purpose**: Check allowance for staking operations
- **Parameters**:
  - `owner`: Token owner
  - `spender`: Staking contract address
- **Returns**: Current allowance

#### `getBalanceInfo(address account)` → `(uint256 balance, bool canTransfer)`
- **Purpose**: Get balance and transfer status
- **Parameters**: `account` - Address to check
- **Returns**: Balance and whether transfers are enabled

---

## BattleshipGame Contract

Core game logic contract handling all gameplay mechanics.

### Game Management Functions

#### `createGame(GameSize size, uint256 entryFee)`
- **Purpose**: Create a new game lobby
- **Parameters**:
  - `size`: Game size (SMALL, MEDIUM, LARGE)
  - `entryFee`: Entry fee in SHIP tokens
- **Returns**: `gameId` - Unique game identifier
- **Events**: Emits `GameCreated`
- **Notes**: Creator must have valid fleet

#### `joinGame(uint256 gameId, uint256[5] shipIds, uint256 captainId, uint256[] crewIds)`
- **Purpose**: Join an existing game
- **Parameters**:
  - `gameId`: Game to join
  - `shipIds`: Array of 5 ship NFT IDs
  - `captainId`: Captain NFT ID (0 if none)
  - `crewIds`: Array of crew NFT IDs
- **Events**: Emits `GameJoined`, potentially `GameStarted`
- **Notes**: Must meet fleet requirements and pay entry fee

#### `placeShips(uint256 gameId, uint8[] positions, ShipRotation[] rotations)`
- **Purpose**: Place ships on game grid
- **Parameters**:
  - `gameId`: Game identifier
  - `positions`: Starting positions for each ship (0-99)
  - `rotations`: Rotation for each ship (HORIZONTAL, VERTICAL, etc.)
- **Events**: Emits `ShipPlaced` for each ship
- **Notes**: Must validate no overlaps, both players must place before game starts

### Combat Functions

#### `defaultAttack(uint256 gameId, uint8 targetCell)`
- **Purpose**: Perform basic attack on target cell
- **Parameters**:
  - `gameId`: Game identifier
  - `targetCell`: Cell index to attack (0-99)
- **Events**: Emits `CellRevealed`, potentially `ShipDestroyed` or `GameCompleted`
- **Notes**: Consumes 1 attack action, applies captain/crew bonuses

#### `useActionNFT(uint256 gameId, uint256 actionId, uint8[] targetCells)`
- **Purpose**: Use an Action NFT for special attack
- **Parameters**:
  - `gameId`: Game identifier
  - `actionId`: Action NFT token ID
  - `targetCells`: Array of target cells
- **Events**: Emits attack events, potentially game completion
- **Notes**: Validates NFT ownership and remaining uses

### Movement Functions

#### `moveShip(uint256 gameId, uint8 shipIndex, uint8 newPosition)`
- **Purpose**: Move a ship to new position
- **Parameters**:
  - `gameId`: Game identifier
  - `shipIndex`: Ship index in fleet (0-4)
  - `newPosition`: New position on grid (0-99)
- **Events**: Emits `ShipPlaced`
- **Notes**: Validates movement range and collision detection

#### `rotateShip(uint256 gameId, uint8 shipIndex, ShipRotation newRotation)`
- **Purpose**: Rotate a ship in place
- **Parameters**:
  - `gameId`: Game identifier
  - `shipIndex`: Ship index in fleet (0-4)
  - `newRotation`: New rotation direction
- **Events**: Emits `ShipPlaced`
- **Notes**: Validates new orientation fits on grid

### Turn Management Functions

#### `skipTurn(uint256 gameId)`
- **Purpose**: Skip current turn (with penalty)
- **Parameters**: `gameId` - Game identifier
- **Events**: Emits `TurnAdvanced`
- **Notes**: Applies credit penalty, advances to opponent's turn

#### `checkTurnTimer(uint256 gameId)` → `(bool hasExpired, uint256 timeRemaining)`
- **Purpose**: Check if current turn has exceeded time limit
- **Parameters**: `gameId` - Game identifier
- **Returns**: Whether turn expired and time remaining
- **Notes**: Used for automatic turn advancement

### View Functions

#### `getCompleteGameState(uint256 gameId)` → `(GameInfo, GameState, uint8, uint8)`
- **Purpose**: Get comprehensive game information
- **Parameters**: `gameId` - Game identifier
- **Returns**: Game info, game state, player1 ships alive, player2 ships alive
- **Notes**: Primary function for frontend game display

#### `getPlayerFleet(uint256 gameId, address player)` → `PlayerFleet`
- **Purpose**: Get player's fleet information
- **Parameters**:
  - `gameId`: Game identifier
  - `player`: Player address
- **Returns**: Complete fleet data including ship positions and health

#### `getValidMovePositions(uint256 gameId, uint8 shipIndex)` → `uint8[]`
- **Purpose**: Calculate valid movement positions for a ship
- **Parameters**:
  - `gameId`: Game identifier
  - `shipIndex`: Ship index (0-4)
- **Returns**: Array of valid position indices

#### `getPlayerVisibility(uint256 gameId, address player)` → `uint256[2]`
- **Purpose**: Get what cells a player has revealed
- **Parameters**:
  - `gameId`: Game identifier
  - `player`: Player address
- **Returns**: Packed visibility grid data

### Administrative Functions

#### `forceEndGame(uint256 gameId)`
- **Purpose**: Emergency function to end stuck games
- **Parameters**: `gameId` - Game to force end
- **Access**: Owner only
- **Events**: Emits `GameCancelled`
- **Notes**: Refunds both players, no winner declared

#### `setContractReferences(address _nftManager, address _tokenomicsCore, address _gameConfig, address _marketplaceCore)`
- **Purpose**: Set references to other contracts
- **Parameters**: Contract addresses for integration
- **Access**: Owner only
- **Notes**: Required for full functionality

---

## NFTManager Contract

Unified NFT contract managing Ships, Actions, Captains, and Crew NFTs.

### Minting Functions

#### `mintShip(address to, ShipType shipType, Rarity rarity, uint8 variant)` → `uint256`
- **Purpose**: Mint a new ship NFT
- **Parameters**:
  - `to`: Recipient address
  - `shipType`: Type of ship (DESTROYER, SUBMARINE, etc.)
  - `rarity`: Rarity level
  - `variant`: Visual variant (0-4)
- **Returns**: Token ID of minted ship
- **Access**: Only LootboxSystem
- **Events**: Emits `NFTMinted`

#### `mintActionNFT(address to, ActionCategory category, Rarity rarity, uint256 variantId)` → `uint256`
- **Purpose**: Mint a new Action NFT
- **Parameters**:
  - `to`: Recipient address
  - `category`: OFFENSIVE or DEFENSIVE
  - `rarity`: Rarity level
  - `variantId`: Seasonal variant ID
- **Returns**: Token ID of minted action
- **Access**: Only LootboxSystem

#### `mintCaptain(address to, CaptainAbility ability, Rarity rarity)` → `uint256`
- **Purpose**: Mint a new Captain NFT
- **Parameters**:
  - `to`: Recipient address
  - `ability`: Captain ability type
  - `rarity`: Rarity level
- **Returns**: Token ID of minted captain
- **Access**: Only LootboxSystem

#### `mintCrew(address to, CrewType crewType, Rarity rarity)` → `uint256`
- **Purpose**: Mint a new Crew NFT
- **Parameters**:
  - `to`: Recipient address
  - `crewType`: Crew specialization
  - `rarity`: Rarity level
- **Returns**: Token ID of minted crew
- **Access**: Only LootboxSystem

### Ship Management Functions

#### `destroyShip(uint256 tokenId)`
- **Purpose**: Mark a ship as destroyed (10% chance after game loss)
- **Parameters**: `tokenId` - Ship token ID
- **Access**: Only BattleshipGame
- **Events**: Emits `ShipDestroyed`
- **Notes**: Ship becomes unusable but remains owned

#### `repairShip(uint256 tokenId)`
- **Purpose**: Repair a destroyed ship (admin emergency function)
- **Parameters**: `tokenId` - Ship token ID
- **Access**: Owner only
- **Events**: Emits `ShipRepaired`

#### `canUseShip(uint256 tokenId)` → `bool`
- **Purpose**: Check if ship can be used in games
- **Parameters**: `tokenId` - Ship token ID
- **Returns**: True if ship is usable (not destroyed)

### Action NFT Management

#### `useActionNFT(uint256 tokenId)`
- **Purpose**: Consume one use of an Action NFT
- **Parameters**: `tokenId` - Action NFT token ID
- **Access**: Only BattleshipGame
- **Notes**: Decrements remaining uses, burns if reaches 0

#### `getActionUsesRemaining(uint256 tokenId)` → `uint256`
- **Purpose**: Get remaining uses for Action NFT
- **Parameters**: `tokenId` - Action NFT token ID
- **Returns**: Number of uses remaining

### Crew Management Functions

#### `useCrewStamina(uint256 tokenId, uint8 amount)`
- **Purpose**: Consume crew stamina (used when games start)
- **Parameters**:
  - `tokenId`: Crew NFT token ID
  - `amount`: Stamina to consume
- **Access**: Only BattleshipGame
- **Notes**: Crew regenerates stamina over time

#### `getCrewStamina(uint256 tokenId)` → `uint8`
- **Purpose**: Get current crew stamina
- **Parameters**: `tokenId` - Crew NFT token ID
- **Returns**: Current stamina (0-100)

### Stats and Metadata Functions

#### `getShipStats(uint256 tokenId)` → `ShipStats`
- **Purpose**: Get ship statistics
- **Parameters**: `tokenId` - Ship token ID
- **Returns**: Struct with size, health, speed, armor
- **Notes**: Stats vary by type and rarity

#### `getActionStats(uint256 tokenId)` → `ActionStats`
- **Purpose**: Get action statistics
- **Parameters**: `tokenId` - Action token ID
- **Returns**: Struct with damage, range, uses, target pattern

#### `getCaptainAbility(uint256 tokenId)` → `CaptainAbility`
- **Purpose**: Get captain's ability type
- **Parameters**: `tokenId` - Captain token ID
- **Returns**: Ability enum value

#### `getCrewType(uint256 tokenId)` → `CrewType`
- **Purpose**: Get crew specialization
- **Parameters**: `tokenId` - Crew token ID
- **Returns**: Crew type enum value

### Query Functions

#### `getTokensByTypeAndOwner(address owner, TokenType tokenType)` → `uint256[]`
- **Purpose**: Get all NFTs of specific type owned by address
- **Parameters**:
  - `owner`: Owner address
  - `tokenType`: Type of NFT to query
- **Returns**: Array of token IDs

#### `getUsableShips(address player)` → `uint256[]`
- **Purpose**: Get all usable ships for a player
- **Parameters**: `player` - Player address
- **Returns**: Array of usable ship token IDs
- **Notes**: Excludes destroyed ships

#### `tokenURI(uint256 tokenId)` → `string`
- **Purpose**: Get metadata URI for NFT
- **Parameters**: `tokenId` - Token ID
- **Returns**: JSON metadata URI
- **Notes**: Dynamically generated SVG and metadata

### Action Template Management

#### `addActionTemplate(string name, string description, uint8[] targetCells, uint8 damage, uint8 range, uint8 uses, ActionCategory category, Rarity minRarity, bool isSeasonalOnly, uint256 seasonId)` → `uint8`
- **Purpose**: Add new action template
- **Parameters**: Complete template configuration
- **Returns**: Template ID
- **Access**: Owner only
- **Events**: Emits `ActionTemplateAdded`

#### `batchCreateActionTemplates(ActionTemplateCreationData[] templateData)`
- **Purpose**: Create multiple templates efficiently
- **Parameters**: Array of template data
- **Access**: Owner only
- **Notes**: Gas-efficient batch operation

#### `setTemplateActive(uint8 templateId, bool isActive)`
- **Purpose**: Enable/disable action template
- **Parameters**:
  - `templateId`: Template to modify
  - `isActive`: Whether template is available
- **Access**: Owner only

### Seasonal Variant Management

#### `createActionVariant(string name, uint256 seasonId, string visualTheme)` → `uint256`
- **Purpose**: Create new seasonal variant
- **Parameters**:
  - `name`: Variant name
  - `seasonId`: Season identifier
  - `visualTheme`: Visual theme string
- **Returns**: Variant ID
- **Access**: Owner only

#### `activateActionVariant(uint256 variantId)`
- **Purpose**: Activate variant for minting
- **Parameters**: `variantId` - Variant to activate
- **Access**: Owner only
- **Notes**: Only one variant can be active at a time

#### `retireActionVariant(uint256 variantId)`
- **Purpose**: Permanently retire a variant
- **Parameters**: `variantId` - Variant to retire
- **Access**: Owner only
- **Notes**: Retired variants cannot be reactivated

### Utility Functions

#### `burn(uint256 tokenId)`
- **Purpose**: Burn an NFT (used for protocol rentals)
- **Parameters**: `tokenId` - Token to burn
- **Access**: Token owner or approved
- **Events**: Emits `NFTBurned`
- **Notes**: Cleans up all associated data

---

## LootboxSystem Contract

Handles lootbox purchases and NFT generation with configurable drop rates.

### Purchase Functions

#### `buyLootbox(address paymentToken, uint256 quantity)` → `uint256[]`
- **Purpose**: Purchase lootboxes with various payment tokens
- **Parameters**:
  - `paymentToken`: Token address for payment (SHIP, USDC, etc.)
  - `quantity`: Number of lootboxes to buy
- **Returns**: Array of ship token IDs (guaranteed drops)
- **Events**: Emits `LootboxPurchased`, `LootboxOpened`
- **Notes**: Each lootbox guarantees 1 ship, chance for actions/captains/crew

#### `buyLootboxWithETH(uint256 quantity)` → `uint256[]`
- **Purpose**: Purchase lootboxes with ETH
- **Parameters**: `quantity` - Number of lootboxes
- **Returns**: Array of ship token IDs
- **Notes**: Uses price oracle for ETH conversion

### Drop Rate Configuration

#### `updateDropRates(uint8 _shipCommonRate, uint8 _shipUncommonRate, uint8 _shipRareRate, uint8 _shipEpicRate, uint8 _shipLegendaryRate)`
- **Purpose**: Update ship rarity drop rates
- **Parameters**: Drop rates for each rarity (must sum to 100)
- **Access**: Owner only
- **Events**: Emits `DropRatesUpdated`

#### `updateRarityRates(uint8 _actionDropRate, uint8 _captainDropRate, uint8 _crewDropRate)`
- **Purpose**: Update secondary drop rates
- **Parameters**: Drop rates for non-ship NFTs
- **Access**: Owner only
- **Notes**: Rates are independent probabilities

### Payment Configuration

#### `updatePaymentToken(address token, uint256 price, bool accepted)`
- **Purpose**: Configure accepted payment tokens and prices
- **Parameters**:
  - `token`: Token contract address
  - `price`: Price per lootbox in token units
  - `accepted`: Whether token is accepted
- **Access**: Owner only

#### `updatePricing(uint256 _shipPrice, uint256 _usdcPrice, uint256 _ethPrice)`
- **Purpose**: Update lootbox prices
- **Parameters**: Prices in SHIP, USDC, and ETH
- **Access**: Owner only

### Revenue Distribution

#### `distributeRevenue()`
- **Purpose**: Distribute accumulated revenue to destinations
- **Access**: Anyone can call
- **Notes**: 70% to staking, 20% to team, 10% to liquidity
- **Events**: Emits `RevenueDistributed`

### View Functions

#### `getLootboxPrice(address paymentToken)` → `uint256`
- **Purpose**: Get current lootbox price in specific token
- **Parameters**: `paymentToken` - Token address
- **Returns**: Price per lootbox

#### `getDropRates()` → `(uint8[5] shipRates, uint8 actionRate, uint8 captainRate, uint8 crewRate)`
- **Purpose**: Get current drop rate configuration
- **Returns**: All drop rates

#### `estimateLootboxContents(uint256 quantity)` → `(uint256 expectedShips, uint256 expectedActions, uint256 expectedCaptains, uint256 expectedCrew)`
- **Purpose**: Estimate expected contents from multiple lootboxes
- **Parameters**: `quantity` - Number of lootboxes
- **Returns**: Expected counts of each NFT type

---

## StakingPool Contract

Token staking with flexible rewards and auto-compounding options.

### Staking Functions

#### `stake(uint256 amount)`
- **Purpose**: Stake tokens with default parameters (1 week lock, no auto-compound)
- **Parameters**: `amount` - Amount of SHIP tokens to stake
- **Events**: Emits `Staked`
- **Notes**: Simple interface for basic staking

#### `stakeWithOptions(uint256 amount, uint256 lockWeeks, bool autoCompound)`
- **Purpose**: Stake tokens with custom parameters
- **Parameters**:
  - `amount`: Amount to stake
  - `lockWeeks`: Lock period in weeks (0-52)
  - `autoCompound`: Whether to automatically compound rewards
- **Events**: Emits `Staked`
- **Notes**: Longer locks and auto-compound provide bonus multipliers

#### `unstake(uint256 amount)`
- **Purpose**: Unstake tokens (simple interface)
- **Parameters**: `amount` - Amount to unstake
- **Events**: Emits `Unstaked`
- **Notes**: Unstakes from oldest available stake

#### `unstakeSpecific(uint256 stakeIndex)`
- **Purpose**: Unstake a specific stake
- **Parameters**: `stakeIndex` - Index of stake to unstake
- **Events**: Emits `Unstaked`
- **Notes**: Must respect lock periods

### Reward Functions

#### `claimRewards()`
- **Purpose**: Claim accumulated staking rewards
- **Returns**: `rewardAmount` - Amount of rewards claimed
- **Events**: Emits `RewardsClaimed`
- **Notes**: Claims from all eligible stakes

#### `claimSpecificRewards(uint256 stakeIndex)`
- **Purpose**: Claim rewards from specific stake
- **Parameters**: `stakeIndex` - Stake to claim from
- **Returns**: Reward amount
- **Events**: Emits `RewardsClaimed`

#### `compoundRewards()`
- **Purpose**: Manually compound rewards into new stake
- **Events**: Emits `RewardsCompounded`
- **Notes**: Creates new stake with claimed rewards

### Configuration Functions

#### `updateRewardRate(uint256 newRate)`
- **Purpose**: Update base reward rate
- **Parameters**: `newRate` - New rate (basis points, 500 = 5%)
- **Access**: Owner only
- **Events**: Emits `RewardRateUpdated`

#### `addRewardFunds(uint256 amount)`
- **Purpose**: Add tokens to reward pool
- **Parameters**: `amount` - Amount to add
- **Access**: Owner only
- **Notes**: Extends reward distribution period

#### `setLockMultipliers(uint256[5] multipliers)`
- **Purpose**: Set reward multipliers for lock periods
- **Parameters**: `multipliers` - Multipliers for 1, 4, 12, 26, 52 week locks
- **Access**: Owner only

### View Functions

#### `getStakeInfo(address user, uint256 stakeIndex)` → `StakeInfo`
- **Purpose**: Get detailed information about a specific stake
- **Parameters**:
  - `user`: Staker address
  - `stakeIndex`: Index of stake
- **Returns**: Complete stake information

#### `getUserStakes(address user)` → `StakeInfo[]`
- **Purpose**: Get all stakes for a user
- **Parameters**: `user` - User address
- **Returns**: Array of stake information

#### `calculateRewards(address user, uint256 stakeIndex)` → `uint256`
- **Purpose**: Calculate pending rewards for a stake
- **Parameters**:
  - `user`: Staker address
  - `stakeIndex`: Stake index
- **Returns**: Pending reward amount

#### `getTotalStaked()` → `uint256`
- **Purpose**: Get total amount staked in pool
- **Returns**: Total staked tokens

#### `getPoolInfo()` → `(uint256 totalStaked, uint256 rewardRate, uint256 rewardPool)`
- **Purpose**: Get overall pool statistics
- **Returns**: Pool totals and rates

---

## MarketplaceCore Contract

NFT trading platform with rental system and auction capabilities.

### NFT Trading Functions

#### `listNFT(uint256 tokenId, uint256 price, uint256 duration)`
- **Purpose**: List NFT for sale
- **Parameters**:
  - `tokenId`: NFT token ID
  - `price`: Sale price in SHIP tokens
  - `duration`: Listing duration in seconds
- **Events**: Emits `NFTListed`
- **Notes**: NFT is escrowed until sale or expiry

#### `buyNFT(uint256 listingId)`
- **Purpose**: Purchase a listed NFT
- **Parameters**: `listingId` - Listing identifier
- **Events**: Emits `NFTSold`
- **Notes**: Handles payment and fee distribution

#### `cancelListing(uint256 listingId)`
- **Purpose**: Cancel an active NFT listing
- **Parameters**: `listingId` - Listing to cancel
- **Events**: Emits `ListingCancelled`
- **Notes**: Returns NFT to owner

### Auction Functions

#### `createAuction(uint256 tokenId, uint256 startingBid, uint256 duration)`
- **Purpose**: Create NFT auction
- **Parameters**:
  - `tokenId`: NFT token ID
  - `startingBid`: Minimum bid amount
  - `duration`: Auction duration in seconds
- **Events**: Emits `AuctionCreated`

#### `placeBid(uint256 auctionId, uint256 bidAmount)`
- **Purpose**: Place bid on auction
- **Parameters**:
  - `auctionId`: Auction identifier
  - `bidAmount`: Bid amount in SHIP tokens
- **Events**: Emits `BidPlaced`
- **Notes**: Refunds previous highest bidder

#### `finalizeAuction(uint256 auctionId)`
- **Purpose**: Complete auction and distribute NFT/payment
- **Parameters**: `auctionId` - Auction to finalize
- **Events**: Emits `AuctionFinalized`
- **Notes**: Can be called by anyone after auction ends

### Rental System Functions

#### `rentFullFleet(uint256 maxHours)` → `uint256[5]`
- **Purpose**: Rent complete fleet for new players
- **Parameters**: `maxHours` - Maximum rental duration (1-168)
- **Returns**: Array of 5 ship token IDs
- **Events**: Emits `FleetRented`
- **Notes**: Mint-and-burn system, includes 10% fleet discount

#### `rentProtocolShip(ShipType shipType, uint256 maxHours)` → `uint256`
- **Purpose**: Rent single ship from protocol
- **Parameters**:
  - `shipType`: Type of ship to rent
  - `maxHours`: Maximum rental duration
- **Returns**: Ship token ID
- **Events**: Emits `ShipRented`

#### `listShipForRent(uint256 shipId, uint256 pricePerGame, uint256 maxGames)` → `uint256`
- **Purpose**: List player ship for P2P rental
- **Parameters**:
  - `shipId`: Ship token ID to rent
  - `pricePerGame`: Price per game in SHIP tokens
  - `maxGames`: Maximum games allowed
- **Returns**: Listing ID
- **Events**: Emits `ShipListedForRent`

#### `rentPlayerShip(uint256 listingId, uint256 gameCount, uint256 maxHours)` → `uint256`
- **Purpose**: Rent ship from another player
- **Parameters**:
  - `listingId`: P2P rental listing ID
  - `gameCount`: Number of games to rent for
  - `maxHours`: Maximum rental duration
- **Returns**: Ship token ID
- **Events**: Emits `ShipRented`

### Rental Cleanup Functions

#### `cleanupExpiredRentals(uint256[] expiredShipIds)` → `uint256`
- **Purpose**: Clean up expired rentals and earn rewards
- **Parameters**: `expiredShipIds` - Array of expired ship IDs (max 20)
- **Returns**: Total reward earned
- **Events**: Emits `RentalCleaned`
- **Notes**: Regular cleaners get 10% of staking fees, admin cleaners get 0%

#### `getExpiredRentalIds()` → `uint256[]`
- **Purpose**: Get list of expired rental ship IDs
- **Returns**: Array of ship IDs ready for cleanup
- **Notes**: Useful for cleanup bots

#### `isRentalExpired(uint256 shipId)` → `(bool expired, string reason)`
- **Purpose**: Check if specific rental has expired
- **Parameters**: `shipId` - Ship token ID to check
- **Returns**: Whether expired and reason
- **Notes**: Checks both time and game count expiry

### Administrative Functions

#### `setProtocolRentalConfig(ShipType shipType, uint256 price, bool isActive)`
- **Purpose**: Configure protocol rental pricing
- **Parameters**:
  - `shipType`: Ship type to configure
  - `price`: Price per game in SHIP tokens
  - `isActive`: Whether available for rental
- **Access**: Owner only

#### `setAdminCleaner(address cleaner, bool isAdmin)`
- **Purpose**: Set admin cleaner status (no fee diversion)
- **Parameters**:
  - `cleaner`: Address to update
  - `isAdmin`: Whether address is admin cleaner
- **Access**: Owner only

#### `setFleetDiscount(uint256 discountPercent)`
- **Purpose**: Set fleet rental discount percentage
- **Parameters**: `discountPercent` - Discount percentage (0-50)
- **Access**: Owner only

#### `emergencyReturnRental(uint256 shipId)`
- **Purpose**: Force return rental (emergency function)
- **Parameters**: `shipId` - Ship to return
- **Access**: Owner only

### View Functions

#### `getProtocolRentalPrice(ShipType shipType)` → `uint256`
- **Purpose**: Get protocol rental price for ship type
- **Parameters**: `shipType` - Ship type
- **Returns**: Price per game

#### `isActiveRental(uint256 shipId)` → `bool`
- **Purpose**: Check if ship is currently rented
- **Parameters**: `shipId` - Ship token ID
- **Returns**: True if currently rented

#### `getUserActiveRentals(address user)` → `uint256[]`
- **Purpose**: Get user's active rental ships
- **Parameters**: `user` - User address
- **Returns**: Array of rented ship IDs

#### `getActiveListing(uint256 listingId)` → `Listing`
- **Purpose**: Get details of active listing
- **Parameters**: `listingId` - Listing identifier
- **Returns**: Complete listing information

#### `getActiveAuction(uint256 auctionId)` → `Auction`
- **Purpose**: Get details of active auction
- **Parameters**: `auctionId` - Auction identifier
- **Returns**: Complete auction information

---

## TokenomicsCore Contract

Central economic management for credit earning, token distribution, and treasury operations.

### Credit Management Functions

#### `awardCredits(address player, uint256 amount)`
- **Purpose**: Award credits to player for game completion
- **Parameters**:
  - `player`: Player address
  - `amount`: Credits to award
- **Access**: Only BattleshipGame
- **Events**: Emits `CreditsAwarded`

#### `spendCredits(address player, uint256 amount)`
- **Purpose**: Spend player credits
- **Parameters**:
  - `player`: Player address
  - `amount`: Credits to spend
- **Access**: Only authorized contracts
- **Events**: Emits `CreditsSpent`

#### `getCreditBalance(address player)` → `uint256`
- **Purpose**: Get player's credit balance
- **Parameters**: `player` - Player address
- **Returns**: Current credit balance

### Token Distribution Functions

#### `distributePrizePool(address winner, address loser, uint256 totalPrize)`
- **Purpose**: Distribute game prize pool
- **Parameters**:
  - `winner`: Winning player address
  - `loser`: Losing player address
  - `totalPrize`: Total prize amount
- **Access**: Only BattleshipGame
- **Events**: Emits `PrizeDistributed`
- **Notes**: Winner gets 85%, protocol gets 15%

#### `processLootboxRevenue(uint256 amount)`
- **Purpose**: Process revenue from lootbox sales
- **Parameters**: `amount` - Revenue amount to distribute
- **Access**: Only LootboxSystem
- **Notes**: 70% staking, 20% team, 10% liquidity

#### `processMarketplaceFees(uint256 amount)`
- **Purpose**: Process marketplace transaction fees
- **Parameters**: `amount` - Fee amount to distribute
- **Access**: Only MarketplaceCore
- **Notes**: 60% staking, 40% team treasury

### Treasury Functions

#### `withdrawTeamFunds(uint256 amount)`
- **Purpose**: Withdraw funds from team treasury
- **Parameters**: `amount` - Amount to withdraw
- **Access**: Only team wallet
- **Events**: Emits `TeamFundsWithdrawn`

#### `addLiquidityFunds(uint256 amount)`
- **Purpose**: Add funds to liquidity pool
- **Parameters**: `amount` - Amount to add
- **Access**: Owner only
- **Events**: Emits `LiquidityAdded`

### Configuration Functions

#### `updateDistributionRates(uint256 stakingRate, uint256 teamRate, uint256 liquidityRate)`
- **Purpose**: Update revenue distribution percentages
- **Parameters**: Distribution rates (must sum to 100%)
- **Access**: Owner only
- **Events**: Emits `DistributionRatesUpdated`

#### `setTeamWallet(address newTeamWallet)`
- **Purpose**: Update team treasury wallet
- **Parameters**: `newTeamWallet` - New team wallet address
- **Access**: Owner only

#### `updateCreditExchangeRate(uint256 newRate)`
- **Purpose**: Update credits to SHIP token exchange rate
- **Parameters**: `newRate` - New exchange rate
- **Access**: Owner only

### View Functions

#### `getTreasuryBalances()` → `(uint256 team, uint256 staking, uint256 liquidity)`
- **Purpose**: Get current treasury balances
- **Returns**: Balances in each treasury category

#### `getDistributionRates()` → `(uint256 staking, uint256 team, uint256 liquidity)`
- **Purpose**: Get current distribution rate configuration
- **Returns**: Distribution percentages

#### `calculateGameRewards(GameSize size, bool isWinner)` → `uint256`
- **Purpose**: Calculate credit rewards for game completion
- **Parameters**:
  - `size`: Game size
  - `isWinner`: Whether player won
- **Returns**: Credit amount to award

#### `estimateTokenValue(uint256 creditAmount)` → `uint256`
- **Purpose**: Estimate SHIP token value of credits
- **Parameters**: `creditAmount` - Credits to convert
- **Returns**: Estimated SHIP token value

---

## Integration Notes

### Cross-Contract Communication

The contracts are designed to work together seamlessly:

1. **BattleshipGame** calls **NFTManager** for NFT validation and usage
2. **LootboxSystem** calls **NFTManager** for minting new NFTs
3. **BattleshipGame** calls **TokenomicsCore** for credit awards and prize distribution
4. **MarketplaceCore** calls **NFTManager** for NFT transfers and burns
5. **StakingPool** receives funds from **TokenomicsCore** revenue distribution
6. **All contracts** reference **GameConfig** for parameter values

### Event Monitoring

Frontend applications should monitor these key events:
- `GameCreated`, `GameJoined`, `GameStarted`, `GameCompleted` from BattleshipGame
- `NFTMinted`, `ShipDestroyed` from NFTManager  
- `LootboxPurchased`, `LootboxOpened` from LootboxSystem
- `Staked`, `Unstaked`, `RewardsClaimed` from StakingPool
- `NFTListed`, `NFTSold`, `ShipRented` from MarketplaceCore

### Gas Optimization

Several functions are optimized for gas efficiency:
- Batch operations in NFTManager and LootboxSystem
- Packed storage for game grids and ship positions
- Efficient cleanup functions in MarketplaceCore
- Minimal storage reads in view functions

This completes the comprehensive function reference for the CryptoBattleship smart contract ecosystem. Each function is production-ready with proper access controls, event emissions, and error handling. 