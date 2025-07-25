// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameState.sol";

// =============================================================================
// INTERFACES
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
    
    function getShipStats(ShipType shipType) external view returns (ShipStats memory);
    function getDefaultAttackDamage() external view returns (uint8);
    function getTurnTimer() external view returns (uint256);
}

interface ICaptainNFTManager {
    enum CaptainAbility { DAMAGE_BOOST, SPEED_BOOST, DEFENSE_BOOST, VISION_BOOST, LUCK_BOOST }
    
    struct CaptainInfo {
        string name;
        CaptainAbility ability;
        uint8 abilityPower;
        uint256 experience;
        uint8 leadership;
        uint8 tactics;
        uint8 morale;
    }
    
    function getCaptainInfo(uint256 tokenId) external view returns (CaptainInfo memory);
}

interface ICrewNFTManager {
    enum CrewType { GUNNER, ENGINEER, NAVIGATOR, MEDIC }
    
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
    
    function getCrewInfo(uint256 tokenId) external view returns (CrewInfo memory);
    function canUseCrew(uint256 tokenId) external view returns (bool canUse, uint8 currentStamina);
    function useCrewStamina(uint256 tokenId, address user) external;
}

/**
 * @title GameLogic
 * @dev Handles all game mechanics, validation, and combat calculations for CryptoBattleship
 */
