// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GameConfig
 * @dev Central configuration contract for CryptoBattleship game parameters
 * @notice This contract stores all configurable parameters for the game mechanics,
 *         NFT systems, and tokenomics. Only admin can modify parameters.
 */
contract GameConfig is Ownable, Pausable, ReentrancyGuard {
    
    // =============================================================================
    // ENUMS AND STRUCTS (from STANDARDS.md)
    // =============================================================================
    
    enum GameSize { SHRIMP, FISH, SHARK, WHALE }
    enum CellState { EMPTY, SHIP, HIT, MISS, SUNK, SHIELDED, SCANNING, SPECIAL }
    enum ShipType { DESTROYER, SUBMARINE, CRUISER, BATTLESHIP, CARRIER }
    enum ShipRotation { HORIZONTAL, VERTICAL, DIAGONAL_RIGHT, DIAGONAL_LEFT }
    enum ActionType { OFFENSIVE, DEFENSIVE }
    enum CrewType { GUNNER, ENGINEER, NAVIGATOR, MEDIC }
    enum CaptainAbility { SCAN_BOOST, DAMAGE_BOOST, SPEED_BOOST, SHIELDS, REVEAL, DODGE, BERSERKER, DEFENDER }

    struct ShipStats {
        uint8 health;
        uint8 speed;
        uint8 shields;
        uint8 size;
    }

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event ParameterUpdated(bytes32 indexed parameterKey, uint256 oldValue, uint256 newValue);
    event EmergencyPauseActivated(address indexed admin);
    event EmergencyPauseDeactivated(address indexed admin);
    event AdminRoleGranted(address indexed newAdmin, address indexed grantor);

    // =============================================================================
    // SECTION 1.1: BASIC CONTRACT STRUCTURE AND ADMIN CONTROLS
    // =============================================================================

    // Additional admin addresses for multi-admin support
    mapping(address => bool) public isAdmin;
    
    // Emergency pause reasons for transparency
    string public pauseReason;

    /**
     * @dev Function1: Contract initialization with admin role
     * @param _initialAdmin Address to be granted initial admin privileges
     */
    constructor(address _initialAdmin) {
        require(_initialAdmin != address(0), "GameConfig: Initial admin cannot be zero address");
        
        // Set contract deployer as owner (OpenZeppelin Ownable)
        _transferOwnership(_initialAdmin);
        
        // Grant admin role to initial admin
        isAdmin[_initialAdmin] = true;
        
        // Initialize ship stats and default configurations
        _initializeShipStats();
        _initializeNFTEconomyParams();
        
        emit AdminRoleGranted(_initialAdmin, msg.sender);
    }

    /**
     * @dev Function2: Admin modifier and access control
     * @notice Restricts function access to admin addresses only
     */
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner(), "GameConfig: Caller is not an admin");
        _;
    }

    /**
     * @dev Grant admin role to a new address
     * @param _newAdmin Address to grant admin privileges
     * @notice Only owner can grant admin roles
     */
    function grantAdminRole(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "GameConfig: Cannot grant admin to zero address");
        require(!isAdmin[_newAdmin], "GameConfig: Address is already an admin");
        
        isAdmin[_newAdmin] = true;
        emit AdminRoleGranted(_newAdmin, msg.sender);
    }

    /**
     * @dev Revoke admin role from an address
     * @param _admin Address to revoke admin privileges from
     * @notice Only owner can revoke admin roles
     */
    function revokeAdminRole(address _admin) external onlyOwner {
        require(_admin != address(0), "GameConfig: Cannot revoke from zero address");
        require(isAdmin[_admin], "GameConfig: Address is not an admin");
        require(_admin != owner(), "GameConfig: Cannot revoke owner's admin role");
        
        isAdmin[_admin] = false;
    }

    /**
     * @dev Function3: Emergency pause functionality
     * @param _reason Reason for the emergency pause
     * @notice Pauses all contract functionality in case of emergency
     */
    function emergencyPause(string calldata _reason) external onlyAdmin {
        require(bytes(_reason).length > 0, "GameConfig: Pause reason cannot be empty");
        
        pauseReason = _reason;
        _pause();
        
        emit EmergencyPauseActivated(msg.sender);
    }

    /**
     * @dev Unpause the contract after emergency
     * @notice Only admin can unpause the contract
     */
    function emergencyUnpause() external onlyAdmin {
        pauseReason = "";
        _unpause();
        
        emit EmergencyPauseDeactivated(msg.sender);
    }

    /**
     * @dev Check if an address has admin privileges
     * @param _address Address to check
     * @return bool True if address is admin or owner
     */
    function hasAdminRole(address _address) external view returns (bool) {
        return isAdmin[_address] || _address == owner();
    }

    /**
     * @dev Get current pause status and reason
     * @return isPaused Current pause status
     * @return reason Current pause reason (empty if not paused)
     */
    function getPauseStatus() external view returns (bool isPaused, string memory reason) {
        return (paused(), pauseReason);
    }

    // =============================================================================
    // SECTION 1.2: GAME PARAMETER STORAGE AND GETTERS
    // =============================================================================

    // Function1: Grid size and cell state configurations
    uint8 public gridSize = 10; // 10x10 grid
    uint8 public maxCellStates = 8; // Number of possible cell states

    // Function2: Turn timer and skip turn parameters
    uint256 public turnTimer = 5 minutes; // Default turn time limit
    uint8 public maxSkipTurns = 3; // Max consecutive skipped turns before penalty
    uint256 public skipPenaltyRevealGrid = 3; // Reveal grid after this many skips

    // Function3: Ship type definitions and stats
    mapping(ShipType => ShipStats) public shipStats;

    // Fleet requirements: [Destroyer, Submarine, Cruiser, Battleship, Carrier]
    uint8[5] public fleetRequirements = [1, 2, 0, 1, 1]; // 1 Destroyer, 2 Sub/Cruiser, 1 Battleship, 1 Carrier

    // Function4: Default attack configuration
    uint8 public defaultAttackDamage = 1;
    uint8[] public defaultAttackPattern; // Single cell pattern by default

    /**
     * @dev Initialize ship stats with default values
     * @notice Called during contract deployment to set up ship configurations
     */
    function _initializeShipStats() private {
        // Destroyer: size 2, health 2, speed 3, shields 0
        shipStats[ShipType.DESTROYER] = ShipStats({
            health: 2,
            speed: 3,
            shields: 0,
            size: 2
        });

        // Submarine: size 3, health 3, speed 2, shields 1
        shipStats[ShipType.SUBMARINE] = ShipStats({
            health: 3,
            speed: 2,
            shields: 1,
            size: 3
        });

        // Cruiser: size 3, health 3, speed 2, shields 1
        shipStats[ShipType.CRUISER] = ShipStats({
            health: 3,
            speed: 2,
            shields: 1,
            size: 3
        });

        // Battleship: size 4, health 4, speed 1, shields 2
        shipStats[ShipType.BATTLESHIP] = ShipStats({
            health: 4,
            speed: 1,
            shields: 2,
            size: 4
        });

        // Carrier: size 5, health 5, speed 1, shields 2
        shipStats[ShipType.CARRIER] = ShipStats({
            health: 5,
            speed: 1,
            shields: 2,
            size: 5
        });

        // Initialize default attack pattern (single cell)
        defaultAttackPattern.push(0); // Single target cell
    }

    /**
     * @dev Get grid size configuration
     * @return uint8 Current grid size (default 10 for 10x10)
     */
    function getGridSize() external view returns (uint8) {
        return gridSize;
    }

    /**
     * @dev Get turn timer configuration
     * @return uint256 Current turn timer in seconds
     */
    function getTurnTimer() external view returns (uint256) {
        return turnTimer;
    }

    /**
     * @dev Get maximum skip turns before penalty
     * @return uint8 Maximum consecutive skipped turns allowed
     */
    function getMaxSkipTurns() external view returns (uint8) {
        return maxSkipTurns;
    }

    /**
     * @dev Get ship stats for a specific ship type
     * @param shipType The type of ship to get stats for
     * @return ShipStats Struct containing health, speed, shields, and size
     */
    function getShipStats(ShipType shipType) external view returns (ShipStats memory) {
        return shipStats[shipType];
    }

    /**
     * @dev Get fleet requirements configuration
     * @return uint8[5] Array of required ship counts [Destroyer, Submarine, Cruiser, Battleship, Carrier]
     */
    function getFleetRequirements() external view returns (uint8[5] memory) {
        return fleetRequirements;
    }

    /**
     * @dev Get default attack damage
     * @return uint8 Damage dealt by default attack
     */
    function getDefaultAttackDamage() external view returns (uint8) {
        return defaultAttackDamage;
    }

    /**
     * @dev Get default attack pattern
     * @return uint8[] Array representing attack pattern (single cell by default)
     */
    function getDefaultAttackPattern() external view returns (uint8[] memory) {
        return defaultAttackPattern;
    }

    // =============================================================================
    // SECTION 1.3: NFT AND ECONOMY PARAMETERS
    // =============================================================================

    // Function1: Action NFT use counts by rarity
    // Rarity mapping: 0=Common, 1=Rare, 2=Epic, 3=Legendary
    mapping(uint8 => uint8) public actionUsesByRarity;

    // Function2: Captain ability toggles for default attack
    mapping(CaptainAbility => bool) public captainDefaultAttackToggle;

    // Function3: Credit earning rates by game size
    mapping(GameSize => uint256) public winnerCredits;
    mapping(GameSize => uint256) public loserCredits;

    // Function4: Ship destruction chance configuration
    uint256 public shipDestructionChance = 10; // 10% chance on game loss (in percentage)

    // Additional economy parameters
    uint256 public gameFeePercentage = 5; // 5% fee on game buy-ins
    uint256 public weeklyEmissionRate = 100000; // Base weekly emission amount (adjustable)

    // Crew default attack toggles
    mapping(CrewType => bool) public crewDefaultAttackToggle;

    /**
     * @dev Initialize NFT and economy parameters
     * @notice Called during contract deployment to set default values
     */
    function _initializeNFTEconomyParams() private {
        // Function1: Set action use counts by rarity
        actionUsesByRarity[0] = 15; // Common: 15 uses
        actionUsesByRarity[1] = 10; // Rare: 10 uses
        actionUsesByRarity[2] = 7;  // Epic: 7 uses
        actionUsesByRarity[3] = 3;  // Legendary: 3 uses

        // Function2: Initialize captain ability toggles (all disabled by default)
        captainDefaultAttackToggle[CaptainAbility.SCAN_BOOST] = false;
        captainDefaultAttackToggle[CaptainAbility.DAMAGE_BOOST] = false;
        captainDefaultAttackToggle[CaptainAbility.SPEED_BOOST] = false;
        captainDefaultAttackToggle[CaptainAbility.SHIELDS] = false;
        captainDefaultAttackToggle[CaptainAbility.REVEAL] = false;
        captainDefaultAttackToggle[CaptainAbility.DODGE] = false;
        captainDefaultAttackToggle[CaptainAbility.BERSERKER] = false;
        captainDefaultAttackToggle[CaptainAbility.DEFENDER] = false;

        // Function3: Set credit earning rates by game size
        winnerCredits[GameSize.SHRIMP] = 1;
        loserCredits[GameSize.SHRIMP] = 0;
        
        winnerCredits[GameSize.FISH] = 4;
        loserCredits[GameSize.FISH] = 2;
        
        winnerCredits[GameSize.SHARK] = 7;
        loserCredits[GameSize.SHARK] = 3;
        
        winnerCredits[GameSize.WHALE] = 30;
        loserCredits[GameSize.WHALE] = 15;

        // Initialize crew default attack toggles (all disabled by default)
        crewDefaultAttackToggle[CrewType.GUNNER] = false;
        crewDefaultAttackToggle[CrewType.ENGINEER] = false;
        crewDefaultAttackToggle[CrewType.NAVIGATOR] = false;
        crewDefaultAttackToggle[CrewType.MEDIC] = false;
    }

    /**
     * @dev Get action use count by rarity
     * @param rarity Rarity level (0-3)
     * @return uint8 Number of uses for actions of this rarity
     */
    function getActionUsesByRarity(uint8 rarity) external view returns (uint8) {
        require(rarity <= 3, "GameConfig: Invalid rarity level");
        return actionUsesByRarity[rarity];
    }

    /**
     * @dev Get captain ability default attack toggle status
     * @param ability Captain ability to check
     * @return bool True if ability affects default attack
     */
    function getCaptainDefaultAttackToggle(CaptainAbility ability) external view returns (bool) {
        return captainDefaultAttackToggle[ability];
    }

    /**
     * @dev Get crew type default attack toggle status
     * @param crewType Crew type to check
     * @return bool True if crew type affects default attack
     */
    function getCrewDefaultAttackToggle(CrewType crewType) external view returns (bool) {
        return crewDefaultAttackToggle[crewType];
    }

    /**
     * @dev Get credit earning rates by game size
     * @param size Game size to check
     * @return winner Credits awarded to winner
     * @return loser Credits awarded to loser
     */
    function getCreditsByGameSize(GameSize size) external view returns (uint256 winner, uint256 loser) {
        return (winnerCredits[size], loserCredits[size]);
    }

    /**
     * @dev Get ship destruction chance
     * @return uint256 Destruction chance percentage (10 = 10%)
     */
    function getShipDestructionChance() external view returns (uint256) {
        return shipDestructionChance;
    }

    /**
     * @dev Get game fee percentage
     * @return uint256 Fee percentage (5 = 5%)
     */
    function getGameFeePercentage() external view returns (uint256) {
        return gameFeePercentage;
    }

    /**
     * @dev Get weekly emission rate
     * @return uint256 Base weekly emission amount
     */
    function getWeeklyEmissionRate() external view returns (uint256) {
        return weeklyEmissionRate;
    }

    // =============================================================================
    // SECTION 1.4: PARAMETER UPDATE FUNCTIONS
    // =============================================================================

    /**
     * @dev Function1: Update game mechanics parameters
     * @param key Parameter key identifier
     * @param value New parameter value
     * @notice Only admin can update game parameters
     */
    function updateGameParameter(bytes32 key, uint256 value) external onlyAdmin whenNotPaused {
        uint256 oldValue;
        
        if (key == keccak256("gridSize")) {
            require(value >= 8 && value <= 20, "GameConfig: Grid size must be between 8 and 20");
            oldValue = gridSize;
            gridSize = uint8(value);
        } else if (key == keccak256("turnTimer")) {
            require(value >= 30 seconds && value <= 30 minutes, "GameConfig: Turn timer must be between 30 seconds and 30 minutes");
            oldValue = turnTimer;
            turnTimer = value;
        } else if (key == keccak256("maxSkipTurns")) {
            require(value >= 1 && value <= 10, "GameConfig: Max skip turns must be between 1 and 10");
            oldValue = maxSkipTurns;
            maxSkipTurns = uint8(value);
        } else if (key == keccak256("defaultAttackDamage")) {
            require(value >= 1 && value <= 5, "GameConfig: Default attack damage must be between 1 and 5");
            oldValue = defaultAttackDamage;
            defaultAttackDamage = uint8(value);
        } else {
            revert("GameConfig: Invalid game parameter key");
        }
        
        emit ParameterUpdated(key, oldValue, value);
    }

    /**
     * @dev Function2: Update tokenomics parameters
     * @param key Parameter key identifier
     * @param value New parameter value
     * @notice Only admin can update tokenomics parameters
     */
    function updateTokenomicsParameter(bytes32 key, uint256 value) external onlyAdmin whenNotPaused {
        uint256 oldValue;
        
        if (key == keccak256("gameFeePercentage")) {
            require(value <= 20, "GameConfig: Game fee cannot exceed 20%");
            oldValue = gameFeePercentage;
            gameFeePercentage = value;
        } else if (key == keccak256("weeklyEmissionRate")) {
            require(value <= 1000000, "GameConfig: Weekly emission rate too high");
            oldValue = weeklyEmissionRate;
            weeklyEmissionRate = value;
        } else if (key == keccak256("shipDestructionChance")) {
            require(value <= 50, "GameConfig: Ship destruction chance cannot exceed 50%");
            oldValue = shipDestructionChance;
            shipDestructionChance = value;
        } else {
            revert("GameConfig: Invalid tokenomics parameter key");
        }
        
        emit ParameterUpdated(key, oldValue, value);
    }

    /**
     * @dev Function3: Update NFT parameters
     * @param paramType Type of NFT parameter (1=action, 2=captain, 3=crew, 4=credits)
     * @param identifier Specific identifier (rarity, ability, crew type, or game size)
     * @param value New parameter value
     * @notice Only admin can update NFT parameters
     */
    function updateNFTParameter(uint8 paramType, uint8 identifier, uint256 value) external onlyAdmin whenNotPaused {
        bytes32 key;
        uint256 oldValue;
        
        if (paramType == 1) { // Action use counts
            require(identifier <= 3, "GameConfig: Invalid rarity level");
            require(value >= 1 && value <= 50, "GameConfig: Action uses must be between 1 and 50");
            key = keccak256(abi.encodePacked("actionUses", identifier));
            oldValue = actionUsesByRarity[identifier];
            actionUsesByRarity[identifier] = uint8(value);
        } else if (paramType == 2) { // Captain toggles
            require(identifier <= 7, "GameConfig: Invalid captain ability");
            key = keccak256(abi.encodePacked("captainToggle", identifier));
            oldValue = captainDefaultAttackToggle[CaptainAbility(identifier)] ? 1 : 0;
            captainDefaultAttackToggle[CaptainAbility(identifier)] = value == 1;
        } else if (paramType == 3) { // Crew toggles  
            require(identifier <= 3, "GameConfig: Invalid crew type");
            key = keccak256(abi.encodePacked("crewToggle", identifier));
            oldValue = crewDefaultAttackToggle[CrewType(identifier)] ? 1 : 0;
            crewDefaultAttackToggle[CrewType(identifier)] = value == 1;
        } else if (paramType == 4) { // Credit rates
            require(identifier <= 3, "GameConfig: Invalid game size");
            require(value <= 100, "GameConfig: Credit amount too high");
            key = keccak256(abi.encodePacked("credits", identifier));
            oldValue = winnerCredits[GameSize(identifier)];
            winnerCredits[GameSize(identifier)] = value;
            // Loser gets half of winner credits (except SHRIMP which stays 0)
            if (identifier > 0) {
                loserCredits[GameSize(identifier)] = value / 2;
            }
        } else {
            revert("GameConfig: Invalid NFT parameter type");
        }
        
        emit ParameterUpdated(key, oldValue, value);
    }

    /**
     * @dev Function4: Batch parameter updates for gas efficiency
     * @param keys Array of parameter keys
     * @param values Array of parameter values
     * @notice Keys and values arrays must have the same length
     */
    function batchUpdateParameters(bytes32[] calldata keys, uint256[] calldata values) external onlyAdmin whenNotPaused {
        require(keys.length == values.length, "GameConfig: Arrays length mismatch");
        require(keys.length <= 20, "GameConfig: Too many parameters in batch");
        
        for (uint256 i = 0; i < keys.length; i++) {
            // Route to appropriate update function based on key prefix
            if (keys[i] == keccak256("gridSize") || 
                keys[i] == keccak256("turnTimer") || 
                keys[i] == keccak256("maxSkipTurns") || 
                keys[i] == keccak256("defaultAttackDamage")) {
                updateGameParameter(keys[i], values[i]);
            } else if (keys[i] == keccak256("gameFeePercentage") || 
                       keys[i] == keccak256("weeklyEmissionRate") || 
                       keys[i] == keccak256("shipDestructionChance")) {
                updateTokenomicsParameter(keys[i], values[i]);
            } else {
                revert("GameConfig: Invalid parameter key in batch");
            }
        }
    }

    /**
     * @dev Update ship stats for a specific ship type
     * @param shipType Type of ship to update
     * @param newStats New stats for the ship
     * @notice Only admin can update ship stats
     */
    function updateShipStats(ShipType shipType, ShipStats calldata newStats) external onlyAdmin whenNotPaused {
        require(newStats.health > 0 && newStats.health <= 10, "GameConfig: Health must be between 1 and 10");
        require(newStats.speed > 0 && newStats.speed <= 5, "GameConfig: Speed must be between 1 and 5");
        require(newStats.shields <= 5, "GameConfig: Shields cannot exceed 5");
        require(newStats.size > 0 && newStats.size <= 6, "GameConfig: Size must be between 1 and 6");
        
        shipStats[shipType] = newStats;
        
        emit ParameterUpdated(
            keccak256(abi.encodePacked("shipStats", uint8(shipType))), 
            0, 
            uint256(newStats.health) << 24 | uint256(newStats.speed) << 16 | uint256(newStats.shields) << 8 | uint256(newStats.size)
        );
    }

    /**
     * @dev Update fleet requirements
     * @param newRequirements New fleet composition requirements
     * @notice Only admin can update fleet requirements
     */
    function updateFleetRequirements(uint8[5] calldata newRequirements) external onlyAdmin whenNotPaused {
        for (uint8 i = 0; i < 5; i++) {
            require(newRequirements[i] <= 5, "GameConfig: Fleet requirement too high");
        }
        
        uint256 oldValue = uint256(fleetRequirements[0]) << 32 | uint256(fleetRequirements[1]) << 24 | 
                          uint256(fleetRequirements[2]) << 16 | uint256(fleetRequirements[3]) << 8 | 
                          uint256(fleetRequirements[4]);
        
        fleetRequirements = newRequirements;
        
        uint256 newValue = uint256(newRequirements[0]) << 32 | uint256(newRequirements[1]) << 24 | 
                          uint256(newRequirements[2]) << 16 | uint256(newRequirements[3]) << 8 | 
                          uint256(newRequirements[4]);
        
        emit ParameterUpdated(keccak256("fleetRequirements"), oldValue, newValue);
    }
} 