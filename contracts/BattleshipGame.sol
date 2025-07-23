// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// =============================================================================
// INTERFACES FOR CROSS-CONTRACT INTEGRATION
// =============================================================================

interface IGameConfig {
    enum GameSize { SHRIMP, FISH, SHARK, WHALE }
    enum ShipType { DESTROYER, SUBMARINE, CRUISER, BATTLESHIP, CARRIER }
    enum CaptainAbility { DAMAGE_BOOST, SPEED_BOOST, DEFENSE_BOOST, VISION_BOOST, LUCK_BOOST }
    enum CrewType { GUNNER, ENGINEER, NAVIGATOR, MEDIC }
    
    struct ShipStats {
        uint8 health;
        uint8 speed;
        uint8 shields;
        uint8 size;
    }
    
    function getGridSize() external view returns (uint8);
    function getTurnTimer() external view returns (uint256);
    function getMaxSkipTurns() external view returns (uint8);
    function getShipDestructionChance() external view returns (uint256);
    function getShipStats(ShipType shipType) external view returns (ShipStats memory);
    function getDefaultAttackDamage() external view returns (uint8);
    function getCaptainDefaultAttackToggle(CaptainAbility ability) external view returns (bool);
    function getCrewDefaultAttackToggle(CrewType crewType) external view returns (bool);
    function getCreditsByGameSize(GameSize size) external view returns (uint256 winner, uint256 loser);
    function getGameFeePercentage() external view returns (uint256);
}

// Interfaces for split NFT contracts
interface IShipNFTManager {
    enum ShipType { DESTROYER, SUBMARINE, CRUISER, BATTLESHIP, CARRIER }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    struct ShipStats {
        uint8 health;
        uint8 speed;
        uint8 shields;
        uint8 size;
        uint8 firepower;
        uint8 range;
        uint8 armor;
        uint8 stealth;
    }
    
    function ownerOf(uint256 tokenId) external view returns (address);
    function getShipInfo(uint256 tokenId) external view returns (
        ShipType shipType,
        Rarity rarity,
        ShipStats memory stats,
        uint256 variantId,
        bool isDestroyed,
        uint256 crewCapacity
    );
    function canUseShip(uint256 tokenId) external view returns (bool canUse);
    function destroyShip(uint256 tokenId) external;
    function useRentalGame(uint256 tokenId) external;
}

interface IActionNFTManager {
    enum ActionCategory { OFFENSIVE, DEFENSIVE }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    struct ActionPattern {
        uint8[] targetCells;
        uint8 damage;
        uint8 range;
        ActionCategory category;
    }
    
    function ownerOf(uint256 tokenId) external view returns (address);
    function getActionInfo(uint256 tokenId) external view returns (
        ActionPattern memory pattern,
        ActionCategory category,
        uint256 usesRemaining
    );
    function useAction(uint256 tokenId, address user) external;
}

interface ICaptainAndCrewNFTManager {
    enum CaptainAbility { DAMAGE_BOOST, SPEED_BOOST, DEFENSE_BOOST, VISION_BOOST, LUCK_BOOST }
    enum CrewType { GUNNER, ENGINEER, NAVIGATOR, MEDIC }
    enum NFTType { CAPTAIN, CREW }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    struct CaptainInfo {
        string name;
        CaptainAbility ability;
        uint8 abilityPower;
        uint256 experience;
        uint8 leadership;
        uint8 tactics;
        uint8 morale;
    }
    
    struct CrewInfo {
        string name;
        CrewType crewType;
        uint8 skillLevel;
        uint8 stamina;
        uint8 maxStamina;
        uint256 experience;
        uint8 efficiency;
        uint8 loyalty;
        uint256 lastUsed;
        uint256 variantId;
    }
    
    function ownerOf(uint256 tokenId) external view returns (address);
    function getCaptainInfo(uint256 tokenId) external view returns (CaptainInfo memory info);
    function getCrewInfo(uint256 tokenId) external view returns (CrewInfo memory info);
    function canUseCrew(uint256 tokenId) external view returns (bool canUse, uint8 currentStamina);
    function useCrewStamina(uint256 tokenId, address user) external;
}

interface ITokenomicsCore {
    enum GameSize { SHRIMP, FISH, SHARK, WHALE }
    
    function awardCredits(address player, uint256 amount) external;
    function recordGameRevenue(uint256 amount) external;
}

/**
 * @title BattleshipGame
 * @dev Main game logic and state management for CryptoBattleship
 * @notice Handles grid storage, turn management, fleet selection, combat resolution, 
 *         and game outcomes with NFT integration
 */