contract GameLogic is Ownable {
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    GameState public gameState;
    IGameConfig public gameConfig;
    ICaptainNFTManager public captainNFTManager;
    ICrewNFTManager public crewNFTManager;

    // Ship size constants
    uint8 constant DESTROYER_SIZE = 2;
    uint8 constant SUBMARINE_SIZE = 3;
    uint8 constant CRUISER_SIZE = 3;
    uint8 constant BATTLESHIP_SIZE = 4;
    uint8 constant CARRIER_SIZE = 5;

    // Grid constants
    uint8 constant GRID_SIZE = 10;
    uint8 constant MAX_ACTIONS_PER_TURN = 3;

    // Authorized contracts
    mapping(address => bool) public authorizedContracts;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event AttackExecuted(uint256 indexed gameId, address indexed attacker, uint8 x, uint8 y, bool hit, uint8 damage);
    event ShipDestroyed(uint256 indexed gameId, address indexed player, uint8 shipIndex);
    event CaptainAbilityUsed(uint256 indexed gameId, address indexed player, uint256 captainId);
    event CrewAbilityUsed(uint256 indexed gameId, address indexed player, uint256 crewId);

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner(), "GameLogic: Not authorized");
        _;
    }

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(
        address _initialAdmin,
        address _gameState,
        address _gameConfig,
        address _captainNFTManager,
        address _crewNFTManager
    ) Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "GameLogic: Invalid admin");
        require(_gameState != address(0), "GameLogic: Invalid GameState");
        require(_gameConfig != address(0), "GameLogic: Invalid GameConfig");
        require(_captainNFTManager != address(0), "GameLogic: Invalid CaptainNFTManager");
        require(_crewNFTManager != address(0), "GameLogic: Invalid CrewNFTManager");

        gameState = GameState(_gameState);
        gameConfig = IGameConfig(_gameConfig);
        captainNFTManager = ICaptainNFTManager(_captainNFTManager);
        crewNFTManager = ICrewNFTManager(_crewNFTManager);
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    function setAuthorizedContract(address contractAddr, bool authorized) external onlyOwner {
        require(contractAddr != address(0), "GameLogic: Invalid contract address");
        authorizedContracts[contractAddr] = authorized;
    }

    function updateContracts(
        address _gameConfig,
        address _captainNFTManager,
        address _crewNFTManager
    ) external onlyOwner {
        if (_gameConfig != address(0)) gameConfig = IGameConfig(_gameConfig);
        if (_captainNFTManager != address(0)) captainNFTManager = ICaptainNFTManager(_captainNFTManager);
        if (_crewNFTManager != address(0)) crewNFTManager = ICrewNFTManager(_crewNFTManager);
    }

    // =============================================================================
    // SHIP PLACEMENT VALIDATION
    // =============================================================================

    function validateShipPlacement(
        uint256 gameId,
        address player,
        uint8[5] calldata shipTypes,
        uint8[5] calldata xPositions,
        uint8[5] calldata yPositions,
        GameState.ShipRotation[5] calldata rotations
    ) external onlyAuthorized returns (bool valid) {
        // Check that all ships can be placed without overlap
        bool[100] memory occupiedCells;
        
        for (uint8 i = 0; i < 5; i++) {
            uint8 shipSize = getShipSize(shipTypes[i]);
            uint8[] memory shipCells = calculateShipCells(xPositions[i], yPositions[i], shipSize, rotations[i]);
            
            // Check each cell of this ship
            for (uint8 j = 0; j < shipCells.length; j++) {
                if (occupiedCells[shipCells[j]]) {
                    return false; // Overlap detected
                }
                occupiedCells[shipCells[j]] = true;
            }
            
            // Place ship data in GameState
            IGameConfig.ShipStats memory stats = gameConfig.getShipStats(IGameConfig.ShipType(shipTypes[i]));
            gameState.setShipData(
                gameId,
                player,
                i,
                shipTypes[i],
                stats.health,
                stats.health,
                xPositions[i],
                yPositions[i],
                rotations[i]
            );
            
            // Mark ship cells in grid
            for (uint8 k = 0; k < shipCells.length; k++) {
                (uint8 x, uint8 y) = gameState.indexToCoords(uint8(shipCells[k]));
                gameState.setCellState(gameId, player, x, y, GameState.CellState.SHIP);
            }
        }
        
        return true;
    }

    function getShipSize(uint8 shipType) public pure returns (uint8) {
        if (shipType == 0) return DESTROYER_SIZE;
        if (shipType == 1) return SUBMARINE_SIZE;
        if (shipType == 2) return CRUISER_SIZE;
        if (shipType == 3) return BATTLESHIP_SIZE;
        if (shipType == 4) return CARRIER_SIZE;
        revert("GameLogic: Invalid ship type");
    }

    function calculateShipCells(
        uint8 x,
        uint8 y,
        uint8 size,
        GameState.ShipRotation rotation
    ) public pure returns (uint8[] memory cells) {
        cells = new uint8[](size);
        
        for (uint8 i = 0; i < size; i++) {
            uint8 cellX = x;
            uint8 cellY = y;
            
            if (rotation == GameState.ShipRotation.NORTH) {
                cellY = y - i;
            } else if (rotation == GameState.ShipRotation.EAST) {
                cellX = x + i;
            } else if (rotation == GameState.ShipRotation.SOUTH) {
                cellY = y + i;
            } else if (rotation == GameState.ShipRotation.WEST) {
                cellX = x - i;
            }
            
            require(cellX < GRID_SIZE && cellY < GRID_SIZE, "GameLogic: Ship extends outside grid");
            cells[i] = cellY * GRID_SIZE + cellX;
        }
    }

    // =============================================================================
    // COMBAT SYSTEM
    // =============================================================================

    function executeAttack(
        uint256 gameId,
        address attacker,
        uint8 targetX,
        uint8 targetY,
        bool useCaptainAbility,
        uint256[] calldata crewIds
    ) external onlyAuthorized returns (bool hit, uint8 damage, bool shipDestroyed) {
        require(targetX < GRID_SIZE && targetY < GRID_SIZE, "GameLogic: Invalid target coordinates");
        
        address opponent = gameState.getOpponent(gameId, attacker);
        GameState.CellState currentState = gameState.getCellState(gameId, opponent, targetX, targetY);
        
        // Calculate base damage
        damage = gameConfig.getDefaultAttackDamage();
        
        // Apply captain bonuses
        if (useCaptainAbility) {
            damage += applyCaptainBonus(gameId, attacker, damage);
        }
        
        // Apply crew bonuses
        damage += applyCrewBonuses(gameId, attacker, crewIds, damage);
        
        // Check for hit
        if (currentState == GameState.CellState.SHIP) {
            hit = true;
            gameState.setCellState(gameId, opponent, targetX, targetY, GameState.CellState.HIT);
            
            // Find and damage the ship
            uint8 shipIndex = findShipAtCell(gameId, opponent, targetX, targetY);
            if (shipIndex < 5) {
                shipDestroyed = gameState.damageShip(gameId, opponent, shipIndex, damage);
                
                if (shipDestroyed) {
                    markShipAsSunk(gameId, opponent, shipIndex);
                    emit ShipDestroyed(gameId, opponent, shipIndex);
                }
            }
            
            // Update score
            gameState.updateScore(gameId, attacker, damage);
        } else {
            hit = false;
            gameState.setCellState(gameId, opponent, targetX, targetY, GameState.CellState.MISS);
        }
        
        emit AttackExecuted(gameId, attacker, targetX, targetY, hit, damage);
        return (hit, damage, shipDestroyed);
    }

    function applyCaptainBonus(uint256 gameId, address player, uint8 baseDamage) 
        internal returns (uint8 bonus) 
    {
        GameState.PlayerFleet memory fleet = gameState.getPlayerFleet(gameId, player);
        if (fleet.captainId == 0) return 0;
        
        ICaptainNFTManager.CaptainInfo memory captain = captainNFTManager.getCaptainInfo(fleet.captainId);
        
        if (captain.ability == ICaptainNFTManager.CaptainAbility.DAMAGE_BOOST) {
            bonus = (baseDamage * captain.abilityPower) / 100;
        } else if (captain.ability == ICaptainNFTManager.CaptainAbility.LUCK_BOOST) {
            bonus = captain.abilityPower / 10; // Flat bonus for luck
        }
        
        emit CaptainAbilityUsed(gameId, player, fleet.captainId);
        return bonus;
    }

    function applyCrewBonuses(
        uint256 gameId,
        address player,
        uint256[] calldata crewIds,
        uint8 baseDamage
    ) internal returns (uint8 totalBonus) {
        for (uint8 i = 0; i < crewIds.length && i < 3; i++) { // Max 3 crew per attack
            (bool canUse,) = crewNFTManager.canUseCrew(crewIds[i]);
            if (!canUse) continue;
            
            ICrewNFTManager.CrewInfo memory crew = crewNFTManager.getCrewInfo(crewIds[i]);
            
            if (crew.crewType == ICrewNFTManager.CrewType.GUNNER) {
                totalBonus += crew.skillLevel / 2; // Damage bonus
            } else if (crew.crewType == ICrewNFTManager.CrewType.ENGINEER) {
                totalBonus += crew.efficiency / 10; // Efficiency bonus
            }
            
            // Use crew stamina
            crewNFTManager.useCrewStamina(crewIds[i], player);
            emit CrewAbilityUsed(gameId, player, crewIds[i]);
        }
        
        return totalBonus;
    }

    function findShipAtCell(uint256 gameId, address player, uint8 x, uint8 y) 
        internal view returns (uint8 shipIndex) 
    {
        uint8 targetIndex = gameState.coordsToIndex(x, y);
        
        // Check each ship to see if it occupies this cell
        for (uint8 i = 0; i < 5; i++) {
            GameState.ShipData memory ship = gameState.getShipData(gameId, player, i);
            if (ship.isDestroyed) continue;
            
            uint8 shipSize = getShipSize(ship.shipType);
            uint8[] memory shipCells = calculateShipCells(ship.x, ship.y, shipSize, ship.rotation);
            
            for (uint8 j = 0; j < shipCells.length; j++) {
                if (shipCells[j] == targetIndex) {
                    return i;
                }
            }
        }
        
        return 255; // Not found
    }

    function markShipAsSunk(uint256 gameId, address player, uint8 shipIndex) internal {
        GameState.ShipData memory ship = gameState.getShipData(gameId, player, shipIndex);
        uint8 shipSize = getShipSize(ship.shipType);
        uint8[] memory shipCells = calculateShipCells(ship.x, ship.y, shipSize, ship.rotation);
        
        // Mark all ship cells as sunk
        for (uint8 i = 0; i < shipCells.length; i++) {
            (uint8 x, uint8 y) = gameState.indexToCoords(uint8(shipCells[i]));
            gameState.setCellState(gameId, player, x, y, GameState.CellState.SUNK);
        }
    }

    // =============================================================================
    // TURN MANAGEMENT
    // =============================================================================

    function canPlayerMove(uint256 gameId, address player) external view returns (bool) {
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        if (!gameState.isGameActive(gameId)) return false;
        
        uint8 playerNumber = (player == game.player1) ? 1 : 2;
        return game.currentPlayer == playerNumber;
    }

    function checkTurnTimer(uint256 gameId) external view returns (bool timerExpired) {
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        uint256 turnTimer = gameConfig.getTurnTimer();
        
        return (block.timestamp - game.lastMoveTime) > turnTimer;
    }

    function advanceTurn(uint256 gameId) external onlyAuthorized {
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        uint8 nextPlayer = (game.currentPlayer == 1) ? 2 : 1;
        gameState.updateCurrentPlayer(gameId, nextPlayer);
    }

    function checkGameEnd(uint256 gameId) external view returns (bool gameEnded, address winner) {
        GameState.PlayerFleet memory player1Fleet = gameState.getPlayerFleet(gameId, gameState.getGameInfo(gameId).player1);
        GameState.PlayerFleet memory player2Fleet = gameState.getPlayerFleet(gameId, gameState.getGameInfo(gameId).player2);
        
        if (player1Fleet.shipsRemaining == 0 && player2Fleet.shipsRemaining == 0) {
            return (true, address(0)); // Draw
        } else if (player1Fleet.shipsRemaining == 0) {
            return (true, gameState.getGameInfo(gameId).player2);
        } else if (player2Fleet.shipsRemaining == 0) {
            return (true, gameState.getGameInfo(gameId).player1);
        }
        
        return (false, address(0));
    }

    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================

    function isValidCoordinate(uint8 x, uint8 y) external pure returns (bool) {
        return x < GRID_SIZE && y < GRID_SIZE;
    }

    function getActionsRemaining(uint256 gameId, address player) external view returns (uint8) {
        GameState.GameStateData memory state = gameState.getGameStateData(gameId);
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        
        uint256 actionsUsed;
        if (player == game.player1) {
            actionsUsed = state.player1ActionsUsed;
        } else {
            actionsUsed = state.player2ActionsUsed;
        }
        
        if (actionsUsed >= MAX_ACTIONS_PER_TURN) {
            return 0;
        }
        
        return MAX_ACTIONS_PER_TURN - uint8(actionsUsed);
    }

    function canUseAction(uint256 gameId, address player) external view returns (bool) {
        return this.getActionsRemaining(gameId, player) > 0;
    }
}