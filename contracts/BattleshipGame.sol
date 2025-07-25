// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameState.sol";
import "./GameLogic.sol";

// =============================================================================
// INTERFACES FOR BATTLESHIP GAME
// =============================================================================

interface IGameConfigBG {    
    function getCreditsByGameSize(GameState.GameSize size) external view returns (uint256 winner, uint256 loser);
    function getGameFeePercentage() external view returns (uint256);
    function getTurnTimer() external view returns (uint256);
    function getMaxSkipTurns() external view returns (uint8);
}

interface IShipNFTManagerBG {
    function ownerOf(uint256 tokenId) external view returns (address);
    function canUseShip(uint256 tokenId) external view returns (bool canUse);
    function destroyShip(uint256 tokenId) external;
    function useRentalGame(uint256 tokenId) external;
}

interface IActionNFTManagerBG {
    function ownerOf(uint256 tokenId) external view returns (address);
    function useAction(uint256 tokenId, address user) external;
}

interface ICaptainNFTManagerBG {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface ICrewNFTManagerBG {
    function ownerOf(uint256 tokenId) external view returns (address);
    function canUseCrew(uint256 tokenId) external view returns (bool canUse, uint8 currentStamina);
}

interface ITokenomicsCore {
    function distributeGameCredits(address winner, address loser, uint256 winnerAmount, uint256 loserAmount, uint256 gameId) external;
    function recordGameFee(uint256 amount, address player1, address player2, uint256 gameId) external;
}

/**
 * @title BattleshipGame
 * @dev Main orchestrator contract for CryptoBattleship - coordinates GameState and GameLogic
 */
contract BattleshipGame is ReentrancyGuard, Pausable, Ownable {
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    GameState public gameState;
    GameLogic public gameLogic;
    IGameConfigBG public gameConfig;
    IShipNFTManagerBG public shipNFTManager;
    IActionNFTManagerBG public actionNFTManager;
    ICaptainNFTManagerBG public captainNFTManager;
    ICrewNFTManagerBG public crewNFTManager;
    ITokenomicsCore public tokenomicsCore;

    // Ante configuration
    mapping(GameState.GameSize => uint256) public anteAmounts;
    
    // Game tracking
    mapping(address => uint256) public playerActiveGames;
    mapping(address => uint256) public playerGameStats;
    
    // Emergency controls
    bool public emergencyMode;
    mapping(uint256 => bool) public emergencyEndedGames;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event GameCreated(uint256 indexed gameId, address indexed player1, GameState.GameSize gameSize, uint256 ante);
    event GameJoined(uint256 indexed gameId, address indexed player2);
    event GameStarted(uint256 indexed gameId, address indexed player1, address indexed player2);
    event AttackMade(uint256 indexed gameId, address indexed attacker, uint8 x, uint8 y, bool hit);
    event GameEnded(uint256 indexed gameId, address indexed winner, address indexed loser, uint256 winnerCredits, uint256 loserCredits);
    event AnteUpdated(GameState.GameSize gameSize, uint256 newAnte);
    event EmergencyModeToggled(bool enabled);

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier gameExists(uint256 gameId) {
        require(gameId > 0 && gameId < gameState.nextGameId(), "BattleshipGame: Invalid game ID");
        _;
    }

    modifier onlyPlayer(uint256 gameId) {
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        require(msg.sender == game.player1 || msg.sender == game.player2, "BattleshipGame: Not a player in this game");
        _;
    }

    modifier notInEmergency() {
        require(!emergencyMode, "BattleshipGame: Emergency mode active");
        _;
    }

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(
        address _initialAdmin,
        address _gameState,
        address _gameLogic,
        address _gameConfig
    ) Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "BattleshipGame: Invalid admin");
        require(_gameState != address(0), "BattleshipGame: Invalid GameState");
        require(_gameLogic != address(0), "BattleshipGame: Invalid GameLogic");
        require(_gameConfig != address(0), "BattleshipGame: Invalid GameConfig");

