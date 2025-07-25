// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GameState
 * @dev Manages all game state storage and basic state operations for CryptoBattleship
 */
contract GameState is Ownable {
    // =============================================================================
    // ENUMS AND STRUCTS
    // =============================================================================

    enum GameStatus { WAITING, ACTIVE, COMPLETED, CANCELLED }
    enum GameSize { SHRIMP, FISH, SHARK, WHALE }
    enum CellState { EMPTY, SHIP, HIT, MISS, SUNK }
    enum ShipRotation { NORTH, EAST, SOUTH, WEST }

    struct GameInfo {
        address player1;
        address player2;
        GameSize gameSize;
        uint256 ante;
        uint256 startTime;
        GameStatus status;
        address winner;
        uint256 endTime;
        uint8 currentPlayer;
        uint256 lastMoveTime;
        uint8 player1SkippedTurns;
        uint8 player2SkippedTurns;
        bool gameEnded;
    }

    struct GameStateData {
        uint256 player1ShipsRemaining;
        uint256 player2ShipsRemaining;
        uint256 player1Score;
        uint256 player2Score;
        uint256 player1ActionsUsed;
        uint256 player2ActionsUsed;
        uint256 player1LastActionTime;
        uint256 player2LastActionTime;
        bool player1GridRevealed;
        bool player2GridRevealed;
    }

    struct PlayerFleet {
        uint256 shipId;
        uint256[] actionIds;
        uint256 captainId;
        uint256[] crewIds;
        bool shipsPlaced;
        uint8 shipsRemaining;
    }

    struct GridState {
        uint256[25] packedGrid; // 100 cells packed into 25 uint256s (4 bits per cell)
        mapping(uint8 => ShipData) ships;
        uint8 totalShips;
    }

    struct ShipData {
        uint8 shipType; // 0=destroyer, 1=submarine, 2=cruiser, 3=battleship, 4=carrier
        uint8 health;
        uint8 maxHealth;
        uint8 x;
        uint8 y;
        ShipRotation rotation;
        bool isDestroyed;
    }

    struct VisibilityState {
        uint256[25] packedVisibility; // Visible cells packed
        uint8 totalCellsRevealed;
        uint8 accurateShotsLanded;
        uint8 totalShotsFired;
        uint8 shipsSpotted;
    }

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    uint256 public nextGameId = 1;
    uint8 public constant GRID_SIZE = 10;
    
    // Core storage mappings
    mapping(uint256 => GameInfo) public games;
    mapping(uint256 => GameStateData) public gameStates;
    mapping(uint256 => mapping(address => PlayerFleet)) public playerFleets;
    mapping(uint256 => mapping(address => GridState)) public playerGrids;
    mapping(uint256 => mapping(address => GridState)) public visibilityGrids;
    mapping(uint256 => mapping(address => VisibilityState)) public visibilityStates;

    // Authorized contracts
    mapping(address => bool) public authorizedContracts;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event GameCreated(uint256 indexed gameId, address indexed player1, GameSize gameSize, uint256 ante);
    event GameJoined(uint256 indexed gameId, address indexed player2);
    event GameStarted(uint256 indexed gameId, address indexed player1, address indexed player2);
    event ShipsPlaced(uint256 indexed gameId, address indexed player);
    event CellStateChanged(uint256 indexed gameId, address indexed player, uint8 x, uint8 y, CellState newState);
    event GameStateUpdated(uint256 indexed gameId, uint8 currentPlayer, uint256 timestamp);

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner(), "GameState: Not authorized");
        _;
    }

    modifier validGameId(uint256 gameId) {
        require(gameId > 0 && gameId < nextGameId, "GameState: Invalid game ID");
        _;
    }

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _initialAdmin) Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "GameState: Invalid admin address");
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    function setAuthorizedContract(address contractAddr, bool authorized) external onlyOwner {
        require(contractAddr != address(0), "GameState: Invalid contract address");
        authorizedContracts[contractAddr] = authorized;
    }

    // =============================================================================
    // GAME LIFECYCLE FUNCTIONS
    // =============================================================================

    function createGame(
        address player1,
        GameSize gameSize,
        uint256 ante
    ) external onlyAuthorized returns (uint256 gameId) {
        gameId = nextGameId++;
        
        games[gameId] = GameInfo({
            player1: player1,
            player2: address(0),
            gameSize: gameSize,
            ante: ante,
            startTime: 0,
            status: GameStatus.WAITING,
            winner: address(0),
            endTime: 0,
            currentPlayer: 1,
            lastMoveTime: 0,
            player1SkippedTurns: 0,
            player2SkippedTurns: 0,
            gameEnded: false
        });

        gameStates[gameId] = GameStateData({
            player1ShipsRemaining: 0,
            player2ShipsRemaining: 0,
            player1Score: 0,
            player2Score: 0,
            player1ActionsUsed: 0,
            player2ActionsUsed: 0,
            player1LastActionTime: 0,
            player2LastActionTime: 0,
            player1GridRevealed: false,
            player2GridRevealed: false
        });

        emit GameCreated(gameId, player1, gameSize, ante);
        return gameId;
    }

    function joinGame(uint256 gameId, address player2) external onlyAuthorized validGameId(gameId) {
        require(games[gameId].status == GameStatus.WAITING, "GameState: Game not waiting for players");
        require(games[gameId].player2 == address(0), "GameState: Game already full");
        require(games[gameId].player1 != player2, "GameState: Cannot join own game");

        games[gameId].player2 = player2;
        emit GameJoined(gameId, player2);
    }

    function startGame(uint256 gameId) external onlyAuthorized validGameId(gameId) {
        require(games[gameId].status == GameStatus.WAITING, "GameState: Game not ready to start");
        require(games[gameId].player2 != address(0), "GameState: Game needs two players");
        
        games[gameId].status = GameStatus.ACTIVE;
        games[gameId].startTime = block.timestamp;
        games[gameId].lastMoveTime = block.timestamp;

        emit GameStarted(gameId, games[gameId].player1, games[gameId].player2);
    }

    function endGame(uint256 gameId, address winner) external onlyAuthorized validGameId(gameId) {
        require(games[gameId].status == GameStatus.ACTIVE, "GameState: Game not active");
        
        games[gameId].status = GameStatus.COMPLETED;
        games[gameId].winner = winner;
        games[gameId].endTime = block.timestamp;
        games[gameId].gameEnded = true;
    }

    function cancelGame(uint256 gameId) external onlyAuthorized validGameId(gameId) {
        require(games[gameId].status == GameStatus.WAITING, "GameState: Can only cancel waiting games");
        
        games[gameId].status = GameStatus.CANCELLED;
        games[gameId].endTime = block.timestamp;
    }

    // =============================================================================
    // FLEET MANAGEMENT FUNCTIONS
    // =============================================================================

    function setPlayerFleet(
        uint256 gameId,
        address player,
        uint256 shipId,
        uint256[] calldata actionIds,
        uint256 captainId,
        uint256[] calldata crewIds
    ) external onlyAuthorized validGameId(gameId) {
        playerFleets[gameId][player] = PlayerFleet({
            shipId: shipId,
            actionIds: actionIds,
            captainId: captainId,
            crewIds: crewIds,
            shipsPlaced: false,
            shipsRemaining: 5 // Standard fleet: destroyer, submarine, cruiser, battleship, carrier
        });
    }

    function setShipsPlaced(uint256 gameId, address player, bool placed) external onlyAuthorized validGameId(gameId) {
        playerFleets[gameId][player].shipsPlaced = placed;
        if (placed) {
            emit ShipsPlaced(gameId, player);
        }
    }

    // =============================================================================
    // GRID STATE FUNCTIONS
    // =============================================================================

    function getCellState(uint256 gameId, address player, uint8 x, uint8 y) 
        external view validGameId(gameId) returns (CellState) 
    {
        require(x < GRID_SIZE && y < GRID_SIZE, "GameState: Invalid coordinates");
        
        uint8 index = y * GRID_SIZE + x;
        uint256 packedIndex = index / 64; // 64 cells per uint256 (4 bits each, 256/4=64)
        uint256 cellIndex = index % 64;
        
        uint256 packedValue = playerGrids[gameId][player].packedGrid[packedIndex];
        uint256 cellValue = (packedValue >> (cellIndex * 4)) & 0xF;
        
        return CellState(cellValue);
    }

    function setCellState(uint256 gameId, address player, uint8 x, uint8 y, CellState state) 
        external onlyAuthorized validGameId(gameId) 
    {
        require(x < GRID_SIZE && y < GRID_SIZE, "GameState: Invalid coordinates");
        
        uint8 index = y * GRID_SIZE + x;
        uint256 packedIndex = index / 64;
        uint256 cellIndex = index % 64;
        
        uint256 packedValue = playerGrids[gameId][player].packedGrid[packedIndex];
        
        // Clear the 4 bits for this cell
        uint256 mask = ~(0xF << (cellIndex * 4));
        packedValue &= mask;
        
        // Set the new value
        packedValue |= (uint256(state) << (cellIndex * 4));
        playerGrids[gameId][player].packedGrid[packedIndex] = packedValue;
        
        emit CellStateChanged(gameId, player, x, y, state);
    }

    function setShipData(
        uint256 gameId,
        address player,
        uint8 shipIndex,
        uint8 shipType,
        uint8 health,
        uint8 maxHealth,
        uint8 x,
        uint8 y,
        ShipRotation rotation
    ) external onlyAuthorized validGameId(gameId) {
        playerGrids[gameId][player].ships[shipIndex] = ShipData({
            shipType: shipType,
            health: health,
            maxHealth: maxHealth,
            x: x,
            y: y,
            rotation: rotation,
            isDestroyed: false
        });
    }

    function damageShip(uint256 gameId, address player, uint8 shipIndex, uint8 damage) 
        external onlyAuthorized validGameId(gameId) returns (bool destroyed)
    {
        ShipData storage ship = playerGrids[gameId][player].ships[shipIndex];
        require(!ship.isDestroyed, "GameState: Ship already destroyed");
        
        if (ship.health <= damage) {
            ship.health = 0;
            ship.isDestroyed = true;
            playerFleets[gameId][player].shipsRemaining--;
            destroyed = true;
        } else {
            ship.health -= damage;
            destroyed = false;
        }
    }

    // =============================================================================
    // GAME STATE UPDATE FUNCTIONS
    // =============================================================================

    function updateCurrentPlayer(uint256 gameId, uint8 newPlayer) external onlyAuthorized validGameId(gameId) {
        games[gameId].currentPlayer = newPlayer;
        games[gameId].lastMoveTime = block.timestamp;
        emit GameStateUpdated(gameId, newPlayer, block.timestamp);
    }

    function incrementSkippedTurns(uint256 gameId, address player) external onlyAuthorized validGameId(gameId) {
        if (player == games[gameId].player1) {
            games[gameId].player1SkippedTurns++;
        } else {
            games[gameId].player2SkippedTurns++;
        }
    }

    function updateScore(uint256 gameId, address player, uint256 points) external onlyAuthorized validGameId(gameId) {
        if (player == games[gameId].player1) {
            gameStates[gameId].player1Score += points;
        } else {
            gameStates[gameId].player2Score += points;
        }
    }

    function incrementActionsUsed(uint256 gameId, address player) external onlyAuthorized validGameId(gameId) {
        if (player == games[gameId].player1) {
            gameStates[gameId].player1ActionsUsed++;
            gameStates[gameId].player1LastActionTime = block.timestamp;
        } else {
            gameStates[gameId].player2ActionsUsed++;
            gameStates[gameId].player2LastActionTime = block.timestamp;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getGameInfo(uint256 gameId) external view validGameId(gameId) returns (GameInfo memory) {
        return games[gameId];
    }

    function getGameStateData(uint256 gameId) external view validGameId(gameId) returns (GameStateData memory) {
        return gameStates[gameId];
    }

    function getPlayerFleet(uint256 gameId, address player) external view validGameId(gameId) returns (PlayerFleet memory) {
        return playerFleets[gameId][player];
    }

    function getShipData(uint256 gameId, address player, uint8 shipIndex) 
        external view validGameId(gameId) returns (ShipData memory) 
    {
        return playerGrids[gameId][player].ships[shipIndex];
    }

    function isGameActive(uint256 gameId) external view validGameId(gameId) returns (bool) {
        return games[gameId].status == GameStatus.ACTIVE;
    }

    function getOpponent(uint256 gameId, address player) external view validGameId(gameId) returns (address) {
        if (games[gameId].player1 == player) {
            return games[gameId].player2;
        } else if (games[gameId].player2 == player) {
            return games[gameId].player1;
        } else {
            revert("GameState: Player not in game");
        }
    }

    function coordsToIndex(uint8 x, uint8 y) external pure returns (uint8) {
        return y * GRID_SIZE + x;
    }

    function indexToCoords(uint8 index) external pure returns (uint8 x, uint8 y) {
        x = index % GRID_SIZE;
        y = index / GRID_SIZE;
    }
}