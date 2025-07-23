// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ShipNFTManager
 * @dev Manages Ship NFTs with placard and grid SVGs
 * @notice Handles battle ships with stats and variants
 */
contract ShipNFTManager is ERC721, ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // =============================================================================
    // ENUMS AND STRUCTS
    // =============================================================================

    /**
     * @dev Rarity levels for all NFT types
     */
    enum Rarity {
        COMMON,     // 0: 60% drop rate
        UNCOMMON,   // 1: 25% drop rate  
        RARE,       // 2: 10% drop rate
        EPIC,       // 3: 4% drop rate
        LEGENDARY   // 4: 1% drop rate
    }

    /**
     * @dev Ship types matching game mechanics
     */
    enum ShipType {
        DESTROYER,    // 0: Size 2, Speed 3
        SUBMARINE,    // 1: Size 3, Speed 2  
        CRUISER,      // 2: Size 3, Speed 2
        BATTLESHIP,   // 3: Size 4, Speed 1
        CARRIER       // 4: Size 5, Speed 1
    }

    /**
     * @dev Ship statistics
     */
    struct ShipStats {
        uint8 health;        // Ship health points
        uint8 speed;         // Movement speed per turn
        uint8 shields;       // Damage reduction
        uint8 size;          // Ship size (cells on grid)
        uint8 firepower;     // Attack damage
        uint8 range;         // Attack range
        uint8 armor;         // Damage resistance
        uint8 stealth;       // Evasion capability
    }

    /**
     * @dev Ship variant for seasonal collections
     */
    struct ShipVariant {
        string name;             // Variant name (e.g., "Military Fleet")
        bool isActive;           // Whether variant is active
        bool isRetired;          // Whether variant is retired
        uint256 seasonId;        // Season ID
        uint8 svgThemeId;        // SVG theme identifier for artwork
        bool hasAnimations;      // Whether variant has animations
        uint256 retiredAt;       // Block number when retired
        VariantStatMods statMods; // Stat modifications for this variant
    }

    /**
     * @dev Variant stat modifications
     */
    struct VariantStatMods {
        int8 healthMod;      // Health modifier (-5 to +5)
        int8 speedMod;       // Speed modifier (-2 to +2)
        int8 shieldsMod;     // Shields modifier (-3 to +3)
        int8 firepowerMod;   // Firepower modifier (-3 to +3)
        int8 rangeMod;       // Range modifier (-2 to +2)
        int8 armorMod;       // Armor modifier (-2 to +2)
        int8 stealthMod;     // Stealth modifier (-2 to +2)
    }

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    // Token tracking
    uint256 private _nextTokenId = 1;
    mapping(uint256 => Rarity) public tokenRarities;
    mapping(uint256 => ShipType) public shipTypes;
    mapping(uint256 => uint256) public shipVariants;
    mapping(uint256 => ShipStats) public shipStats;
    mapping(uint256 => bool) public shipIsDestroyed;
    mapping(uint256 => uint256) public shipCrewCapacity;

    // Variant system
    mapping(uint256 => ShipVariant) public variants;
    uint256 public nextVariantId = 1;
    uint256 public activeVariant = 1; // Default to variant 1

    // SVG system
    uint8 public svgVersion = 1;
    mapping(uint8 => string) private svgThemeColors;
    mapping(uint8 => string) private svgThemeNames;
    mapping(uint8 => string) private svgThemeElements;

    // Ship rental system
    struct RentalInfo {
        bool isRental;           // Whether this is a rental ship
        address renter;          // Who rented it
        uint256 rentedAt;        // When it was rented
        uint256 rentDuration;    // Rental duration in seconds
        uint256 gamesRemaining;  // Games remaining in rental
    }
    mapping(uint256 => RentalInfo) public shipRentals;

    // Authorized minters
    mapping(address => bool) public authorizedMinters;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event ShipMinted(uint256 indexed tokenId, address indexed owner, ShipType shipType, Rarity rarity, uint256 variantId);
    event ShipDestroyed(uint256 indexed tokenId, address indexed owner);
    event ShipRepaired(uint256 indexed tokenId, address indexed owner);
    event ShipVariantCreated(uint256 indexed variantId, string name, uint256 seasonId);
    event ShipVariantActivated(uint256 indexed variantId);
    event ShipVariantRetired(uint256 indexed variantId);
    event ShipRented(uint256 indexed tokenId, address indexed renter, uint256 duration, uint256 games);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);
    event SVGVersionUpdated(uint8 newVersion);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _initialAdmin) ERC721("CryptoBattleship Ships", "CBSHIP") Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "ShipNFTManager: Initial admin cannot be zero address");
        _initializeDefaultVariants();
        _initializeSVGThemes();
    }

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "ShipNFTManager: Not authorized to mint");
        _;
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    /**
     * @dev Set authorized minter status
     * @param minter Address to authorize/unauthorize
     * @param authorized Whether address can mint
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "ShipNFTManager: Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterUpdated(minter, authorized);
    }

    /**
     * @dev Update SVG version for cache invalidation
     * @param newVersion New SVG version
     */
    function updateSVGVersion(uint8 newVersion) external onlyOwner {
        svgVersion = newVersion;
        emit SVGVersionUpdated(newVersion);
    }

    // =============================================================================
    // MINTING FUNCTIONS
    // =============================================================================

    /**
     * @dev Mint ship NFT
     * @param recipient Address to receive the ship
     * @param shipType Type of ship to mint
     * @param rarity Rarity level of the ship
     * @return tokenId Minted token ID
     */
    function mintShip(address recipient, ShipType shipType, Rarity rarity) 
        external 
        onlyAuthorizedMinter
        whenNotPaused
        returns (uint256 tokenId) 
    {
        return _mintShip(recipient, shipType, rarity, activeVariant, false);
    }

    /**
     * @dev Mint rental ship (burns after use)
     * @param recipient Address to receive the ship
     * @param shipType Type of ship to mint
     * @param rarity Rarity level of the ship
     * @param rentDuration Rental duration in seconds
     * @param gamesCount Number of games included
     * @return tokenId Minted token ID
     */
    function mintRentalShip(
        address recipient, 
        ShipType shipType, 
        Rarity rarity, 
        uint256 rentDuration,
        uint256 gamesCount
    ) external onlyAuthorizedMinter whenNotPaused returns (uint256 tokenId) {
        tokenId = _mintShip(recipient, shipType, rarity, activeVariant, true);
        
        // Set rental info
        shipRentals[tokenId] = RentalInfo({
            isRental: true,
            renter: recipient,
            rentedAt: block.timestamp,
            rentDuration: rentDuration,
            gamesRemaining: gamesCount
        });
        
        emit ShipRented(tokenId, recipient, rentDuration, gamesCount);
        return tokenId;
    }

    /**
     * @dev Internal mint function
     */
    function _mintShip(
        address recipient, 
        ShipType shipType, 
        Rarity rarity, 
        uint256 variantId,
        bool isRental
    ) internal returns (uint256 tokenId) {
        require(recipient != address(0), "ShipNFTManager: Cannot mint to zero address");
        require(variantId < nextVariantId, "ShipNFTManager: Variant does not exist");
        
        ShipVariant memory variant = variants[variantId];
        require(variant.isActive, "ShipNFTManager: Variant not active");
        
        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        
        // Set token properties
        tokenRarities[tokenId] = rarity;
        shipTypes[tokenId] = shipType;
        shipVariants[tokenId] = variantId;
        shipIsDestroyed[tokenId] = false;
        
        // Generate stats
        shipStats[tokenId] = _generateShipStats(shipType, rarity, variantId);
        shipCrewCapacity[tokenId] = _calculateCrewCapacity(shipType, rarity);
        
        emit ShipMinted(tokenId, recipient, shipType, rarity, variantId);
        return tokenId;
    }

    // =============================================================================
    // SVG GENERATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Generate placard SVG for ship NFT (trading card view)
     * @param tokenId Token ID to generate placard for
     * @return svg Complete placard SVG string
     */
    function generatePlacardSVG(uint256 tokenId) external view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: Token does not exist");
        
        ShipType shipType = shipTypes[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ShipStats memory stats = shipStats[tokenId];
        uint256 variantId = shipVariants[tokenId];
        ShipVariant memory variant = variants[variantId];
        
        return _buildPlacardSVG(tokenId, shipType, variant, rarity, stats);
    }

    /**
     * @dev Generate grid SVG for ship NFT (in-game grid view)
     * @param tokenId Token ID to generate grid SVG for
     * @return svg Complete grid SVG string
     */
    function generateGridSVG(uint256 tokenId) external view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: Token does not exist");
        
        ShipType shipType = shipTypes[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ShipStats memory stats = shipStats[tokenId];
        uint256 variantId = shipVariants[tokenId];
        ShipVariant memory variant = variants[variantId];
        
        return _buildGridSVG(tokenId, shipType, variant, rarity, stats);
    }

    /**
     * @dev Build placard SVG with stats and artwork
     */
    function _buildPlacardSVG(
        uint256 tokenId,
        ShipType shipType,
        ShipVariant memory variant,
        Rarity rarity,
        ShipStats memory stats
    ) internal view returns (string memory) {
        string memory colors = svgThemeColors[variant.svgThemeId];
        string memory rarityColor = _getRarityColor(rarity);
        
        return string(abi.encodePacked(
            '<svg width="300" height="420" xmlns="http://www.w3.org/2000/svg">',
            '<defs><style>.text{font-family:Arial,sans-serif;font-weight:bold;}</style></defs>',
            '<rect width="300" height="420" fill="#0a0e27" stroke="', rarityColor, '" stroke-width="3"/>',
            
            // Header with ship name and type
            '<rect x="10" y="10" width="280" height="60" fill="', rarityColor, '" opacity="0.8"/>',
            '<text x="150" y="35" text-anchor="middle" fill="white" class="text" font-size="16">', _getShipName(shipType), '</text>',
            '<text x="150" y="55" text-anchor="middle" fill="white" class="text" font-size="12">', _getRarityName(rarity), ' ', variant.name, '</text>',
            
            // Ship artwork area
            '<rect x="20" y="80" width="260" height="180" fill="#1a1a2e" stroke="#444"/>',
            _generateShipArtwork(shipType, variant, rarityColor),
            
            // Stats section
            '<rect x="10" y="270" width="280" height="140" fill="#333" stroke="', rarityColor, '"/>',
            '<text x="20" y="290" fill="white" class="text" font-size="12">Health: ', _toString(stats.health), '</text>',
            '<text x="160" y="290" fill="white" class="text" font-size="12">Speed: ', _toString(stats.speed), '</text>',
            '<text x="20" y="310" fill="white" class="text" font-size="12">Shields: ', _toString(stats.shields), '</text>',
            '<text x="160" y="310" fill="white" class="text" font-size="12">Size: ', _toString(stats.size), '</text>',
            '<text x="20" y="330" fill="white" class="text" font-size="12">Firepower: ', _toString(stats.firepower), '</text>',
            '<text x="160" y="330" fill="white" class="text" font-size="12">Range: ', _toString(stats.range), '</text>',
            '<text x="20" y="350" fill="white" class="text" font-size="12">Armor: ', _toString(stats.armor), '</text>',
            '<text x="160" y="350" fill="white" class="text" font-size="12">Stealth: ', _toString(stats.stealth), '</text>',
            '<text x="20" y="380" fill="white" class="text" font-size="12">Crew Capacity: ', _toString(shipCrewCapacity[tokenId]), '</text>',
            
            '</svg>'
        ));
    }

    /**
     * @dev Build grid SVG for in-game use
     */
    function _buildGridSVG(
        uint256 tokenId,
        ShipType shipType,
        ShipVariant memory variant,
        Rarity rarity,
        ShipStats memory stats
    ) internal view returns (string memory) {
        string memory colors = svgThemeColors[variant.svgThemeId];
        
        // Simple grid representation - scaled for game board
        return string(abi.encodePacked(
            '<svg width="', _toString(stats.size * 40), '" height="40" xmlns="http://www.w3.org/2000/svg">',
            '<rect width="100%" height="100%" fill="#2a2a3e" stroke="#666"/>',
            _generateGridShipShape(shipType, stats.size, colors),
            '</svg>'
        ));
    }

    // =============================================================================
    // SHIP MANAGEMENT FUNCTIONS
    // =============================================================================

    /**
     * @dev Destroy a ship (used by game contract)
     * @param tokenId Ship to destroy
     */
    function destroyShip(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: Ship does not exist");
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(), 
            "ShipNFTManager: Not authorized to destroy"
        );
        
        address owner_addr = ownerOf(tokenId);
        shipIsDestroyed[tokenId] = true;
        
        // If it's a rental, burn it
        if (shipRentals[tokenId].isRental) {
            _burn(tokenId);
        }
        
        emit ShipDestroyed(tokenId, owner_addr);
    }

    /**
     * @dev Repair a destroyed ship (admin only)
     * @param tokenId Ship to repair
     */
    function repairShip(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: Ship does not exist");
        require(shipIsDestroyed[tokenId], "ShipNFTManager: Ship not destroyed");
        
        shipIsDestroyed[tokenId] = false;
        emit ShipRepaired(tokenId, ownerOf(tokenId));
    }

    /**
     * @dev Check if ship can be used in game
     * @param tokenId Ship to check
     * @return canUse True if ship can be used
     */
    function canUseShip(uint256 tokenId) external view returns (bool canUse) {
        if (_ownerOf(tokenId) == address(0)) return false;
        if (shipIsDestroyed[tokenId]) return false;
        
        // Check rental expiry
        RentalInfo memory rental = shipRentals[tokenId];
        if (rental.isRental) {
            if (block.timestamp > rental.rentedAt + rental.rentDuration) return false;
            if (rental.gamesRemaining == 0) return false;
        }
        
        return true;
    }

    /**
     * @dev Use rental game (decrements games remaining)
     * @param tokenId Rental ship to use
     */
    function useRentalGame(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: Ship does not exist");
        require(shipRentals[tokenId].isRental, "ShipNFTManager: Not a rental ship");
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(), 
            "ShipNFTManager: Not authorized"
        );
        
        RentalInfo storage rental = shipRentals[tokenId];
        require(rental.gamesRemaining > 0, "ShipNFTManager: No games remaining");
        
        rental.gamesRemaining--;
        
        // Burn if no games left
        if (rental.gamesRemaining == 0) {
            _burn(tokenId);
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get complete ship information
     * @param tokenId Ship to query
     * @return shipType Ship type
     * @return rarity Ship rarity
     * @return stats Ship statistics
     * @return variantId Variant ID
     * @return isDestroyed Whether ship is destroyed
     * @return crewCapacity Crew capacity
     */
    function getShipInfo(uint256 tokenId) 
        external 
        view 
        returns (
            ShipType shipType,
            Rarity rarity,
            ShipStats memory stats,
            uint256 variantId,
            bool isDestroyed,
            uint256 crewCapacity
        ) 
    {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: Ship does not exist");
        
        return (
            shipTypes[tokenId],
            tokenRarities[tokenId],
            shipStats[tokenId],
            shipVariants[tokenId],
            shipIsDestroyed[tokenId],
            shipCrewCapacity[tokenId]
        );
    }

    /**
     * @dev Get ships owned by address
     * @param owner Address to query
     * @return tokenIds Array of owned ship token IDs
     */
    function getOwnedShips(address owner) external view returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    function _initializeDefaultVariants() internal {
        // Military Fleet variant
        variants[1] = ShipVariant({
            name: "Military Fleet",
            isActive: true,
            isRetired: false,
            seasonId: 0,
            svgThemeId: 1,
            hasAnimations: true,
            retiredAt: 0,
            statMods: VariantStatMods({
                healthMod: 0,
                speedMod: 0,
                shieldsMod: 0,
                firepowerMod: 1,
                rangeMod: 0,
                armorMod: 1,
                stealthMod: 0
            })
        });
        
        nextVariantId = 2;
        activeVariant = 1;
    }

    function _initializeSVGThemes() internal {
        svgThemeColors[1] = "4a5d3a,708238,8fbc8f"; // Military greens
        svgThemeNames[1] = "Military";
        svgThemeElements[1] = "angular,armor,tactical";
        
        svgThemeColors[2] = "8b4513,daa520,cd853f"; // Pirate browns/gold
        svgThemeNames[2] = "Pirate";
        svgThemeElements[2] = "skull,sails,treasure";
    }

    function _generateShipStats(ShipType shipType, Rarity rarity, uint256 variantId) internal view returns (ShipStats memory stats) {
        // Base stats by ship type
        if (shipType == ShipType.DESTROYER) {
            stats = ShipStats({health: 60, speed: 3, shields: 10, size: 2, firepower: 45, range: 4, armor: 15, stealth: 25});
        } else if (shipType == ShipType.SUBMARINE) {
            stats = ShipStats({health: 80, speed: 2, shields: 15, size: 3, firepower: 55, range: 5, armor: 20, stealth: 35});
        } else if (shipType == ShipType.CRUISER) {
            stats = ShipStats({health: 100, speed: 2, shields: 20, size: 3, firepower: 65, range: 5, armor: 25, stealth: 15});
        } else if (shipType == ShipType.BATTLESHIP) {
            stats = ShipStats({health: 140, speed: 1, shields: 30, size: 4, firepower: 85, range: 6, armor: 35, stealth: 5});
        } else { // CARRIER
            stats = ShipStats({health: 180, speed: 1, shields: 25, size: 5, firepower: 70, range: 7, armor: 30, stealth: 10});
        }
        
        // Apply rarity bonuses
        uint8 rarityBonus = uint8(rarity) + 1;
        stats.health += rarityBonus * 10;
        stats.firepower += rarityBonus * 5;
        stats.shields += rarityBonus * 2;
        
        // Apply variant modifiers
        ShipVariant memory variant = variants[variantId];
        stats.health = uint8(_applyMod(int16(stats.health), variant.statMods.healthMod));
        stats.speed = uint8(_applyMod(int16(stats.speed), variant.statMods.speedMod));
        stats.shields = uint8(_applyMod(int16(stats.shields), variant.statMods.shieldsMod));
        stats.firepower = uint8(_applyMod(int16(stats.firepower), variant.statMods.firepowerMod));
        stats.range = uint8(_applyMod(int16(stats.range), variant.statMods.rangeMod));
        stats.armor = uint8(_applyMod(int16(stats.armor), variant.statMods.armorMod));
        stats.stealth = uint8(_applyMod(int16(stats.stealth), variant.statMods.stealthMod));
    }

    function _applyMod(int16 baseStat, int8 modifier) internal pure returns (int16) {
        int16 result = baseStat + int16(modifier);
        return result < 0 ? int16(0) : result;
    }

    function _calculateCrewCapacity(ShipType shipType, Rarity rarity) internal pure returns (uint256) {
        uint256 baseCapacity;
        if (shipType == ShipType.DESTROYER) baseCapacity = 2;
        else if (shipType == ShipType.SUBMARINE) baseCapacity = 3;
        else if (shipType == ShipType.CRUISER) baseCapacity = 4;
        else if (shipType == ShipType.BATTLESHIP) baseCapacity = 6;
        else baseCapacity = 8; // CARRIER
        
        // Rarity bonus
        return baseCapacity + uint256(rarity);
    }

    function _getShipName(ShipType shipType) internal pure returns (string memory) {
        if (shipType == ShipType.DESTROYER) return "Destroyer";
        if (shipType == ShipType.SUBMARINE) return "Submarine";
        if (shipType == ShipType.CRUISER) return "Cruiser";
        if (shipType == ShipType.BATTLESHIP) return "Battleship";
        return "Carrier";
    }

    function _getRarityColor(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.COMMON) return "#808080";
        if (rarity == Rarity.UNCOMMON) return "#00ff00";
        if (rarity == Rarity.RARE) return "#0080ff";
        if (rarity == Rarity.EPIC) return "#8000ff";
        return "#ff8000"; // LEGENDARY
    }

    function _getRarityName(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.COMMON) return "Common";
        if (rarity == Rarity.UNCOMMON) return "Uncommon";
        if (rarity == Rarity.RARE) return "Rare";
        if (rarity == Rarity.EPIC) return "Epic";
        return "Legendary";
    }

    function _generateShipArtwork(ShipType shipType, ShipVariant memory variant, string memory rarityColor) internal pure returns (string memory) {
        // Generate ship silhouette based on type
        return string(abi.encodePacked(
            '<g transform="translate(150, 170)">',
            '<rect x="-60" y="-20" width="120" height="40" fill="', rarityColor, '" opacity="0.8" rx="5"/>',
            '<circle cx="0" cy="0" r="15" fill="#fff" opacity="0.9"/>',
            '<text x="0" y="5" text-anchor="middle" fill="#000" font-size="12">⚓</text>',
            '</g>'
        ));
    }

    function _generateGridShipShape(ShipType shipType, uint8 size, string memory colors) internal pure returns (string memory) {
        string memory shipColor = "#4a5d3a"; // Extract first color from theme
        
        string memory shapes = "";
        for (uint8 i = 0; i < size; i++) {
            shapes = string(abi.encodePacked(
                shapes,
                '<rect x="', _toString(i * 40 + 5), '" y="5" width="30" height="30" fill="', shipColor, '" stroke="#fff" stroke-width="1"/>'
            ));
        }
        
        return shapes;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        return Strings.toString(value);
    }

    // =============================================================================
    // REQUIRED OVERRIDES
    // =============================================================================

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ShipNFTManager: URI query for nonexistent token");
        
        string memory placardSVG = this.generatePlacardSVG(tokenId);
        string memory shipName = _getShipName(shipTypes[tokenId]);
        
        // Return base64 encoded JSON metadata with embedded SVG
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(string(abi.encodePacked(
                '{"name":"', shipName, 
                '","description":"A powerful ', shipName, ' ready for battle",',
                '"image":"data:image/svg+xml;base64,', _base64Encode(bytes(placardSVG)), '"}'
            ))))
        ));
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        // Simplified base64 encoding - in production use a proper library
        return "placeholder_base64";
    }
}