        gameState = GameState(_gameState);
        gameLogic = GameLogic(_gameLogic);
        gameConfig = IGameConfigBG(_gameConfig);

        // Set default antes (1 SHIP token = 1e18 wei)
        anteAmounts[GameState.GameSize.SHRIMP] = 1e18;   // 1 SHIP
        anteAmounts[GameState.GameSize.FISH] = 1e18;     // 1 SHIP  
        anteAmounts[GameState.GameSize.SHARK] = 1e18;    // 1 SHIP
        anteAmounts[GameState.GameSize.WHALE] = 1e18;    // 1 SHIP
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    function setContractAddresses(
        address _gameConfig,
        address _shipNFTManager,
        address _actionNFTManager,
        address _captainNFTManager,
        address _crewNFTManager,
        address _tokenomicsCore
    ) external onlyOwner {
        if (_gameConfig != address(0)) gameConfig = IGameConfigBG(_gameConfig);
        if (_shipNFTManager != address(0)) shipNFTManager = IShipNFTManagerBG(_shipNFTManager);
        if (_actionNFTManager != address(0)) actionNFTManager = IActionNFTManagerBG(_actionNFTManager);
        if (_captainNFTManager != address(0)) captainNFTManager = ICaptainNFTManagerBG(_captainNFTManager);
        if (_crewNFTManager != address(0)) crewNFTManager = ICrewNFTManagerBG(_crewNFTManager);
        if (_tokenomicsCore != address(0)) tokenomicsCore = ITokenomicsCore(_tokenomicsCore);
    }

    function updateAnteAmount(GameState.GameSize gameSize, uint256 newAnte) external onlyOwner {
        require(newAnte > 0, "BattleshipGame: Ante must be greater than 0");
        anteAmounts[gameSize] = newAnte;
        emit AnteUpdated(gameSize, newAnte);
    }