contract BattleshipGame is ReentrancyGuard, Pausable, Ownable {
    
    // =============================================================================
    // CONTRACT ADDRESSES
    // =============================================================================
    
    IGameConfig public gameConfig;
    IShipNFTManager public shipNFTManager;
    IActionNFTManager public actionNFTManager;
    ICaptainAndCrewNFTManager public captainAndCrewNFTManager;
    ITokenomicsCore public tokenomicsCore;
    
    // Legacy storage for compatibility
    address public gameConfigContract;
    address public shipNFTManagerContract;
    address public actionNFTManagerContract;
    address public captainAndCrewNFTManagerContract;
    address public tokenomicsCoreContract;
    
    // =============================================================================
    // ANTE SYSTEM CONFIGURATION
    // =============================================================================
    
    // Current ante configuration
    struct AnteConfig {
        bool useFixedAnte;           // True = fixed ante, False = flexible matching system
        uint256 fixedAnteAmount;     // Fixed ante amount in wei (when useFixedAnte = true)
        mapping(GameSize => uint256) gameTypeAntes;  // Future: different antes per game size
    }
    
    AnteConfig public anteConfig;
    
    // Events for ante system
    event AnteConfigUpdated(bool useFixedAnte, uint256 fixedAmount);
    event GameTypeAnteUpdated(GameSize gameSize, uint256 anteAmount);
    
    // =============================================================================
    // ENUMS AND STRUCTS (from STANDARDS.md)
    // =============================================================================
    
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

    // =============================================================================
    // SECTION 3.1: GAME STATE STRUCTURES AND STORAGE
    // =============================================================================

    // Game counter for unique game IDs
    uint256 public gameCounter;
    
    // Mapping from game ID to game info
    mapping(uint256 => GameInfo) public games;

    /**
     * @dev Function1: Grid state packed storage (2 uint256 per player)
     * Each cell uses 3 bits to store state (8 possible states)
     * 10x10 grid = 100 cells × 3 bits = 300 bits total
     * 2 uint256 (512 bits) can store the entire grid efficiently
     * 
     * Grid layout: (0,0) is top-left, (9,9) is bottom-right
     * Cell index = row * 10 + col
     */
    struct GridState {
        uint256 data1; // Stores cells 0-84 (85 cells × 3 bits = 255 bits)
        uint256 data2; // Stores cells 85-99 (15 cells × 3 bits = 45 bits)
    }

    // Player grids: gameId => player => GridState
    mapping(uint256 => mapping(address => GridState)) public playerGrids;

    // Visibility grids (what each player can see of opponent's grid)
    mapping(uint256 => mapping(address => GridState)) public visibilityGrids;

    /**
     * @dev Function2: Game metadata struct (players, status, turn, timer)
     * Additional game state beyond the basic GameInfo
     */
    struct GameState {
        // Turn management
        uint8 player1ActionsUsed; // Actions used this turn [moves, attacks, defenses]
        uint8 player2ActionsUsed; // Packed as: moves(bits 0-2), attacks(bits 3-5), defenses(bits 6-7)
        uint256 turnStartTime;    // When current turn started
        
        // Game progression
        uint8 totalTurns;         // Total turns played
        bool gridRevealed;        // True if grid penalty is active (after 3 skips)
        
        // Entry fee tracking
        uint256 totalPot;         // Total entry fees collected
        bool feesDistributed;     // Whether fees have been distributed
    }

    mapping(uint256 => GameState) public gameStates;

    /**
     * @dev Function3: Fleet composition tracking
     * Tracks which NFTs each player is using in the game
     */
    struct PlayerFleet {
        uint256[] shipIds;        // NFT IDs of ships being used
        uint256 captainId;        // NFT ID of captain (0 if none)
        uint256[] crewIds;        // NFT IDs of crew members
        mapping(uint8 => uint8) shipPositions;  // shipIndex => gridPosition
        mapping(uint8 => ShipRotation) shipRotations; // shipIndex => rotation
        mapping(uint8 => uint8) shipHealth;     // shipIndex => current health
        bool fleetPlaced;         // Whether ships have been placed on grid
    }

    mapping(uint256 => mapping(address => PlayerFleet)) public playerFleets;

    /**
     * @dev Function4: Visibility system for fog of war
     * Tracks what each player has revealed about opponent's grid
     */
    struct VisibilityState {
        mapping(uint8 => bool) revealedCells;     // cellIndex => isRevealed
        uint8 totalRevealed;                      // Count of revealed cells
        uint8 shipsFound;                         // Count of enemy ships found
        uint8 shipsDestroyed;                     // Count of enemy ships destroyed
    }

    mapping(uint256 => mapping(address => VisibilityState)) public visibilityStates;

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event GameCreated(uint256 indexed gameId, address indexed creator, GameSize size, uint256 entryFee);
    event GameJoined(uint256 indexed gameId, address indexed player);
    event GameStarted(uint256 indexed gameId);
    event GameCompleted(uint256 indexed gameId, address indexed winner, address indexed loser);
    event ShipDestroyed(uint256 indexed gameId, address indexed player, uint256 indexed shipId);
    event TurnAdvanced(uint256 indexed gameId, address indexed player, uint8 actionsRemaining);
    event CellRevealed(uint256 indexed gameId, address indexed player, uint8 cellIndex, CellState cellState);
    event ShipPlaced(uint256 indexed gameId, address indexed player, uint8 shipIndex, uint8 position, ShipRotation rotation);
    event NFTManagerUpdated(address indexed oldManager, address indexed newManager);
    
    // =============================================================================
    // MODIFIERS
    // =============================================================================
    
    modifier gameExists(uint256 gameId) {
        require(gameId > 0 && gameId <= gameCounter, "BattleshipGame: Game does not exist");
        _;
    }
    
    modifier playerInGame(uint256 gameId) {
        GameInfo memory game = games[gameId];
        require(
            msg.sender == game.player1 || msg.sender == game.player2,
            "BattleshipGame: Not a player in this game"
        );
        _;
    }
    
    modifier isPlayerTurn(uint256 gameId) {
        require(
            games[gameId].currentTurn == msg.sender,
            "BattleshipGame: Not your turn"
        );
        _;
    }
    
    modifier gameInStatus(uint256 gameId, GameStatus status) {
        require(
            games[gameId].status == status,
            "BattleshipGame: Game not in required status"
        );
        _;
    }

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _initialAdmin,
        address _shipNFTManager,
        address _actionNFTManager,
        address _captainAndCrewNFTManager
    ) {
        require(_initialAdmin != address(0), "BattleshipGame: Initial admin cannot be zero address");
        require(_shipNFTManager != address(0), "BattleshipGame: Ship NFT manager cannot be zero address");
        require(_actionNFTManager != address(0), "BattleshipGame: Action NFT manager cannot be zero address");
        require(_captainAndCrewNFTManager != address(0), "BattleshipGame: Captain and crew NFT manager cannot be zero address");
        
        _transferOwnership(_initialAdmin);
        gameCounter = 0;
        
        // Set NFT contract addresses
        shipNFTManager = IShipNFTManager(_shipNFTManager);
        actionNFTManager = IActionNFTManager(_actionNFTManager);
        captainAndCrewNFTManager = ICaptainAndCrewNFTManager(_captainAndCrewNFTManager);
        
        // Initialize ante system - 1 S for testing (1 * 10^18 wei)
        anteConfig.useFixedAnte = true;
        anteConfig.fixedAnteAmount = 1 ether; // 1 S
    }

    // =============================================================================
    // GRID MANIPULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Get cell state from packed grid storage
     * @param grid The grid state to read from
     * @param cellIndex The cell index (0-99 for 10x10 grid)
     * @return CellState The state of the cell
     */
    function getCellState(GridState memory grid, uint8 cellIndex) public pure returns (CellState) {
        require(cellIndex < 100, "BattleshipGame: Cell index out of bounds");
        
        uint256 bitPosition;
        uint256 data;
        
        if (cellIndex < 85) {
            // Cell is in data1
            bitPosition = cellIndex * 3;
            data = grid.data1;
        } else {
            // Cell is in data2
            bitPosition = (cellIndex - 85) * 3;
            data = grid.data2;
        }
        
        uint256 cellValue = (data >> bitPosition) & 0x7; // Extract 3 bits
        return CellState(cellValue);
    }

    /**
     * @dev Set cell state in packed grid storage
     * @param grid The grid state to modify
     * @param cellIndex The cell index (0-99 for 10x10 grid)
     * @param state The new state for the cell
     */
    function setCellState(GridState storage grid, uint8 cellIndex, CellState state) internal {
        require(cellIndex < 100, "BattleshipGame: Cell index out of bounds");
        require(uint8(state) < 8, "BattleshipGame: Invalid cell state");
        
        uint256 bitPosition;
        uint256 stateValue = uint256(state);
        
        if (cellIndex < 85) {
            // Cell is in data1
            bitPosition = cellIndex * 3;
            // Clear the 3 bits at position
            grid.data1 &= ~(uint256(0x7) << bitPosition);
            // Set the new value
            grid.data1 |= (stateValue << bitPosition);
        } else {
            // Cell is in data2
            bitPosition = (cellIndex - 85) * 3;
            // Clear the 3 bits at position
            grid.data2 &= ~(uint256(0x7) << bitPosition);
            // Set the new value
            grid.data2 |= (stateValue << bitPosition);
        }
    }

    /**
     * @dev Convert grid coordinates to cell index
     * @param row Grid row (0-9)
     * @param col Grid column (0-9)
     * @return uint8 Cell index (0-99)
     */
    function coordsToIndex(uint8 row, uint8 col) public pure returns (uint8) {
        require(row < 10 && col < 10, "BattleshipGame: Coordinates out of bounds");
        return row * 10 + col;
    }

    /**
     * @dev Convert cell index to grid coordinates
     * @param cellIndex Cell index (0-99)
     * @return row Grid row (0-9)
     * @return col Grid column (0-9)
     */
    function indexToCoords(uint8 cellIndex) public pure returns (uint8 row, uint8 col) {
        require(cellIndex < 100, "BattleshipGame: Cell index out of bounds");
        row = cellIndex / 10;
        col = cellIndex % 10;
    }

    /**
     * @dev Get full grid state as array for frontend
     * @param gameId Game ID
     * @param player Player address
     * @return cells Array of cell states (100 elements)
     */
    function getPlayerGrid(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (uint8[] memory cells) 
    {
        cells = new uint8[](100);
        GridState memory grid = playerGrids[gameId][player];
        
        for (uint8 i = 0; i < 100; i++) {
            cells[i] = uint8(getCellState(grid, i));
        }
    }

    /**
     * @dev Get visible grid state (what player can see of opponent)
     * @param gameId Game ID
     * @param player Player address
     * @return cells Array of visible cell states (100 elements)
     */
    function getVisibleGrid(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (uint8[] memory cells) 
    {
        cells = new uint8[](100);
        GridState memory visGrid = visibilityGrids[gameId][player];
        
        for (uint8 i = 0; i < 100; i++) {
            cells[i] = uint8(getCellState(visGrid, i));
        }
    }

    // =============================================================================
    // SECTION 3.2: GAME INITIALIZATION AND SETUP
    // =============================================================================

    /**
     * @dev Set contract addresses for integration
     * @param _gameConfig GameConfig contract address
     * @param _shipNFTManager ShipNFTManager contract address
     * @param _actionNFTManager ActionNFTManager contract address
     * @param _captainAndCrewNFTManager CaptainAndCrewNFTManager contract address
     * @param _tokenomicsCore TokenomicsCore contract address
     */
    function setContractAddresses(
        address _gameConfig,
        address _shipNFTManager,
        address _actionNFTManager,
        address _captainAndCrewNFTManager,
        address _tokenomicsCore
    ) external onlyOwner {
        require(_gameConfig != address(0), "BattleshipGame: GameConfig cannot be zero address");
        require(_shipNFTManager != address(0), "BattleshipGame: ShipNFTManager cannot be zero address");
        require(_actionNFTManager != address(0), "BattleshipGame: ActionNFTManager cannot be zero address");
        require(_captainAndCrewNFTManager != address(0), "BattleshipGame: CaptainAndCrewNFTManager cannot be zero address");
        require(_tokenomicsCore != address(0), "BattleshipGame: TokenomicsCore cannot be zero address");
        
        gameConfig = IGameConfig(_gameConfig);
        shipNFTManager = IShipNFTManager(_shipNFTManager);
        actionNFTManager = IActionNFTManager(_actionNFTManager);
        captainAndCrewNFTManager = ICaptainAndCrewNFTManager(_captainAndCrewNFTManager);
        tokenomicsCore = ITokenomicsCore(_tokenomicsCore);
        
        // Keep legacy storage for compatibility
        gameConfigContract = _gameConfig;
        shipNFTManagerContract = _shipNFTManager;
        actionNFTManagerContract = _actionNFTManager;
        captainAndCrewNFTManagerContract = _captainAndCrewNFTManager;
        tokenomicsCoreContract = _tokenomicsCore;
    }
    
    /**
     * @dev Update ship NFT manager address
     * @param _shipNFTManager New ship NFT manager address
     */
    function updateShipNFTManager(address _shipNFTManager) external onlyOwner {
        require(_shipNFTManager != address(0), "BattleshipGame: Ship NFT manager cannot be zero address");
        address oldManager = address(shipNFTManager);
        shipNFTManager = IShipNFTManager(_shipNFTManager);
        emit NFTManagerUpdated(oldManager, _shipNFTManager);
    }
    
    /**
     * @dev Update action NFT manager address
     * @param _actionNFTManager New action NFT manager address
     */
    function updateActionNFTManager(address _actionNFTManager) external onlyOwner {
        require(_actionNFTManager != address(0), "BattleshipGame: Action NFT manager cannot be zero address");
        address oldManager = address(actionNFTManager);
        actionNFTManager = IActionNFTManager(_actionNFTManager);
        emit NFTManagerUpdated(oldManager, _actionNFTManager);
    }
    
    /**
     * @dev Update captain and crew NFT manager address
     * @param _captainAndCrewNFTManager New captain and crew NFT manager address
     */
    function updateCaptainAndCrewNFTManager(address _captainAndCrewNFTManager) external onlyOwner {
        require(_captainAndCrewNFTManager != address(0), "BattleshipGame: Captain and crew NFT manager cannot be zero address");
        address oldManager = address(captainAndCrewNFTManager);
        captainAndCrewNFTManager = ICaptainAndCrewNFTManager(_captainAndCrewNFTManager);
        emit NFTManagerUpdated(oldManager, _captainAndCrewNFTManager);
    }

    /**
     * @dev Function1: Create new game with standardized ante
     * @param size Game size (SHRIMP, FISH, SHARK, WHALE)
     * @return gameId The ID of the created game
     */
    function createGame(GameSize size) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
        returns (uint256 gameId) 
    {
        uint256 requiredAnte = _getRequiredAnte(size);
        require(msg.value == requiredAnte, "BattleshipGame: Incorrect ante amount");
        require(requiredAnte > 0, "BattleshipGame: Ante must be greater than zero");
        
        // Increment game counter and assign ID
        gameCounter++;
        gameId = gameCounter;
        
        // Initialize game info
        games[gameId] = GameInfo({
            player1: msg.sender,
            player2: address(0),
            size: size,
            status: GameStatus.WAITING,
            entryFee: requiredAnte,
            startTime: 0,
            lastMoveTime: 0,
            currentTurn: address(0),
            skipCount: 0
        });
        
        // Initialize game state
        gameStates[gameId] = GameState({
            player1ActionsUsed: 0,
            player2ActionsUsed: 0,
            turnStartTime: 0,
            totalTurns: 0,
            gridRevealed: false,
            totalPot: requiredAnte,
            feesDistributed: false
        });
        
        emit GameCreated(gameId, msg.sender, size, requiredAnte);
    }

    /**
     * @dev Get required ante for game size
     * @param size Game size
     * @return ante Required ante amount in wei
     */
    function _getRequiredAnte(GameSize size) internal view returns (uint256 ante) {
        if (anteConfig.useFixedAnte) {
            return anteConfig.fixedAnteAmount;
        } else {
            return anteConfig.gameTypeAntes[size];
        }
    }

    /**
     * @dev Get required ante for game size (public view)
     * @param size Game size
     * @return ante Required ante amount in wei
     */
    function getRequiredAnte(GameSize size) external view returns (uint256 ante) {
        return _getRequiredAnte(size);
    }

    /**
     * @dev Update ante configuration (admin only)
     * @param useFixed True for fixed ante, false for flexible system
     * @param fixedAmount Fixed ante amount (when useFixed = true)
     */
    function updateAnteConfig(bool useFixed, uint256 fixedAmount) external onlyOwner {
        anteConfig.useFixedAnte = useFixed;
        if (useFixed) {
            require(fixedAmount > 0, "BattleshipGame: Fixed ante must be greater than zero");
            anteConfig.fixedAnteAmount = fixedAmount;
        }
        emit AnteConfigUpdated(useFixed, fixedAmount);
    }

    /**
     * @dev Set ante for specific game type (for future flexible system)
     * @param gameSize Game size to set ante for
     * @param anteAmount Ante amount in wei
     */
    function setGameTypeAnte(GameSize gameSize, uint256 anteAmount) external onlyOwner {
        require(anteAmount > 0, "BattleshipGame: Ante must be greater than zero");
        anteConfig.gameTypeAntes[gameSize] = anteAmount;
        emit GameTypeAnteUpdated(gameSize, anteAmount);
    }

    /**
     * @dev Function2: Join existing game
     * @param gameId ID of the game to join
     * @param shipIds Array of ship NFT IDs to use
     * @param captainId Captain NFT ID (0 if none)
     * @param crewIds Array of crew NFT IDs to use
     */
    function joinGame(
        uint256 gameId,
        uint256[] calldata shipIds,
        uint256 captainId,
        uint256[] calldata crewIds
    ) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.WAITING) 
    {
        GameInfo storage game = games[gameId];
        require(msg.sender != game.player1, "BattleshipGame: Cannot join your own game");
        require(game.player2 == address(0), "BattleshipGame: Game already full");
        require(msg.value == game.entryFee, "BattleshipGame: Incorrect entry fee amount");
        
        // Validate fleet composition
        _validateFleetComposition(shipIds, captainId, crewIds);
        
        // Set player 2
        game.player2 = msg.sender;
        gameStates[gameId].totalPot += msg.value;
        
        // Store player fleet
        PlayerFleet storage fleet = playerFleets[gameId][msg.sender];
        fleet.shipIds = shipIds;
        fleet.captainId = captainId;
        fleet.crewIds = crewIds;
        fleet.fleetPlaced = false;
        
        emit GameJoined(gameId, msg.sender);
        
        // If both players have joined, they can start placing ships
        // Game will start after both players place their fleets
    }

    /**
     * @dev Function3: Fleet selection and validation
     * @param shipIds Array of ship NFT IDs
     * @param captainId Captain NFT ID
     * @param crewIds Array of crew NFT IDs
     */
    function _validateFleetComposition(
        uint256[] calldata shipIds,
        uint256 captainId,
        uint256[] calldata crewIds
    ) internal view {
        require(shipIds.length == 5, "BattleshipGame: Must have exactly 5 ships");
        require(crewIds.length <= 15, "BattleshipGame: Too many crew members"); // Max crew capacity
        require(address(shipNFTManager) != address(0), "BattleshipGame: ShipNFTManager not set");
        require(address(captainAndCrewNFTManager) != address(0), "BattleshipGame: CaptainAndCrewNFTManager not set");
        
        // Validate ship ownership and usability
        for (uint256 i = 0; i < shipIds.length; i++) {
            require(shipIds[i] > 0, "BattleshipGame: Ship ID cannot be zero");
            require(shipNFTManager.ownerOf(shipIds[i]) == msg.sender, "BattleshipGame: Not owner of ship");
            require(shipNFTManager.canUseShip(shipIds[i]), "BattleshipGame: Ship cannot be used");
        }
        
        // Validate captain ownership (if provided)
        if (captainId > 0) {
            require(captainAndCrewNFTManager.ownerOf(captainId) == msg.sender, "BattleshipGame: Not owner of captain");
            // Captain info will be validated by the NFTManager internally
        }
        
        // Validate crew ownership and stamina
        for (uint256 i = 0; i < crewIds.length; i++) {
            require(crewIds[i] > 0, "BattleshipGame: Crew ID cannot be zero");
            require(captainAndCrewNFTManager.ownerOf(crewIds[i]) == msg.sender, "BattleshipGame: Not owner of crew");
            
            (bool canUse, uint8 currentStamina) = captainAndCrewNFTManager.canUseCrew(crewIds[i]);
            require(canUse, "BattleshipGame: Crew has insufficient stamina");
        }
    }

    /**
     * @dev Function4: Ship placement on grid
     * @param gameId Game ID
     * @param positions Array of positions for each ship (5 ships)
     * @param rotations Array of rotations for each ship
     */
    function placeShips(
        uint256 gameId,
        uint8[] calldata positions,
        ShipRotation[] calldata rotations
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        gameExists(gameId) 
        playerInGame(gameId) 
    {
        require(positions.length == 5, "BattleshipGame: Must place exactly 5 ships");
        require(rotations.length == 5, "BattleshipGame: Must specify rotation for each ship");
        
        GameInfo storage game = games[gameId];
        require(
            game.status == GameStatus.WAITING,
            "BattleshipGame: Can only place ships before game starts"
        );
        
        PlayerFleet storage fleet = playerFleets[gameId][msg.sender];
        require(!fleet.fleetPlaced, "BattleshipGame: Fleet already placed");
        
        // Validate ship placements don't overlap
        _validateShipPlacements(positions, rotations);
        
        // Place ships on grid
        GridState storage grid = playerGrids[gameId][msg.sender];
        
        for (uint8 i = 0; i < 5; i++) {
            fleet.shipPositions[i] = positions[i];
            fleet.shipRotations[i] = rotations[i];
            
            // Get ship stats from ShipNFTManager
            uint8 shipSize;
            uint8 shipHealth;
            if (address(shipNFTManager) != address(0)) {
                (, , IShipNFTManager.ShipStats memory stats, , ,) = shipNFTManager.getShipInfo(fleet.shipIds[i]);
                shipSize = stats.size;
                shipHealth = stats.health;
            } else {
                // Fallback to default values
                uint8[5] memory defaultSizes = [2, 3, 3, 4, 5];
                shipSize = defaultSizes[i];
                shipHealth = shipSize;
            }
            
            fleet.shipHealth[i] = shipHealth;
            
            // Mark ship cells on grid
            _placeShipOnGrid(grid, positions[i], rotations[i], shipSize);
            
            emit ShipPlaced(gameId, msg.sender, i, positions[i], rotations[i]);
        }
        
        fleet.fleetPlaced = true;
        
        // Check if both players have placed their fleets
        if (_bothPlayersReady(gameId)) {
            _startGame(gameId);
        }
    }

    /**
     * @dev Validate that ship placements don't overlap and are within bounds
     * @param positions Array of ship positions
     * @param rotations Array of ship rotations
     */
    function _validateShipPlacements(
        uint8[] calldata positions,
        ShipRotation[] calldata rotations
    ) internal pure {
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        bool[100] memory occupiedCells;
        
        for (uint8 i = 0; i < 5; i++) {
            uint8[] memory shipCells = _getShipCells(positions[i], rotations[i], shipSizes[i]);
            
            for (uint8 j = 0; j < shipCells.length; j++) {
                require(shipCells[j] < 100, "BattleshipGame: Ship placement out of bounds");
                require(!occupiedCells[shipCells[j]], "BattleshipGame: Ship overlap detected");
                occupiedCells[shipCells[j]] = true;
            }
        }
    }

    /**
     * @dev Get array of cell indices occupied by a ship
     * @param startPos Starting position of ship
     * @param rotation Ship rotation
     * @param size Ship size
     * @return cells Array of cell indices
     */
    function _getShipCells(
        uint8 startPos,
        ShipRotation rotation,
        uint8 size
    ) internal pure returns (uint8[] memory cells) {
        cells = new uint8[](size);
        (uint8 startRow, uint8 startCol) = indexToCoords(startPos);
        
        for (uint8 i = 0; i < size; i++) {
            uint8 row = startRow;
            uint8 col = startCol;
            
            if (rotation == ShipRotation.HORIZONTAL) {
                col += i;
            } else if (rotation == ShipRotation.VERTICAL) {
                row += i;
            } else if (rotation == ShipRotation.DIAGONAL_RIGHT) {
                row += i;
                col += i;
            } else if (rotation == ShipRotation.DIAGONAL_LEFT) {
                row += i;
                col = startCol > i ? startCol - i : 0; // Prevent underflow
            }
            
            require(row < 10 && col < 10, "BattleshipGame: Ship extends beyond grid bounds");
            cells[i] = coordsToIndex(row, col);
        }
    }

    /**
     * @dev Place a ship on the grid
     * @param grid Grid to place ship on
     * @param startPos Starting position
     * @param rotation Ship rotation
     * @param size Ship size
     */
    function _placeShipOnGrid(
        GridState storage grid,
        uint8 startPos,
        ShipRotation rotation,
        uint8 size
    ) internal {
        uint8[] memory shipCells = _getShipCells(startPos, rotation, size);
        
        for (uint8 i = 0; i < shipCells.length; i++) {
            setCellState(grid, shipCells[i], CellState.SHIP);
        }
    }

    /**
     * @dev Check if both players are ready to start
     * @param gameId Game ID
     * @return bool True if both players have placed their fleets
     */
    function _bothPlayersReady(uint256 gameId) internal view returns (bool) {
        GameInfo memory game = games[gameId];
        return (
            game.player2 != address(0) &&
            playerFleets[gameId][game.player1].fleetPlaced &&
            playerFleets[gameId][game.player2].fleetPlaced
        );
    }

    /**
     * @dev Start the game once both players are ready
     * @param gameId Game ID
     */
    function _startGame(uint256 gameId) internal {
        GameInfo storage game = games[gameId];
        GameState storage state = gameStates[gameId];
        
        game.status = GameStatus.ACTIVE;
        game.startTime = block.timestamp;
        game.lastMoveTime = block.timestamp;
        game.currentTurn = game.player1; // Player 1 goes first
        
        state.turnStartTime = block.timestamp;
        
        // Consume crew stamina for both players
        _consumeCrewStamina(gameId, game.player1);
        _consumeCrewStamina(gameId, game.player2);
        
        emit GameStarted(gameId);
    }

    /**
     * @dev Get game information
     * @param gameId Game ID
     * @return GameInfo struct with game details
     */
    function getGameInfo(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        returns (GameInfo memory) 
    {
        return games[gameId];
    }

    /**
     * @dev Get current turn information
     * @param gameId Game ID
     * @return player Address of player whose turn it is
     */
    function getCurrentTurn(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        returns (address player) 
    {
        return games[gameId].currentTurn;
    }

    /**
     * @dev Consume crew stamina when game starts
     * @param gameId Game ID
     * @param player Player address
     */
    function _consumeCrewStamina(uint256 gameId, address player) internal {
        if (address(captainAndCrewNFTManager) == address(0)) {
            return; // CaptainAndCrewNFTManager not set
        }
        
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        // Consume stamina from each crew member
        for (uint256 i = 0; i < fleet.crewIds.length; i++) {
            if (fleet.crewIds[i] > 0) {
                captainAndCrewNFTManager.useCrewStamina(fleet.crewIds[i], player);
            }
        }
    }

    // =============================================================================
    // FRONTEND VIEW FUNCTIONS (Section 9.2)
    // =============================================================================

    /**
     * @dev Get complete game state for frontend
     * @param gameId Game ID
     * @return gameInfo Basic game information
     * @return gameState Additional game state data
     */
    function getCompleteGameState(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        returns (GameInfo memory gameInfo, GameState memory gameState) 
    {
        gameInfo = games[gameId];
        gameState = gameStates[gameId];
    }

    /**
     * @dev Get player fleet information
     * @param gameId Game ID
     * @param player Player address
     * @return fleet Player fleet data
     */
    function getPlayerFleet(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (PlayerFleet memory fleet) 
    {
        fleet = playerFleets[gameId][player];
    }

    /**
     * @dev Get player grid data
     * @param gameId Game ID
     * @param player Player address
     * @return grid Grid state (visible to everyone)
     */
    function getPlayerGrid(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (uint256[2] memory grid) 
    {
        GridState memory gridState = playerGrids[gameId][player];
        grid[0] = gridState.data1;
        grid[1] = gridState.data2;
    }

    /**
     * @dev Get visibility grid for opponent view
     * @param gameId Game ID
     * @param viewer Player viewing the grid
     * @return grid Visibility grid (what viewer can see of opponent)
     */
    function getVisibleGrid(uint256 gameId, address viewer) 
        external 
        view 
        gameExists(gameId) 
        returns (uint256[2] memory grid) 
    {
        GridState memory gridState = visibilityGrids[gameId][viewer];
        grid[0] = gridState.data1;
        grid[1] = gridState.data2;
    }

    /**
     * @dev Get visibility statistics for player
     * @param gameId Game ID
     * @param player Player address
     * @return totalRevealed Total cells revealed
     * @return shipsFound Ships found by player
     */
    function getVisibilityStats(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (uint256 totalRevealed, uint256 shipsFound) 
    {
        VisibilityState memory visState = visibilityStates[gameId][player];
        totalRevealed = visState.totalRevealed;
        shipsFound = visState.shipsFound;
    }

    /**
     * @dev Get ship health status for all ships
     * @param gameId Game ID
     * @param player Player address
     * @return healths Array of ship health values
     */
    function getShipHealthStatus(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (uint8[5] memory healths) 
    {
        PlayerFleet memory fleet = playerFleets[gameId][player];
        healths = fleet.shipHealth;
    }

    /**
     * @dev Check if game can be joined
     * @param gameId Game ID
     * @return canJoin True if game can be joined
     * @return reason Reason if cannot join
     */
    function canJoinGame(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        returns (bool canJoin, string memory reason) 
    {
        GameInfo memory game = games[gameId];
        
        if (game.status != GameStatus.WAITING) {
            return (false, "Game not in waiting status");
        }
        
        if (game.player2 != address(0)) {
            return (false, "Game already full");
        }
        
        if (game.player1 == msg.sender) {
            return (false, "Cannot join your own game");
        }
        
        return (true, "");
    }

    /**
     * @dev Batch function to get multiple game states
     * @param gameIds Array of game IDs
     * @return gameInfos Array of game information
     */
    function getBatchGameInfo(uint256[] calldata gameIds) 
        external 
        view 
        returns (GameInfo[] memory gameInfos) 
    {
        gameInfos = new GameInfo[](gameIds.length);
        
        for (uint256 i = 0; i < gameIds.length; i++) {
            if (gameIds[i] <= gameCounter && gameIds[i] > 0) {
                gameInfos[i] = games[gameIds[i]];
            }
        }
    }

    // =============================================================================
    // SECTION 3.3: TURN MANAGEMENT SYSTEM
    // =============================================================================

    /**
     * @dev Function1: Turn timer implementation
     * Check if current turn has exceeded time limit
     * @param gameId Game ID
     * @return hasExpired True if turn time has expired
     * @return timeRemaining Seconds remaining in current turn
     */
    function checkTurnTimer(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE)
        returns (bool hasExpired, uint256 timeRemaining) 
    {
        GameState memory state = gameStates[gameId];
        
        // Get turn timer from GameConfig
        uint256 turnTimeLimit = 5 minutes; // Default fallback
        if (address(gameConfig) != address(0)) {
            turnTimeLimit = gameConfig.getTurnTimer();
        }
        
        uint256 elapsed = block.timestamp - state.turnStartTime;
        
        if (elapsed >= turnTimeLimit) {
            hasExpired = true;
            timeRemaining = 0;
        } else {
            hasExpired = false;
            timeRemaining = turnTimeLimit - elapsed;
        }
    }

    /**
     * @dev Function2: Turn skip detection and penalties
     * Force skip turn if time limit exceeded
     * @param gameId Game ID
     */
    function forceSkipTurn(uint256 gameId) 
        external 
        whenNotPaused 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
    {
        (bool hasExpired,) = this.checkTurnTimer(gameId);
        require(hasExpired, "BattleshipGame: Turn timer has not expired");
        
        GameInfo storage game = games[gameId];
        GameState storage state = gameStates[gameId];
        
        // Increment skip count
        game.skipCount++;
        
        // Check for grid reveal penalty (after 3 skips)
        // Get max skip turns from GameConfig
        uint8 maxSkipTurns = 3; // Default fallback
        if (address(gameConfig) != address(0)) {
            maxSkipTurns = gameConfig.getMaxSkipTurns();
        }
        
        if (game.skipCount >= maxSkipTurns) {
            state.gridRevealed = true;
            // Reveal entire grid to opponent
            _revealEntireGrid(gameId, game.currentTurn);
        }
        
        // Advance to next turn
        _advanceTurn(gameId);
    }

    /**
     * @dev Function3: Action counting per turn (2 moves, 1 attack, 2 defense)
     * Track and validate action usage per turn
     * @param gameId Game ID
     * @param player Player address
     * @return moves Moves remaining
     * @return attacks Attacks remaining  
     * @return defenses Defenses remaining
     */
    function getActionsRemaining(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (uint8 moves, uint8 attacks, uint8 defenses) 
    {
        GameInfo memory game = games[gameId];
        GameState memory state = gameStates[gameId];
        
        uint8 actionsUsed;
        if (player == game.player1) {
            actionsUsed = state.player1ActionsUsed;
        } else if (player == game.player2) {
            actionsUsed = state.player2ActionsUsed;
        } else {
            revert("BattleshipGame: Player not in game");
        }
        
        // Unpack actions: moves(bits 0-2), attacks(bits 3-5), defenses(bits 6-7)
        uint8 movesUsed = actionsUsed & 0x7;        // Extract bits 0-2
        uint8 attacksUsed = (actionsUsed >> 3) & 0x7; // Extract bits 3-5
        uint8 defensesUsed = (actionsUsed >> 6) & 0x3; // Extract bits 6-7
        
        moves = movesUsed >= 2 ? 0 : 2 - movesUsed;
        attacks = attacksUsed >= 1 ? 0 : 1 - attacksUsed;
        defenses = defensesUsed >= 2 ? 0 : 2 - defensesUsed;
    }

    /**
     * @dev Use an action for the current player
     * @param gameId Game ID
     * @param actionType 0=move, 1=attack, 2=defense
     */
    function _useAction(uint256 gameId, uint8 actionType) internal {
        require(actionType <= 2, "BattleshipGame: Invalid action type");
        
        GameInfo memory game = games[gameId];
        GameState storage state = gameStates[gameId];
        
        uint8 actionsUsed;
        bool isPlayer1 = (msg.sender == game.player1);
        
        if (isPlayer1) {
            actionsUsed = state.player1ActionsUsed;
        } else {
            actionsUsed = state.player2ActionsUsed;
        }
        
        // Unpack current actions
        uint8 movesUsed = actionsUsed & 0x7;
        uint8 attacksUsed = (actionsUsed >> 3) & 0x7;
        uint8 defensesUsed = (actionsUsed >> 6) & 0x3;
        
        // Validate action limits
        if (actionType == 0) { // Move
            require(movesUsed < 2, "BattleshipGame: No moves remaining this turn");
            movesUsed++;
        } else if (actionType == 1) { // Attack
            require(attacksUsed < 1, "BattleshipGame: No attacks remaining this turn");
            attacksUsed++;
        } else if (actionType == 2) { // Defense
            require(defensesUsed < 2, "BattleshipGame: No defenses remaining this turn");
            defensesUsed++;
        }
        
        // Pack actions back
        uint8 newActionsUsed = movesUsed | (attacksUsed << 3) | (defensesUsed << 6);
        
        if (isPlayer1) {
            state.player1ActionsUsed = newActionsUsed;
        } else {
            state.player2ActionsUsed = newActionsUsed;
        }
    }

    /**
     * @dev Function4: Turn transition logic
     * Advance to next player's turn
     * @param gameId Game ID
     */
    function _advanceTurn(uint256 gameId) internal {
        GameInfo storage game = games[gameId];
        GameState storage state = gameStates[gameId];
        
        // Switch current turn
        if (game.currentTurn == game.player1) {
            game.currentTurn = game.player2;
        } else {
            game.currentTurn = game.player1;
        }
        
        // Reset action counters for new turn
        if (game.currentTurn == game.player1) {
            state.player1ActionsUsed = 0;
        } else {
            state.player2ActionsUsed = 0;
        }
        
        // Update timing
        game.lastMoveTime = block.timestamp;
        state.turnStartTime = block.timestamp;
        state.totalTurns++;
        
        // Reset skip count on successful turn
        game.skipCount = 0;
        
        // Get remaining actions for the new turn
        (uint8 moves, uint8 attacks, uint8 defenses) = this.getActionsRemaining(gameId, game.currentTurn);
        uint8 totalActionsRemaining = moves + attacks + defenses;
        
        emit TurnAdvanced(gameId, game.currentTurn, totalActionsRemaining);
    }

    /**
     * @dev End current player's turn voluntarily
     * @param gameId Game ID
     */
    function endTurn(uint256 gameId) 
        external 
        whenNotPaused 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
        isPlayerTurn(gameId) 
    {
        _advanceTurn(gameId);
    }

    /**
     * @dev Reveal entire grid as penalty for excessive skipping
     * @param gameId Game ID
     * @param skippingPlayer Player who skipped too many turns
     */
    function _revealEntireGrid(uint256 gameId, address skippingPlayer) internal {
        GameInfo memory game = games[gameId];
        address opponent = (skippingPlayer == game.player1) ? game.player2 : game.player1;
        
        // Get skipping player's grid
        GridState memory playerGrid = playerGrids[gameId][skippingPlayer];
        
        // Reveal entire grid to opponent
        GridState storage opponentVisibility = visibilityGrids[gameId][opponent];
        VisibilityState storage visState = visibilityStates[gameId][opponent];
        
        for (uint8 i = 0; i < 100; i++) {
            CellState cellState = getCellState(playerGrid, i);
            setCellState(opponentVisibility, i, cellState);
            
            if (!visState.revealedCells[i]) {
                visState.revealedCells[i] = true;
                visState.totalRevealed++;
                
                if (cellState == CellState.SHIP) {
                    visState.shipsFound++;
                }
            }
        }
    }

    /**
     * @dev Check if player has any actions remaining this turn
     * @param gameId Game ID
     * @param player Player to check
     * @return hasActions True if player has actions remaining
     */
    function hasActionsRemaining(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (bool hasActions) 
    {
        (uint8 moves, uint8 attacks, uint8 defenses) = this.getActionsRemaining(gameId, player);
        return (moves > 0 || attacks > 0 || defenses > 0);
    }

    // =============================================================================
    // SECTION 3.4: SHIP MOVEMENT AND ROTATION
    // =============================================================================

    /**
     * @dev Function1: Valid movement calculation
     * Calculate valid movement positions for a ship based on its speed
     * @param gameId Game ID
     * @param shipIndex Index of ship in player's fleet (0-4)
     * @return validPositions Array of valid position indices
     */
    function getValidMovePositions(uint256 gameId, uint8 shipIndex) 
        external 
        view 
        gameExists(gameId) 
        playerInGame(gameId) 
        returns (uint8[] memory validPositions) 
    {
        require(shipIndex < 5, "BattleshipGame: Invalid ship index");
        
        PlayerFleet storage fleet = playerFleets[gameId][msg.sender];
        uint8 currentPosition = fleet.shipPositions[shipIndex];
        
        // TODO: Get ship stats from NFTManager or use default
        uint8 shipSpeed = 2; // Default speed, will be fetched from NFTManager
        
        // Get current ship cells to check for collisions
        ShipRotation currentRotation = fleet.shipRotations[shipIndex];
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        uint8 shipSize = shipSizes[shipIndex];
        
        // Calculate valid positions within movement range
        uint8[] memory tempPositions = new uint8[](100);
        uint8 validCount = 0;
        
        (uint8 currentRow, uint8 currentCol) = indexToCoords(currentPosition);
        
        // Check all positions within movement range
        for (int8 rowOffset = -int8(shipSpeed); rowOffset <= int8(shipSpeed); rowOffset++) {
            for (int8 colOffset = -int8(shipSpeed); colOffset <= int8(shipSpeed); colOffset++) {
                // Skip if move distance exceeds ship speed
                uint8 moveDistance = uint8(abs(rowOffset) + abs(colOffset));
                if (moveDistance == 0 || moveDistance > shipSpeed) continue;
                
                int8 newRow = int8(currentRow) + rowOffset;
                int8 newCol = int8(currentCol) + colOffset;
                
                // Check bounds
                if (newRow < 0 || newRow >= 10 || newCol < 0 || newCol >= 10) continue;
                
                uint8 newPosition = coordsToIndex(uint8(newRow), uint8(newCol));
                
                // Check if ship would fit at new position
                if (_canPlaceShipAt(gameId, msg.sender, newPosition, currentRotation, shipSize, shipIndex)) {
                    tempPositions[validCount] = newPosition;
                    validCount++;
                }
            }
        }
        
        // Copy valid positions to properly sized array
        validPositions = new uint8[](validCount);
        for (uint8 i = 0; i < validCount; i++) {
            validPositions[i] = tempPositions[i];
        }
    }

    /**
     * @dev Function2: Ship rotation mechanics
     * Rotate a ship to a new orientation
     * @param gameId Game ID
     * @param shipIndex Index of ship to rotate
     * @param newRotation New rotation for the ship
     */
    function rotateShip(uint256 gameId, uint8 shipIndex, ShipRotation newRotation) 
        external 
        whenNotPaused 
        nonReentrant 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
        isPlayerTurn(gameId) 
        playerInGame(gameId) 
    {
        require(shipIndex < 5, "BattleshipGame: Invalid ship index");
        
        // Use a move action
        _useAction(gameId, 0); // 0 = move action
        
        PlayerFleet storage fleet = playerFleets[gameId][msg.sender];
        uint8 currentPosition = fleet.shipPositions[shipIndex];
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        uint8 shipSize = shipSizes[shipIndex];
        
        // Check if ship can be rotated to new orientation at current position
        require(
            _canPlaceShipAt(gameId, msg.sender, currentPosition, newRotation, shipSize, shipIndex),
            "BattleshipGame: Cannot rotate ship to this orientation"
        );
        
        // Remove ship from current position
        _removeShipFromGrid(gameId, msg.sender, shipIndex);
        
        // Update rotation
        fleet.shipRotations[shipIndex] = newRotation;
        
        // Place ship with new rotation
        GridState storage grid = playerGrids[gameId][msg.sender];
        _placeShipOnGrid(grid, currentPosition, newRotation, shipSize);
        
        emit ShipPlaced(gameId, msg.sender, shipIndex, currentPosition, newRotation);
    }

    /**
     * @dev Function3: Collision detection
     * Check if a ship can be placed at a specific position
     * @param gameId Game ID
     * @param player Player address
     * @param position Position to check
     * @param rotation Ship rotation
     * @param size Ship size
     * @param excludeShip Ship index to exclude from collision check
     * @return canPlace True if ship can be placed
     */
    function _canPlaceShipAt(
        uint256 gameId,
        address player,
        uint8 position,
        ShipRotation rotation,
        uint8 size,
        uint8 excludeShip
    ) internal view returns (bool canPlace) {
        // Get ship cells for the proposed position
        uint8[] memory shipCells = _getShipCells(position, rotation, size);
        
        // Check each cell
        GridState memory grid = playerGrids[gameId][player];
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        for (uint8 i = 0; i < shipCells.length; i++) {
            uint8 cellIndex = shipCells[i];
            
            // Check bounds
            if (cellIndex >= 100) return false;
            
            // Check if cell is occupied by another ship
            CellState cellState = getCellState(grid, cellIndex);
            if (cellState == CellState.SHIP) {
                // Check if this cell belongs to the ship we're moving
                bool belongsToMovingShip = false;
                uint8 currentPos = fleet.shipPositions[excludeShip];
                ShipRotation currentRot = fleet.shipRotations[excludeShip];
                uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
                
                uint8[] memory currentShipCells = _getShipCells(currentPos, currentRot, shipSizes[excludeShip]);
                
                for (uint8 j = 0; j < currentShipCells.length; j++) {
                    if (currentShipCells[j] == cellIndex) {
                        belongsToMovingShip = true;
                        break;
                    }
                }
                
                if (!belongsToMovingShip) {
                    return false; // Cell occupied by another ship
                }
            }
        }
        
        return true;
    }

    /**
     * @dev Function4: Movement validation and execution
     * Move a ship to a new position
     * @param gameId Game ID
     * @param shipIndex Index of ship to move
     * @param newPosition New position for the ship
     */
    function moveShip(uint256 gameId, uint8 shipIndex, uint8 newPosition) 
        external 
        whenNotPaused 
        nonReentrant 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
        isPlayerTurn(gameId) 
        playerInGame(gameId) 
    {
        require(shipIndex < 5, "BattleshipGame: Invalid ship index");
        require(newPosition < 100, "BattleshipGame: Position out of bounds");
        
        // Use a move action
        _useAction(gameId, 0); // 0 = move action
        
        PlayerFleet storage fleet = playerFleets[gameId][msg.sender];
        uint8 currentPosition = fleet.shipPositions[shipIndex];
        ShipRotation rotation = fleet.shipRotations[shipIndex];
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        uint8 shipSize = shipSizes[shipIndex];
        
        // Get ship speed from ShipNFTManager
        uint8 shipSpeed = 2; // Default fallback
        if (address(shipNFTManager) != address(0)) {
            (, , IShipNFTManager.ShipStats memory stats, , ,) = shipNFTManager.getShipInfo(fleet.shipIds[shipIndex]);
            shipSpeed = stats.speed;
        }
        
        // Validate movement is within ship's speed range
        require(
            _isValidMoveDistance(currentPosition, newPosition, shipSpeed),
            "BattleshipGame: Move distance exceeds ship speed"
        );
        
        // Check if ship can be placed at new position
        require(
            _canPlaceShipAt(gameId, msg.sender, newPosition, rotation, shipSize, shipIndex),
            "BattleshipGame: Cannot place ship at target position"
        );
        
        // Remove ship from current position
        _removeShipFromGrid(gameId, msg.sender, shipIndex);
        
        // Update position
        fleet.shipPositions[shipIndex] = newPosition;
        
        // Place ship at new position
        GridState storage grid = playerGrids[gameId][msg.sender];
        _placeShipOnGrid(grid, newPosition, rotation, shipSize);
        
        emit ShipPlaced(gameId, msg.sender, shipIndex, newPosition, rotation);
    }

    /**
     * @dev Remove ship from grid
     * @param gameId Game ID
     * @param player Player address
     * @param shipIndex Ship index to remove
     */
    function _removeShipFromGrid(uint256 gameId, address player, uint8 shipIndex) internal {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        GridState storage grid = playerGrids[gameId][player];
        
        uint8 position = fleet.shipPositions[shipIndex];
        ShipRotation rotation = fleet.shipRotations[shipIndex];
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        uint8 shipSize = shipSizes[shipIndex];
        
        uint8[] memory shipCells = _getShipCells(position, rotation, shipSize);
        
        for (uint8 i = 0; i < shipCells.length; i++) {
            setCellState(grid, shipCells[i], CellState.EMPTY);
        }
    }

    /**
     * @dev Check if movement distance is valid for ship's speed
     * @param fromPos Starting position
     * @param toPos Target position
     * @param speed Ship's movement speed
     * @return isValid True if move is within speed limit
     */
    function _isValidMoveDistance(uint8 fromPos, uint8 toPos, uint8 speed) internal pure returns (bool isValid) {
        (uint8 fromRow, uint8 fromCol) = indexToCoords(fromPos);
        (uint8 toRow, uint8 toCol) = indexToCoords(toPos);
        
        uint8 rowDiff = fromRow > toRow ? fromRow - toRow : toRow - fromRow;
        uint8 colDiff = fromCol > toCol ? fromCol - toCol : toCol - fromCol;
        uint8 distance = rowDiff + colDiff; // Manhattan distance
        
        return distance <= speed;
    }

    /**
     * @dev Helper function for absolute value
     * @param x Signed integer
     * @return Absolute value
     */
    function abs(int8 x) internal pure returns (uint8) {
        return x >= 0 ? uint8(x) : uint8(-x);
    }

    // =============================================================================
    // SECTION 3.5: COMBAT SYSTEM
    // =============================================================================

    /**
     * @dev Function1: Default attack implementation
     * Basic attack available to all players - targets single cell, deals 1 damage
     * @param gameId Game ID
     * @param targetCell Cell index to attack (0-99)
     */
    function defaultAttack(uint256 gameId, uint8 targetCell) 
        external 
        whenNotPaused 
        nonReentrant 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
        isPlayerTurn(gameId) 
        playerInGame(gameId) 
    {
        require(targetCell < 100, "BattleshipGame: Target cell out of bounds");
        
        // Use an attack action
        _useAction(gameId, 1); // 1 = attack action
        
        GameInfo memory game = games[gameId];
        address opponent = (msg.sender == game.player1) ? game.player2 : game.player1;
        
        // Get default attack damage from GameConfig
        uint8 baseDamage = 1; // Default fallback
        if (address(gameConfig) != address(0)) {
            baseDamage = gameConfig.getDefaultAttackDamage();
        }
        
        // Apply captain/crew bonuses if enabled
        uint8 totalDamage = _calculateAttackDamage(gameId, msg.sender, baseDamage, true);
        
        // Execute attack on single target cell
        uint8[] memory targetCells = new uint8[](1);
        targetCells[0] = targetCell;
        
        _executeAttack(gameId, msg.sender, opponent, targetCells, totalDamage);
    }

    /**
     * @dev Function2: Action NFT attack integration
     * Execute attack using Action NFT with custom patterns and damage
     * @param gameId Game ID
     * @param actionId NFT ID of action card to use
     * @param targetCells Array of target cell indices
     */
    function useActionNFT(uint256 gameId, uint256 actionId, uint8[] calldata targetCells) 
        external 
        whenNotPaused 
        nonReentrant 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
        isPlayerTurn(gameId) 
        playerInGame(gameId) 
    {
        require(actionId > 0, "BattleshipGame: Invalid action ID");
        require(targetCells.length > 0, "BattleshipGame: Must specify target cells");
        require(address(actionNFTManager) != address(0), "BattleshipGame: ActionNFTManager not set");
        
        // Validate NFT ownership and get action details from ActionNFTManager
        require(actionNFTManager.ownerOf(actionId) == msg.sender, "BattleshipGame: Not owner of action NFT");
        
        (IActionNFTManager.ActionPattern memory pattern, IActionNFTManager.ActionCategory category, uint256 usesRemaining) = actionNFTManager.getActionInfo(actionId);
        require(usesRemaining > 0, "BattleshipGame: Action NFT has no uses remaining");
        
        // Validate target pattern matches action
        require(targetCells.length == pattern.targetCells.length, "BattleshipGame: Target cells must match action pattern");
        
        // Use an attack action or defense action based on NFT category
        if (category == IActionNFTManager.ActionCategory.OFFENSIVE) {
            _useAction(gameId, 1); // 1 = attack action
        } else {
            _useAction(gameId, 2); // 2 = defense action
        }
        
        GameInfo memory game = games[gameId];
        address opponent = (msg.sender == game.player1) ? game.player2 : game.player1;
        
        // Get action damage from pattern
        uint8 actionDamage = pattern.damage;
        
        // Apply captain/crew bonuses if enabled for action attacks
        uint8 totalDamage = _calculateAttackDamage(gameId, msg.sender, actionDamage, false);
        
        // Execute attack with action pattern
        _executeAttack(gameId, msg.sender, opponent, targetCells, totalDamage);
        
        // Consume action NFT use in ActionNFTManager
        actionNFTManager.useAction(actionId, msg.sender);
    }

    /**
     * @dev Function3: Damage calculation with crew/captain bonuses
     * Calculate total damage including bonuses from captain and crew
     * @param gameId Game ID
     * @param attacker Attacking player address
     * @param baseDamage Base damage amount
     * @param isDefaultAttack Whether this is a default attack
     * @return totalDamage Final damage amount
     */
    function _calculateAttackDamage(
        uint256 gameId, 
        address attacker, 
        uint8 baseDamage,
        bool isDefaultAttack
    ) internal view returns (uint8 totalDamage) {
        totalDamage = baseDamage;
        PlayerFleet storage fleet = playerFleets[gameId][attacker];
        
        // Apply captain bonuses if captain exists and ability affects attacks
        if (fleet.captainId > 0) {
            // TODO: Get captain ability from NFTManager and check if it affects default attacks
            // For now, placeholder logic
            totalDamage = _applyCaptainBonus(totalDamage, fleet.captainId, isDefaultAttack);
        }
        
        // Apply crew bonuses (Gunner crew type increases damage)
        totalDamage = _applyCrewBonuses(gameId, attacker, totalDamage, isDefaultAttack);
        
        // Cap maximum damage to prevent overpowered combinations
        if (totalDamage > 5) totalDamage = 5;
    }

    /**
     * @dev Function4: Hit detection and grid updates
     * Execute attack on target cells and update game state
     * @param gameId Game ID
     * @param attacker Attacking player
     * @param defender Defending player
     * @param targetCells Array of cells being attacked
     * @param damage Damage per hit
     */
    function _executeAttack(
        uint256 gameId,
        address attacker,
        address defender,
        uint8[] memory targetCells,
        uint8 damage
    ) internal {
        GridState storage defenderGrid = playerGrids[gameId][defender];
        GridState storage attackerVisibility = visibilityGrids[gameId][attacker];
        VisibilityState storage visState = visibilityStates[gameId][attacker];
        
        for (uint8 i = 0; i < targetCells.length; i++) {
            uint8 cellIndex = targetCells[i];
            require(cellIndex < 100, "BattleshipGame: Target cell out of bounds");
            
            CellState currentState = getCellState(defenderGrid, cellIndex);
            CellState newState;
            
            // Reveal cell to attacker
            if (!visState.revealedCells[cellIndex]) {
                visState.revealedCells[cellIndex] = true;
                visState.totalRevealed++;
            }
            
            if (currentState == CellState.EMPTY) {
                // Miss
                newState = CellState.MISS;
                setCellState(defenderGrid, cellIndex, newState);
                setCellState(attackerVisibility, cellIndex, newState);
            } else if (currentState == CellState.SHIP) {
                // Hit
                newState = CellState.HIT;
                setCellState(defenderGrid, cellIndex, newState);
                setCellState(attackerVisibility, cellIndex, newState);
                
                // Apply damage to ship
                uint8 shipIndex = _findShipAtCell(gameId, defender, cellIndex);
                if (shipIndex < 5) {
                    _damageShip(gameId, defender, shipIndex, damage, cellIndex);
                }
                
                visState.shipsFound++;
            } else if (currentState == CellState.SHIELDED) {
                // Hit shield - TODO: implement shield logic
                newState = CellState.HIT;
                setCellState(defenderGrid, cellIndex, newState);
                setCellState(attackerVisibility, cellIndex, newState);
            }
            
            emit CellRevealed(gameId, attacker, cellIndex, newState);
        }
        
        // Check for game completion after attack
        if (_checkGameEnd(gameId)) {
            _endGame(gameId);
        }
    }

    /**
     * @dev Apply captain ability bonuses to damage
     * @param baseDamage Base damage amount
     * @param captainId Captain NFT ID
     * @param isDefaultAttack Whether this affects default attacks
     * @return boostedDamage Damage with captain bonus applied
     */
    function _applyCaptainBonus(
        uint8 baseDamage, 
        uint256 captainId, 
        bool isDefaultAttack
    ) internal view returns (uint8 boostedDamage) {
        boostedDamage = baseDamage;
        
        if (address(captainAndCrewNFTManager) == address(0) || address(gameConfig) == address(0)) {
            return boostedDamage; // Contracts not set
        }
        
        // Get captain info from CaptainAndCrewNFTManager
        ICaptainAndCrewNFTManager.CaptainInfo memory captainInfo = captainAndCrewNFTManager.getCaptainInfo(captainId);
        
        // Check if ability affects default attacks (from GameConfig)
        if (isDefaultAttack && !gameConfig.getCaptainDefaultAttackToggle(captainInfo.ability)) {
            return boostedDamage; // This ability doesn't affect default attacks
        }
        
        // Apply damage boost if captain has damage boost ability
        if (captainInfo.ability == ICaptainAndCrewNFTManager.CaptainAbility.DAMAGE_BOOST) {
            boostedDamage += 1; // +1 damage boost
        }
    }

    /**
     * @dev Apply crew bonuses to damage (Gunner crew increases damage)
     * @param gameId Game ID
     * @param player Player address
     * @param baseDamage Base damage amount
     * @param isDefaultAttack Whether this affects default attacks
     * @return boostedDamage Damage with crew bonuses applied
     */
    function _applyCrewBonuses(
        uint256 gameId,
        address player,
        uint8 baseDamage,
        bool isDefaultAttack
    ) internal view returns (uint8 boostedDamage) {
        boostedDamage = baseDamage;
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        if (address(captainAndCrewNFTManager) == address(0) || address(gameConfig) == address(0)) {
            return boostedDamage; // Contracts not set
        }
        
        // Check each crew member and apply bonuses
        uint8 gunnerCount = 0;
        for (uint256 i = 0; i < fleet.crewIds.length; i++) {
            if (fleet.crewIds[i] == 0) continue;
            
            ICaptainAndCrewNFTManager.CrewInfo memory crewInfo = captainAndCrewNFTManager.getCrewInfo(fleet.crewIds[i]);
            
            // Check if crew type affects default attacks (from GameConfig)
            if (isDefaultAttack && !gameConfig.getCrewDefaultAttackToggle(crewInfo.crewType)) {
                continue; // This crew type doesn't affect default attacks
            }
            
            if (crewInfo.crewType == ICaptainAndCrewNFTManager.CrewType.GUNNER) {
                gunnerCount++;
            }
        }
        
        // Each Gunner crew adds +1 damage
        boostedDamage += gunnerCount;
    }

    /**
     * @dev Find which ship occupies a specific cell
     * @param gameId Game ID
     * @param player Player address
     * @param cellIndex Cell to check
     * @return shipIndex Index of ship at cell (255 if none)
     */
    function _findShipAtCell(
        uint256 gameId,
        address player,
        uint8 cellIndex
    ) internal view returns (uint8 shipIndex) {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        
        for (uint8 i = 0; i < 5; i++) {
            uint8 position = fleet.shipPositions[i];
            ShipRotation rotation = fleet.shipRotations[i];
            uint8 size = shipSizes[i];
            
            uint8[] memory shipCells = _getShipCells(position, rotation, size);
            
            for (uint8 j = 0; j < shipCells.length; j++) {
                if (shipCells[j] == cellIndex) {
                    return i;
                }
            }
        }
        
        return 255; // Not found
    }

    /**
     * @dev Apply damage to a ship and check if it's destroyed
     * @param gameId Game ID
     * @param player Player address
     * @param shipIndex Ship index
     * @param damage Damage amount
     * @param hitCell Cell that was hit
     */
    function _damageShip(
        uint256 gameId,
        address player,
        uint8 shipIndex,
        uint8 damage,
        uint8 hitCell
    ) internal {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        // Reduce ship health
        uint8 currentHealth = fleet.shipHealth[shipIndex];
        if (currentHealth > damage) {
            fleet.shipHealth[shipIndex] = currentHealth - damage;
        } else {
            fleet.shipHealth[shipIndex] = 0;
            
            // Ship is destroyed - mark all cells as sunk
            _markShipAsSunk(gameId, player, shipIndex);
            
            emit ShipDestroyed(gameId, player, fleet.shipIds[shipIndex]);
        }
    }

    /**
     * @dev Mark all cells of a destroyed ship as sunk
     * @param gameId Game ID
     * @param player Player address
     * @param shipIndex Ship index
     */
    function _markShipAsSunk(uint256 gameId, address player, uint8 shipIndex) internal {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        GridState storage grid = playerGrids[gameId][player];
        
        uint8 position = fleet.shipPositions[shipIndex];
        ShipRotation rotation = fleet.shipRotations[shipIndex];
        uint8[5] memory shipSizes = [2, 3, 3, 4, 5];
        uint8 size = shipSizes[shipIndex];
        
        uint8[] memory shipCells = _getShipCells(position, rotation, size);
        
        for (uint8 i = 0; i < shipCells.length; i++) {
            setCellState(grid, shipCells[i], CellState.SUNK);
        }
    }



    /**
     * @dev Check if game has ended (all ships of one player destroyed)
     * @param gameId Game ID
     * @return hasEnded True if game should end
     */
    function _checkGameEnd(uint256 gameId) internal view returns (bool hasEnded) {
        GameInfo memory game = games[gameId];
        
        // Check if all ships of player1 are destroyed
        bool player1Defeated = _areAllShipsDestroyed(gameId, game.player1);
        
        // Check if all ships of player2 are destroyed
        bool player2Defeated = _areAllShipsDestroyed(gameId, game.player2);
        
        return player1Defeated || player2Defeated;
    }

    /**
     * @dev Check if all ships of a player are destroyed
     * @param gameId Game ID
     * @param player Player address
     * @return allDestroyed True if all ships are destroyed
     */
    function _areAllShipsDestroyed(uint256 gameId, address player) internal view returns (bool allDestroyed) {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        for (uint8 i = 0; i < 5; i++) {
            if (fleet.shipHealth[i] > 0) {
                return false;
            }
        }
        
        return true;
    }

    // =============================================================================
    // SECTION 3.6: GAME COMPLETION AND REWARDS
    // =============================================================================

    /**
     * @dev Function1: Win condition detection
     * End the game and determine winner/loser
     * @param gameId Game ID
     */
    function _endGame(uint256 gameId) internal {
        GameInfo storage game = games[gameId];
        GameState storage state = gameStates[gameId];
        
        require(game.status == GameStatus.ACTIVE, "BattleshipGame: Game not active");
        
        // Determine winner and loser
        bool player1Defeated = _areAllShipsDestroyed(gameId, game.player1);
        bool player2Defeated = _areAllShipsDestroyed(gameId, game.player2);
        
        address winner;
        address loser;
        
        if (player1Defeated && !player2Defeated) {
            winner = game.player2;
            loser = game.player1;
        } else if (player2Defeated && !player1Defeated) {
            winner = game.player1;
            loser = game.player2;
        } else {
            // Should not happen, but handle edge case
            revert("BattleshipGame: Invalid game end state");
        }
        
        // Update game status
        game.status = GameStatus.COMPLETED;
        
        // Process rental ships for both players
        _processRentalShips(gameId, winner);
        _processRentalShips(gameId, loser);
        
        // Distribute credits
        _distributeCredits(gameId, winner, loser);
        
        // Handle ship destruction chance
        _handleShipDestruction(gameId, loser);
        
        // Distribute prize money
        _distributePrizeMoney(gameId, winner);
        
        emit GameCompleted(gameId, winner, loser);
    }

    /**
     * @dev Function2: Credit calculation and distribution
     * Award credits to players based on game outcome
     * @param gameId Game ID
     * @param winner Winner address
     * @param loser Loser address
     */
    function _distributeCredits(uint256 gameId, address winner, address loser) internal {
        GameInfo memory game = games[gameId];
        
        // Get credit amounts from GameConfig
        uint256 winnerCredits;
        uint256 loserCredits;
        
        if (address(gameConfig) != address(0)) {
            (winnerCredits, loserCredits) = gameConfig.getCreditsByGameSize(game.size);
        } else {
            // Default credit distribution by game size
            if (game.size == GameSize.SHRIMP) {
                winnerCredits = 1;
                loserCredits = 0;
            } else if (game.size == GameSize.FISH) {
                winnerCredits = 4;
                loserCredits = 2;
            } else if (game.size == GameSize.SHARK) {
                winnerCredits = 7;
                loserCredits = 3;
            } else if (game.size == GameSize.WHALE) {
                winnerCredits = 30;
                loserCredits = 15;
            }
        }
        
        // Award credits via TokenomicsCore
        if (address(tokenomicsCore) != address(0)) {
            tokenomicsCore.awardCredits(winner, winnerCredits);
            if (loserCredits > 0) {
                tokenomicsCore.awardCredits(loser, loserCredits);
            }
        }
        
        // For now, emit events for tracking
        emit CreditsAwarded(gameId, winner, winnerCredits);
        emit CreditsAwarded(gameId, loser, loserCredits);
    }

    /**
     * @dev Process rental ships after game completion
     * @param gameId Game ID
     * @param player Player address
     */
    function _processRentalShips(uint256 gameId, address player) internal {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        for (uint256 i = 0; i < 5; i++) {
            uint256 shipId = fleet.shipIds[i];
            // Check if ship is a rental through ShipNFTManager
            if (address(shipNFTManager) != address(0)) {
                // Use rental game (this decrements games remaining for rental ships)
                shipNFTManager.useRentalGame(shipId);
            }
        }
    }

    /**
     * @dev Function3: Ship destruction probability (10%)
     * Handle potential ship destruction for losing player
     * @param gameId Game ID
     * @param loser Losing player address
     */
    function _handleShipDestruction(uint256 gameId, address loser) internal {
        // Get destruction chance from GameConfig
        uint256 destructionChance = 10; // 10% default
        if (address(gameConfig) != address(0)) {
            destructionChance = gameConfig.getShipDestructionChance();
        }
        
        // Generate pseudo-random number for destruction check
        uint256 randomValue = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            gameId,
            loser
        ))) % 100;
        
        if (randomValue < destructionChance) {
            // Destroy one ship - select random ship that was used in game
            PlayerFleet storage fleet = playerFleets[gameId][loser];
            uint256 randomShipIndex = randomValue % 5; // Select random ship (0-4)
            uint256 shipToDestroy = fleet.shipIds[randomShipIndex];
            
            // Destroy ship via ShipNFTManager
            if (address(shipNFTManager) != address(0)) {
                shipNFTManager.destroyShip(shipToDestroy);
            }
            
            emit ShipDestroyed(gameId, loser, shipToDestroy);
        }
    }

    /**
     * @dev Function4: Game cleanup and state reset
     * Distribute prize money to winner
     * @param gameId Game ID
     * @param winner Winner address
     */
    function _distributePrizeMoney(uint256 gameId, address winner) internal {
        GameState storage state = gameStates[gameId];
        
        require(!state.feesDistributed, "BattleshipGame: Fees already distributed");
        require(state.totalPot > 0, "BattleshipGame: No prize money to distribute");
        
        uint256 totalPot = state.totalPot;
        
        // Calculate fee for protocol (5% default)
        // Get fee percentage from GameConfig
        uint256 feePercentage = 5; // 5% default
        if (address(gameConfig) != address(0)) {
            feePercentage = gameConfig.getGameFeePercentage();
        }
        uint256 protocolFee = (totalPot * feePercentage) / 100;
        uint256 winnerPrize = totalPot - protocolFee;
        
        // Transfer prize to winner
        payable(winner).transfer(winnerPrize);
        
        // Send protocol fee to TokenomicsCore
        if (address(tokenomicsCore) != address(0) && protocolFee > 0) {
            tokenomicsCore.recordGameRevenue{value: protocolFee}(protocolFee);
        }
        
        state.feesDistributed = true;
        
        emit PrizeDistributed(gameId, winner, winnerPrize, protocolFee);
    }

    /**
     * @dev Manual game cancellation (emergency function)
     * @param gameId Game ID
     * @param reason Reason for cancellation
     */
    function cancelGame(uint256 gameId, string calldata reason) 
        external 
        onlyOwner 
        gameExists(gameId) 
    {
        GameInfo storage game = games[gameId];
        require(
            game.status == GameStatus.WAITING || game.status == GameStatus.ACTIVE,
            "BattleshipGame: Game cannot be cancelled"
        );
        
        game.status = GameStatus.CANCELLED;
        
        // Refund entry fees
        _refundPlayers(gameId);
        
        emit GameCancelled(gameId, reason);
    }

    /**
     * @dev Refund entry fees to players
     * @param gameId Game ID
     */
    function _refundPlayers(uint256 gameId) internal {
        GameInfo memory game = games[gameId];
        GameState storage state = gameStates[gameId];
        
        if (!state.feesDistributed && state.totalPot > 0) {
            uint256 refundAmount = game.entryFee;
            
            // Refund player 1
            if (game.player1 != address(0)) {
                payable(game.player1).transfer(refundAmount);
            }
            
            // Refund player 2 if they joined
            if (game.player2 != address(0)) {
                payable(game.player2).transfer(refundAmount);
            }
            
            state.feesDistributed = true;
        }
    }

    /**
     * @dev Get game statistics for frontend
     * @param gameId Game ID
     * @return stats Game statistics struct
     */
    function getGameStats(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        returns (
            uint8 totalTurns,
            uint8 player1ShipsRemaining,
            uint8 player2ShipsRemaining,
            uint8 player1CellsRevealed,
            uint8 player2CellsRevealed,
            uint256 gameStartTime,
            uint256 lastMoveTime,
            bool isCompleted
        ) 
    {
        GameInfo memory game = games[gameId];
        GameState memory state = gameStates[gameId];
        
        totalTurns = state.totalTurns;
        gameStartTime = game.startTime;
        lastMoveTime = game.lastMoveTime;
        isCompleted = game.status == GameStatus.COMPLETED;
        
        // Count remaining ships
        player1ShipsRemaining = _countRemainingShips(gameId, game.player1);
        player2ShipsRemaining = _countRemainingShips(gameId, game.player2);
        
        // Get revealed cells count
        player1CellsRevealed = visibilityStates[gameId][game.player1].totalRevealed;
        player2CellsRevealed = visibilityStates[gameId][game.player2].totalRevealed;
    }

    /**
     * @dev Count remaining ships for a player
     * @param gameId Game ID
     * @param player Player address
     * @return remaining Number of ships still alive
     */
    function _countRemainingShips(uint256 gameId, address player) internal view returns (uint8 remaining) {
        PlayerFleet storage fleet = playerFleets[gameId][player];
        
        for (uint8 i = 0; i < 5; i++) {
            if (fleet.shipHealth[i] > 0) {
                remaining++;
            }
        }
    }

    /**
     * @dev Emergency function to end stuck games
     * @param gameId Game ID
     */
    function forceEndGame(uint256 gameId) 
        external 
        onlyOwner 
        gameExists(gameId) 
        gameInStatus(gameId, GameStatus.ACTIVE) 
    {
        // Force end game with no winner (refund both players)
        GameInfo storage game = games[gameId];
        game.status = GameStatus.CANCELLED;
        
        _refundPlayers(gameId);
        
        emit GameCancelled(gameId, "Force ended by admin");
    }

    // =============================================================================
    // ADDITIONAL EVENTS FOR GAME COMPLETION
    // =============================================================================
    
    event CreditsAwarded(uint256 indexed gameId, address indexed player, uint256 amount);
    event PrizeDistributed(uint256 indexed gameId, address indexed winner, uint256 winnerAmount, uint256 protocolFee);
    event GameCancelled(uint256 indexed gameId, string reason);
    
    // =============================================================================
    // VIEW FUNCTIONS FOR FRONTEND INTEGRATION
    // =============================================================================
    
    /**
     * @dev Get comprehensive game state for frontend
     * @param gameId Game ID
     * @return Complete game state information
     */
    function getCompleteGameState(uint256 gameId) 
        external 
        view 
        gameExists(gameId) 
        returns (
            GameInfo memory gameInfo,
            GameState memory gameState,
            uint8 player1ShipsAlive,
            uint8 player2ShipsAlive
        ) 
    {
        gameInfo = games[gameId];
        gameState = gameStates[gameId];
        player1ShipsAlive = _countRemainingShips(gameId, gameInfo.player1);
        player2ShipsAlive = _countRemainingShips(gameId, gameInfo.player2);
    }

    /**
     * @dev Check if a player can perform any actions
     * @param gameId Game ID
     * @param player Player address
     * @return canAct True if player can perform actions
     */
    function canPlayerAct(uint256 gameId, address player) 
        external 
        view 
        gameExists(gameId) 
        returns (bool canAct) 
    {
        GameInfo memory game = games[gameId];
        
        return (
            game.status == GameStatus.ACTIVE &&
            game.currentTurn == player &&
            this.hasActionsRemaining(gameId, player)
        );
    }
} 