    function toggleEmergencyMode() external onlyOwner {
        emergencyMode = !emergencyMode;
        emit EmergencyModeToggled(emergencyMode);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // =============================================================================
    // GAME LIFECYCLE FUNCTIONS
    // =============================================================================

    function createGame(GameState.GameSize gameSize) 
        external 
        nonReentrant 
        whenNotPaused 
        notInEmergency 
        returns (uint256 gameId) 
    {
        require(playerActiveGames[msg.sender] == 0, "BattleshipGame: Player already in a game");
        
        uint256 ante = anteAmounts[gameSize];
        require(ante > 0, "BattleshipGame: Invalid game size");

        gameId = gameState.createGame(msg.sender, gameSize, ante);
        playerActiveGames[msg.sender] = gameId;

        emit GameCreated(gameId, msg.sender, gameSize, ante);
        return gameId;
    }

    function joinGame(uint256 gameId) 
        external 
        nonReentrant 
        whenNotPaused 
        notInEmergency 
        gameExists(gameId) 
    {
        require(playerActiveGames[msg.sender] == 0, "BattleshipGame: Player already in a game");
        
        gameState.joinGame(gameId, msg.sender);
        playerActiveGames[msg.sender] = gameId;

        emit GameJoined(gameId, msg.sender);
    }

    function placeShips(
        uint256 gameId,
        uint256 shipId,
        uint256[] calldata actionIds,
        uint256 captainId,
        uint256[] calldata crewIds,
        uint8[5] calldata shipTypes,
        uint8[5] calldata xPositions,
        uint8[5] calldata yPositions,
        GameState.ShipRotation[5] calldata rotations
    ) external nonReentrant whenNotPaused gameExists(gameId) onlyPlayer(gameId) {
        // Validate NFT ownership
        require(shipNFTManager.ownerOf(shipId) == msg.sender, "BattleshipGame: Ship not owned");
        require(captainNFTManager.ownerOf(captainId) == msg.sender, "BattleshipGame: Captain not owned");
        
        for (uint256 i = 0; i < actionIds.length; i++) {
            require(actionNFTManager.ownerOf(actionIds[i]) == msg.sender, "BattleshipGame: Action not owned");
        }
        
        for (uint256 i = 0; i < crewIds.length; i++) {
            require(crewNFTManager.ownerOf(crewIds[i]) == msg.sender, "BattleshipGame: Crew not owned");
        }

        // Set fleet in GameState
        gameState.setPlayerFleet(gameId, msg.sender, shipId, actionIds, captainId, crewIds);
        
        // Validate and place ships using GameLogic
        bool valid = gameLogic.validateShipPlacement(gameId, msg.sender, shipTypes, xPositions, yPositions, rotations);
        require(valid, "BattleshipGame: Invalid ship placement");
        
        gameState.setShipsPlaced(gameId, msg.sender, true);
        
        // Check if both players have placed ships
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        GameState.PlayerFleet memory player1Fleet = gameState.getPlayerFleet(gameId, game.player1);
        GameState.PlayerFleet memory player2Fleet = gameState.getPlayerFleet(gameId, game.player2);
        
        if (player1Fleet.shipsPlaced && player2Fleet.shipsPlaced) {
            gameState.startGame(gameId);
            emit GameStarted(gameId, game.player1, game.player2);
        }
    }

    // =============================================================================
    // GAMEPLAY FUNCTIONS
    // =============================================================================

    function defaultAttack(
        uint256 gameId,
        uint8 targetX,
        uint8 targetY,
        bool useCaptainAbility,
        uint256[] calldata crewIds
    ) external nonReentrant whenNotPaused gameExists(gameId) onlyPlayer(gameId) {
        require(gameLogic.canPlayerMove(gameId, msg.sender), "BattleshipGame: Not your turn");
        require(gameLogic.canUseAction(gameId, msg.sender), "BattleshipGame: No actions remaining");
        
        // Execute attack through GameLogic
        (bool hit, uint8 damage, bool shipDestroyed) = gameLogic.executeAttack(
            gameId, 
            msg.sender, 
            targetX, 
            targetY, 
            useCaptainAbility, 
            crewIds
        );
        
        gameState.incrementActionsUsed(gameId, msg.sender);
        emit AttackMade(gameId, msg.sender, targetX, targetY, hit);
        
        // Check for game end
        (bool gameEnded, address winner) = gameLogic.checkGameEnd(gameId);
        if (gameEnded) {
            endGame(gameId, winner);
        }
    }

    function endTurn(uint256 gameId) 
        external 
        nonReentrant 
        whenNotPaused 
        gameExists(gameId) 
        onlyPlayer(gameId) 
    {
        require(gameLogic.canPlayerMove(gameId, msg.sender), "BattleshipGame: Not your turn");
        
        gameLogic.advanceTurn(gameId);
        
        // Check for game end after turn
        (bool gameEnded, address winner) = gameLogic.checkGameEnd(gameId);
        if (gameEnded) {
            endGame(gameId, winner);
        }
    }

    function forceSkipTurn(uint256 gameId) 
        external 
        nonReentrant 
        whenNotPaused 
        gameExists(gameId) 
    {
        require(gameLogic.checkTurnTimer(gameId), "BattleshipGame: Turn timer not expired");
        
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        address currentPlayerAddr = (game.currentPlayer == 1) ? game.player1 : game.player2;
        
        gameState.incrementSkippedTurns(gameId, currentPlayerAddr);
        gameLogic.advanceTurn(gameId);
        
        // Check skip limit
        uint8 maxSkips = gameConfig.getMaxSkipTurns();
        uint8 skippedTurns = (game.currentPlayer == 1) ? game.player1SkippedTurns : game.player2SkippedTurns;
        
        if (skippedTurns >= maxSkips) {
            address winner = (currentPlayerAddr == game.player1) ? game.player2 : game.player1;
            endGame(gameId, winner);
        }
    }

    // =============================================================================
    // GAME COMPLETION
    // =============================================================================

    function endGame(uint256 gameId, address winner) internal {
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        gameState.endGame(gameId, winner);
        
        // Clear player active games
        playerActiveGames[game.player1] = 0;
        playerActiveGames[game.player2] = 0;
        
        // Distribute credits
        distributeCredits(gameId, winner, game);
        
        emit GameEnded(gameId, winner, getOpponent(game, winner), 0, 0);
    }

    function distributeCredits(uint256 gameId, address winner, GameState.GameInfo memory game) internal {
        if (address(tokenomicsCore) == address(0)) return;
        
        (uint256 winnerCredits, uint256 loserCredits) = gameConfig.getCreditsByGameSize(game.gameSize);
        address loser = getOpponent(game, winner);
        
        tokenomicsCore.distributeGameCredits(winner, loser, winnerCredits, loserCredits, gameId);
        
        // Record game fee
        uint256 feePercentage = gameConfig.getGameFeePercentage();
        uint256 feeAmount = (game.ante * feePercentage) / 100;
        if (feeAmount > 0) {
            tokenomicsCore.recordGameFee(feeAmount, game.player1, game.player2, gameId);
        }
    }

    function cancelGame(uint256 gameId) 
        external 
        nonReentrant 
        gameExists(gameId) 
        onlyPlayer(gameId) 
    {
        GameState.GameInfo memory game = gameState.getGameInfo(gameId);
        require(game.status == GameState.GameStatus.WAITING, "BattleshipGame: Can only cancel waiting games");
        require(game.player2 == address(0), "BattleshipGame: Cannot cancel joined games");
        
        gameState.cancelGame(gameId);
        playerActiveGames[msg.sender] = 0;
    }

    function forceEndGame(uint256 gameId, address winner) 
        external 
        onlyOwner 
        gameExists(gameId) 
    {
        require(emergencyMode, "BattleshipGame: Emergency mode required");
        require(!emergencyEndedGames[gameId], "BattleshipGame: Game already emergency ended");
        
        emergencyEndedGames[gameId] = true;
        endGame(gameId, winner);
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getGameInfo(uint256 gameId) external view gameExists(gameId) returns (GameState.GameInfo memory) {
        return gameState.getGameInfo(gameId);
    }

    function getGameState(uint256 gameId) external view gameExists(gameId) returns (GameState.GameStateData memory) {
        return gameState.getGameStateData(gameId);
    }

    function getPlayerFleet(uint256 gameId, address player) external view gameExists(gameId) returns (GameState.PlayerFleet memory) {
        return gameState.getPlayerFleet(gameId, player);
    }

    function canPlayerMove(uint256 gameId, address player) external view gameExists(gameId) returns (bool) {
        return gameLogic.canPlayerMove(gameId, player);
    }

    function getActionsRemaining(uint256 gameId, address player) external view gameExists(gameId) returns (uint8) {
        return gameLogic.getActionsRemaining(gameId, player);
    }

    function getCellState(uint256 gameId, address player, uint8 x, uint8 y) 
        external view gameExists(gameId) returns (GameState.CellState) 
    {
        return gameState.getCellState(gameId, player, x, y);
    }

    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================

    function getOpponent(GameState.GameInfo memory game, address player) internal pure returns (address) {
        if (game.player1 == player) {
            return game.player2;
        } else if (game.player2 == player) {
            return game.player1;
        } else {
            revert("BattleshipGame: Player not in game");
        }
    }

    function getAnteAmount(GameState.GameSize gameSize) external view returns (uint256) {
        return anteAmounts[gameSize];
    }

    function isPlayerInGame(address player) external view returns (bool) {
        return playerActiveGames[player] != 0;
    }

    function getPlayerActiveGame(address player) external view returns (uint256) {
        return playerActiveGames[player];
    }
}