// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./STANDARDS.sol";

/**
 * @title NFTManager
 * @dev Unified NFT contract managing Ships, Actions, Captains, and Crew
 * @notice This contract handles all NFT types in the CryptoBattleship ecosystem
 */
contract NFTManager is ERC721, ERC721Enumerable, Ownable, Pausable, ReentrancyGuard, INFTManager {
    using Strings for uint256;

    // =============================================================================
    // SECTION 4.1: MULTI-NFT CONTRACT STRUCTURE
    // =============================================================================

    /**
     * @dev NFT Type enumeration
     */
    enum TokenType {
        SHIP,      // 0: Permanent battle units
        ACTION,    // 1: Consumable action cards  
        CAPTAIN,   // 2: Fleet-wide ability providers
        CREW       // 3: Individual ship enhancers
    }

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
     * @dev Action NFT categories
     */
    enum ActionCategory {
        OFFENSIVE,  // 0: Attack-based actions
        DEFENSIVE   // 1: Defense-based actions
    }

    /**
     * @dev Captain ability types
     */
    enum CaptainAbility {
        DAMAGE_BOOST,     // 0: Increases attack damage
        SPEED_BOOST,      // 1: Increases ship movement
        DEFENSE_BOOST,    // 2: Reduces incoming damage
        VISION_BOOST,     // 3: Reveals additional cells
        LUCK_BOOST        // 4: Improves critical hit chance
    }

    /**
     * @dev Crew specialization types
     */
    enum CrewType {
        GUNNER,     // 0: Increases attack damage
        ENGINEER,   // 1: Increases ship speed
        NAVIGATOR,  // 2: Improves movement efficiency
        MEDIC       // 3: Provides ship repair abilities
    }

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    // Token tracking
    uint256 private _nextTokenId = 1;
    mapping(uint256 => TokenType) public tokenTypes;
    mapping(uint256 => Rarity) public tokenRarities;
    
    // Type-specific counters for ID generation
    mapping(TokenType => uint256) public typeCounters;
    
    // Contract references
    IGameConfig public gameConfig;
    IBattleshipGame public battleshipGame;
    ILootboxSystem public lootboxSystem;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event NFTMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        TokenType tokenType,
        Rarity rarity
    );
    
    event NFTBurned(
        uint256 indexed tokenId,
        TokenType tokenType,
        address indexed owner
    );
    
    event ContractUpdated(string contractName, address newAddress);

    // =============================================================================
    // CONSTRUCTOR AND BASIC SETUP
    // =============================================================================

    /**
     * @dev Constructor initializes the NFT contract
     * @param _gameConfig Address of GameConfig contract
     */
    constructor(address _gameConfig) 
        ERC721("CryptoBattleship NFTs", "CBNFT") 
        Ownable(msg.sender)
    {
        require(_gameConfig != address(0), "NFTManager: Invalid GameConfig address");
        gameConfig = IGameConfig(_gameConfig);
        _initializeVariants();
        _initializeNFTSystems();
    }

    /**
     * @dev Function1: ERC721 base with token type tracking
     * Override required functions and add type tracking
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721Enumerable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Function2: Token type enumeration tracking
     * Get token type for any NFT ID
     * @param tokenId Token ID to check
     * @return tokenType Type of the token
     */
    function getTokenType(uint256 tokenId) external view returns (TokenType tokenType) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        return tokenTypes[tokenId];
    }

    /**
     * @dev Function3: Rarity system implementation
     * Get rarity for any NFT ID
     * @param tokenId Token ID to check  
     * @return rarity Rarity level of the token
     */
    function getTokenRarity(uint256 tokenId) external view returns (Rarity rarity) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        return tokenRarities[tokenId];
    }

    /**
     * @dev Function4: Usage tracking for consumable NFTs
     * Track usage counts for Action NFTs
     * @param tokenId Token ID to check
     * @return usesRemaining Number of uses remaining
     */
    function getTokenUsesRemaining(uint256 tokenId) external view returns (uint256 usesRemaining) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        require(tokenTypes[tokenId] == TokenType.ACTION, "NFTManager: Not an action NFT");
        
        // Will be implemented in Section 4.3
        return actionUsesRemaining[tokenId];
    }

    // =============================================================================
    // VARIANT SYSTEM INITIALIZATION
    // =============================================================================

    /**
     * @dev Initialize the 5 starting variants with balanced stats
     */
    function _initializeVariants() internal {
        // Military Fleet - Balanced tank variant
        variants[VARIANT_MILITARY] = ShipVariant({
            name: "Military Fleet",
            isActive: true,
            isRetired: false,
            seasonId: 0, // Available across all seasons
            svgThemeId: 1, // Military SVG theme
            hasAnimations: true,
            retiredAt: 0,
            boosterPoints: 0
        });
        variantStatMods[VARIANT_MILITARY] = VariantStatMods({
            healthMod: 2,    // +2 Health
            speedMod: -1,    // -1 Speed  
            firepowerMod: -1, // -1 Firepower
            sizeMod: 0       // No size change
        });

        // Pirate Armada - Balanced aggressive variant
        variants[VARIANT_PIRATE] = ShipVariant({
            name: "Pirate Armada",
            isActive: true,
            isRetired: false,
            seasonId: 0,
            svgThemeId: 2, // Pirate SVG theme
            hasAnimations: true,
            retiredAt: 0,
            boosterPoints: 0
        });
        variantStatMods[VARIANT_PIRATE] = VariantStatMods({
            healthMod: -1,   // -1 Health
            speedMod: 1,     // +1 Speed
            firepowerMod: 0, // No firepower change  
            sizeMod: 0       // No size change
        });

        // Undead Fleet - Balanced damage variant
        variants[VARIANT_UNDEAD] = ShipVariant({
            name: "Undead Fleet",
            isActive: true,
            isRetired: false,
            seasonId: 0,
            svgThemeId: 3, // Undead SVG theme
            hasAnimations: true,
            retiredAt: 0,
            boosterPoints: 0
        });
        variantStatMods[VARIANT_UNDEAD] = VariantStatMods({
            healthMod: 0,    // No health change
            speedMod: -1,    // -1 Speed
            firepowerMod: 1, // +1 Firepower
            sizeMod: 0       // No size change
        });

        // Steampunk Armada - Balanced speed variant
        variants[VARIANT_STEAMPUNK] = ShipVariant({
            name: "Steampunk Armada",
            isActive: true,
            isRetired: false,
            seasonId: 0,
            svgThemeId: 4, // Steampunk SVG theme
            hasAnimations: true,
            retiredAt: 0,
            boosterPoints: 0
        });
        variantStatMods[VARIANT_STEAMPUNK] = VariantStatMods({
            healthMod: -1,   // -1 Health
            speedMod: 2,     // +2 Speed
            firepowerMod: -1, // -1 Firepower
            sizeMod: 0       // No size change
        });

        // Alien Invasion - Balanced mystery variant
        variants[VARIANT_ALIEN] = ShipVariant({
            name: "Alien Invasion",
            isActive: true,
            isRetired: false,
            seasonId: 0,
            svgThemeId: 5, // Alien SVG theme
            hasAnimations: true,
            retiredAt: 0,
            boosterPoints: 0
        });
        variantStatMods[VARIANT_ALIEN] = VariantStatMods({
            healthMod: 1,    // +1 Health
            speedMod: 0,     // No speed change
            firepowerMod: -1, // -1 Firepower
            sizeMod: 0       // No size change
        });

        nextVariantId = 6; // Next variant will be ID 6

        emit VariantCreated(VARIANT_MILITARY, "Military Fleet");
        emit VariantCreated(VARIANT_PIRATE, "Pirate Armada");
        emit VariantCreated(VARIANT_UNDEAD, "Undead Fleet");
        emit VariantCreated(VARIANT_STEAMPUNK, "Steampunk Armada");
        emit VariantCreated(VARIANT_ALIEN, "Alien Invasion");
    }

    // =============================================================================
    // VARIANT MANAGEMENT FUNCTIONS
    // =============================================================================

    /**
     * @dev Create a new ship variant
     * @param name Variant name
     * @param seasonId Season this variant belongs to
     * @param svgThemeId SVG theme identifier for onchain artwork
     * @param hasAnimations Whether variant has animations
     * @param statMods Stat modifiers for this variant
     */
    function createVariant(
        string calldata name,
        uint256 seasonId,
        uint8 svgThemeId,
        bool hasAnimations,
        VariantStatMods calldata statMods
    ) external onlyOwner returns (uint256 variantId) {
        // Validate stat balance (sum should be 0 for balanced variants)
        int8 totalMods = statMods.healthMod + statMods.speedMod + 
                        statMods.firepowerMod + statMods.sizeMod;
        require(totalMods == 0, "NFTManager: Variant stats must be balanced");

        variantId = nextVariantId++;
        
        variants[variantId] = ShipVariant({
            name: name,
            isActive: true,
            isRetired: false,
            seasonId: seasonId,
            svgThemeId: svgThemeId,
            hasAnimations: hasAnimations,
            retiredAt: 0,
            boosterPoints: 0
        });
        
        variantStatMods[variantId] = statMods;
        
        emit VariantCreated(variantId, name);
        return variantId;
    }

    /**
     * @dev Retire a variant permanently (can never be minted again)
     * @param variantId Variant to retire
     * @param boosterPoints Extra stat points to add
     */
    function retireVariant(uint256 variantId, uint8 boosterPoints) 
        external 
        onlyOwner 
    {
        require(variants[variantId].isActive, "NFTManager: Variant not active");
        require(!variants[variantId].isRetired, "NFTManager: Already retired");
        require(boosterPoints <= 10, "NFTManager: Too many booster points");

        variants[variantId].isActive = false;
        variants[variantId].isRetired = true;
        variants[variantId].retiredAt = block.timestamp;
        variants[variantId].boosterPoints = boosterPoints;

        emit VariantRetired(variantId, boosterPoints);
    }

    /**
     * @dev Start a new season (3 months duration)
     * @param name Season name
     * @param activeVariantIds Which variants can be minted this season
     */
    function startSeason(
        string calldata name,
        uint256[] calldata activeVariantIds
    ) external onlyOwner returns (uint256 seasonId) {
        // End current season if active
        if (currentSeasonId > 0) {
            seasons[currentSeasonId].isActive = false;
            emit SeasonEnded(currentSeasonId);
        }

        seasonId = nextSeasonId++;
        currentSeasonId = seasonId;

        seasons[seasonId] = Season({
            seasonId: seasonId,
            name: name,
            startTime: block.timestamp,
            endTime: block.timestamp + 90 days, // 3 months
            activeVariants: activeVariantIds,
            isActive: true
        });

        // Validate all active variants exist and aren't retired
        for (uint256 i = 0; i < activeVariantIds.length; i++) {
            uint256 variantId = activeVariantIds[i];
            require(!variants[variantId].isRetired, "NFTManager: Cannot activate retired variant");
        }

        emit SeasonStarted(seasonId, name, activeVariantIds);
        return seasonId;
    }

    /**
     * @dev Check if a variant can currently be minted
     * @param variantId Variant to check
     * @return canMint Whether variant is mintable
     */
    function canMintVariant(uint256 variantId) public view returns (bool canMint) {
        ShipVariant memory variant = variants[variantId];
        
        // Must be active and not retired
        if (!variant.isActive || variant.isRetired) {
            return false;
        }

        // If no season active, only eternal variants (seasonId 0) can be minted
        if (currentSeasonId == 0) {
            return variant.seasonId == 0;
        }

        // Check if variant is in current season's active list
        Season memory season = seasons[currentSeasonId];
        if (!season.isActive || block.timestamp > season.endTime) {
            return false;
        }

        // Check if variant is in active list
        for (uint256 i = 0; i < season.activeVariants.length; i++) {
            if (season.activeVariants[i] == variantId) {
                return true;
            }
        }

        return false;
    }

    // =============================================================================
    // VARIANT SYSTEM VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get variant information
     * @param variantId Variant ID to query
     * @return variant Complete variant data
     */
    function getVariant(uint256 variantId) external view returns (ShipVariant memory variant) {
        return variants[variantId];
    }

    /**
     * @dev Get variant stat modifiers
     * @param variantId Variant ID to query
     * @return mods Stat modifiers for variant
     */
    function getVariantStatMods(uint256 variantId) external view returns (VariantStatMods memory mods) {
        return variantStatMods[variantId];
    }

    /**
     * @dev Get current season information
     * @return season Current season data
     */
    function getCurrentSeason() external view returns (Season memory season) {
        if (currentSeasonId > 0) {
            return seasons[currentSeasonId];
        }
        // Return empty season if none active
        return Season({
            seasonId: 0,
            name: "No Active Season",
            startTime: 0,
            endTime: 0,
            activeVariants: new uint256[](0),
            isActive: false
        });
    }

    /**
     * @dev Get all available variants for minting
     * @return variantIds Array of mintable variant IDs
     */
    function getAvailableVariants() external view returns (uint256[] memory variantIds) {
        uint256[] memory tempIds = new uint256[](nextVariantId);
        uint256 count = 0;

        for (uint256 i = 1; i < nextVariantId; i++) {
            if (canMintVariant(i)) {
                tempIds[count] = i;
                count++;
            }
        }

        // Create result array with exact size
        variantIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            variantIds[i] = tempIds[i];
        }
    }

    /**
     * @dev Get ship's variant information
     * @param tokenId Ship token ID
     * @return variantId Ship's variant ID
     * @return variantName Ship's variant name
     */
    function getShipVariant(uint256 tokenId) external view returns (uint256 variantId, string memory variantName) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Ship does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Not a ship NFT");
        
        variantId = shipVariants[tokenId];
        variantName = variants[variantId].name;
    }

    /**
     * @dev Get final ship stats including all modifiers
     * @param tokenId Ship token ID
     * @return stats Final calculated stats
     */
    function getFinalShipStats(uint256 tokenId) external view returns (ShipStats memory stats) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Ship does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Not a ship NFT");
        
        return shipStats[tokenId];
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
        require(newAddress != address(0), "NFTManager: Invalid address");
        
        bytes32 nameHash = keccak256(abi.encodePacked(contractName));
        
        if (nameHash == keccak256(abi.encodePacked("BattleshipGame"))) {
            battleshipGame = IBattleshipGame(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("LootboxSystem"))) {
            lootboxSystem = ILootboxSystem(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("GameConfig"))) {
            gameConfig = IGameConfig(newAddress);
        } else {
            revert("NFTManager: Unknown contract name");
        }
        
        emit ContractUpdated(contractName, newAddress);
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

    // =============================================================================
    // INTERNAL HELPER FUNCTIONS
    // =============================================================================

    /**
     * @dev Generate next token ID and track type
     * @param tokenType Type of token being minted
     * @return tokenId Generated token ID
     */
    function _generateTokenId(TokenType tokenType) internal returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        _nextTokenId++;
        
        tokenTypes[tokenId] = tokenType;
        typeCounters[tokenType]++;
        
        return tokenId;
    }

    /**
     * @dev Override _beforeTokenTransfer to add pause functionality
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // =============================================================================
    // VIEW FUNCTIONS FOR TYPE STATISTICS
    // =============================================================================

    /**
     * @dev Get total supply by token type
     * @param tokenType Type to check
     * @return count Total tokens of this type
     */
    function getTypeSupply(TokenType tokenType) external view returns (uint256 count) {
        return typeCounters[tokenType];
    }

    /**
     * @dev Get tokens owned by address filtered by type
     * @param owner Address to check
     * @param tokenType Type to filter by
     * @return tokenIds Array of token IDs
     */
    function getTokensByTypeAndOwner(address owner, TokenType tokenType) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        uint256 balance = balanceOf(owner);
        uint256[] memory tempIds = new uint256[](balance);
        uint256 resultCount = 0;
        
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            if (tokenTypes[tokenId] == tokenType) {
                tempIds[resultCount] = tokenId;
                resultCount++;
            }
        }
        
        // Create result array with exact size
        tokenIds = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            tokenIds[i] = tempIds[i];
        }
    }

    // =============================================================================
    // SECTION 4.6: SVG AND METADATA SYSTEM
    // =============================================================================

    // SVG version for cache invalidation
    uint8 public svgVersion = 1;
    
    // SVG theme colors and elements (placeholder system)
    mapping(uint8 => string) private svgThemeColors;
    mapping(uint8 => string) private svgThemeNames;
    mapping(uint8 => string) private svgThemeElements;
    
    // Events for metadata system
    event SVGVersionUpdated(uint8 newVersion);
    event MetadataUpdated(uint256 indexed tokenId, string newTokenURI);

    /**
     * @dev Initialize SVG themes with placeholder designs
     */
    function _initializeSVGThemes() internal {
        // Military Fleet - Gray/Green, Angular
        svgThemeColors[1] = "4a5d3a,708238,8fbc8f"; // Military greens
        svgThemeNames[1] = "Military";
        svgThemeElements[1] = "angular,armor,tactical";
        
        // Pirate Armada - Brown/Gold, Nautical  
        svgThemeColors[2] = "8b4513,daa520,cd853f"; // Browns and gold
        svgThemeNames[2] = "Pirate";
        svgThemeElements[2] = "skull,sails,treasure";
        
        // Undead Fleet - Dark Purple/Green, Spooky
        svgThemeColors[3] = "4b0082,800080,32cd32"; // Dark purples and sickly green
        svgThemeNames[3] = "Undead";
        svgThemeElements[3] = "bones,mist,decay";
        
        // Steampunk Armada - Bronze/Copper, Mechanical
        svgThemeColors[4] = "cd7f32,b87333,d2691e"; // Bronze and copper tones
        svgThemeNames[4] = "Steampunk";
        svgThemeElements[4] = "gears,steam,pipes";
        
        // Alien Invasion - Purple/Cyan, Sci-fi
        svgThemeColors[5] = "9932cc,00ced1,7b68ee"; // Alien purples and cyans
        svgThemeNames[5] = "Alien";
        svgThemeElements[5] = "energy,crystal,tech";
    }

    /**
     * @dev Function1: SVG generation with variant themes
     * Generate SVG artwork based on ship type, variant, and rarity
     * @param tokenId Token ID to generate SVG for
     * @return svg Complete SVG string
     */
    function generateSVG(uint256 tokenId) public view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Only ships have SVG");
        
        uint256 variantId = shipVariants[tokenId];
        ShipType shipType = shipTypes[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ShipStats memory stats = shipStats[tokenId];
        ShipVariant memory variant = variants[variantId];
        
        return _buildSVG(shipType, variant, rarity, stats, tokenId);
    }

    /**
     * @dev Function2: Build SVG with theme-based styling
     * Internal function to construct the actual SVG
     */
    function _buildSVG(
        ShipType shipType,
        ShipVariant memory variant,
        Rarity rarity,
        ShipStats memory stats,
        uint256 tokenId
    ) internal view returns (string memory) {
        string memory colors = svgThemeColors[variant.svgThemeId];
        string memory themeName = svgThemeNames[variant.svgThemeId];
        
        // Extract colors (simple parsing for placeholder)
        string memory primaryColor = _extractColor(colors, 0);
        string memory secondaryColor = _extractColor(colors, 1);
        string memory accentColor = _extractColor(colors, 2);
        
        // Build ship shape based on type
        string memory shipShape = _getShipShape(shipType, primaryColor, secondaryColor);
        
        // Add theme elements
        string memory themeElements = _getThemeElements(variant.svgThemeId, accentColor);
        
        // Add rarity effects
        string memory rarityEffects = _getRarityEffects(rarity);
        
        // Add animations if supported (using extensible system)
        string memory animations = variant.hasAnimations ? _getAnimationsExtended(variant.svgThemeId) : "";
        
        // Add dynamic visual enhancements
        string memory dynamicEffects = getEnhancedVisualEffects(tokenId);
        
        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs><style>.ship-text{font-family:Arial,sans-serif;font-weight:bold;}</style></defs>',
            '<rect width="400" height="400" fill="#000814"/>',
            dynamicEffects,
            '<g transform="translate(200,200)">',
            shipShape,
            themeElements,
            rarityEffects,
            animations,
            '</g>',
            '<text x="20" y="30" class="ship-text" fill="white" font-size="14">',
            variant.name,
            '</text>',
            '<text x="20" y="370" class="ship-text" fill="white" font-size="12">',
            _getShipTypeName(shipType),
            ' | ',
            _getRarityName(rarity),
            '</text>',
            '<text x="20" y="385" class="ship-text" fill="white" font-size="10">',
            'HP:', _toString(stats.health),
            ' SPD:', _toString(stats.speed),
            ' ATK:', _toString(stats.firepower),
            '</text>',
            '</svg>'
        ));
    }

    /**
     * @dev Function3: Generate metadata JSON
     * Create complete NFT metadata including all attributes
     * @param tokenId Token ID to generate metadata for
     * @return json Complete metadata JSON string
     */
    function generateMetadata(uint256 tokenId) public view returns (string memory json) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        
        TokenType tokenType = tokenTypes[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        
        if (tokenType == TokenType.SHIP) {
            return _generateShipMetadata(tokenId);
        } else if (tokenType == TokenType.ACTION) {
            return _generateActionMetadata(tokenId);
        } else if (tokenType == TokenType.CAPTAIN) {
            return _generateCaptainMetadata(tokenId);
        } else if (tokenType == TokenType.CREW) {
            return _generateCrewMetadata(tokenId);
        }
        
        revert("NFTManager: Unknown token type");
    }

    /**
     * @dev Function4: Complete tokenURI implementation
     * ERC721 tokenURI function returning base64 encoded JSON
     * @param tokenId Token ID to get URI for
     * @return uri Complete data URI with metadata and SVG
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: URI query for nonexistent token");
        
        string memory json = generateMetadata(tokenId);
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(json))
        ));
    }

    // =============================================================================
    // SVG HELPER FUNCTIONS
    // =============================================================================

    /**
     * @dev Extract color from comma-separated color string
     */
    function _extractColor(string memory colors, uint8 index) internal pure returns (string memory) {
        // Simple placeholder - returns first color for all indices
        // In production, would properly parse comma-separated values
        bytes memory colorBytes = bytes(colors);
        if (colorBytes.length >= 6) {
            if (index == 0) return string(abi.encodePacked("#", _substring(colors, 0, 6)));
            if (index == 1) return string(abi.encodePacked("#", _substring(colors, 7, 6)));
            if (index == 2) return string(abi.encodePacked("#", _substring(colors, 14, 6)));
        }
        return "#ffffff"; // Fallback
    }

    /**
     * @dev Get ship shape SVG based on type
     */
    function _getShipShape(ShipType shipType, string memory primaryColor, string memory secondaryColor) 
        internal pure returns (string memory) {
        if (shipType == ShipType.DESTROYER) {
            return string(abi.encodePacked(
                '<rect x="-60" y="-20" width="120" height="40" fill="', primaryColor, '"/>',
                '<polygon points="-60,-20 -80,-10 -80,10 -60,20" fill="', secondaryColor, '"/>',
                '<polygon points="60,-20 80,-10 80,10 60,20" fill="', secondaryColor, '"/>'
            ));
        } else if (shipType == ShipType.SUBMARINE) {
            return string(abi.encodePacked(
                '<ellipse cx="0" cy="0" rx="70" ry="25" fill="', primaryColor, '"/>',
                '<rect x="-10" y="-40" width="20" height="30" fill="', secondaryColor, '"/>'
            ));
        } else if (shipType == ShipType.CRUISER) {
            return string(abi.encodePacked(
                '<rect x="-70" y="-25" width="140" height="50" fill="', primaryColor, '"/>',
                '<rect x="-15" y="-50" width="30" height="25" fill="', secondaryColor, '"/>',
                '<polygon points="-70,-25 -90,-10 -90,10 -70,25" fill="', secondaryColor, '"/>'
            ));
        } else if (shipType == ShipType.BATTLESHIP) {
            return string(abi.encodePacked(
                '<rect x="-80" y="-30" width="160" height="60" fill="', primaryColor, '"/>',
                '<rect x="-20" y="-55" width="40" height="25" fill="', secondaryColor, '"/>',
                '<rect x="-40" y="-55" width="20" height="25" fill="', secondaryColor, '"/>',
                '<rect x="20" y="-55" width="20" height="25" fill="', secondaryColor, '"/>'
            ));
        } else { // CARRIER
            return string(abi.encodePacked(
                '<rect x="-90" y="-35" width="180" height="70" fill="', primaryColor, '"/>',
                '<rect x="-80" y="-60" width="160" height="25" fill="', secondaryColor, '"/>',
                '<rect x="-10" y="-85" width="20" height="25" fill="', secondaryColor, '"/>'
            ));
        }
    }

    /**
     * @dev Get theme-specific decorative elements
     */
    function _getThemeElements(uint8 svgThemeId, string memory accentColor) 
        internal pure returns (string memory) {
        if (svgThemeId == 1) { // Military
            return string(abi.encodePacked(
                '<rect x="-5" y="-5" width="10" height="10" fill="', accentColor, '"/>',
                '<text x="0" y="35" text-anchor="middle" fill="', accentColor, '" font-size="12">⚡</text>'
            ));
        } else if (svgThemeId == 2) { // Pirate
            return string(abi.encodePacked(
                '<text x="0" y="35" text-anchor="middle" fill="', accentColor, '" font-size="16">☠</text>',
                '<circle cx="-50" cy="-10" r="3" fill="', accentColor, '"/>'
            ));
        } else if (svgThemeId == 3) { // Undead
            return string(abi.encodePacked(
                '<text x="0" y="35" text-anchor="middle" fill="', accentColor, '" font-size="14">💀</text>',
                '<circle cx="0" cy="0" r="40" fill="none" stroke="', accentColor, '" opacity="0.3"/>'
            ));
        } else if (svgThemeId == 4) { // Steampunk
            return string(abi.encodePacked(
                '<circle cx="0" cy="0" r="8" fill="none" stroke="', accentColor, '" stroke-width="2"/>',
                '<text x="0" y="35" text-anchor="middle" fill="', accentColor, '" font-size="12">⚙</text>'
            ));
        } else { // Alien
            return string(abi.encodePacked(
                '<polygon points="0,-15 10,5 -10,5" fill="', accentColor, '" opacity="0.7"/>',
                '<circle cx="0" cy="-40" r="5" fill="', accentColor, '"/>'
            ));
        }
    }

    /**
     * @dev Get rarity effects (glows, borders, etc.)
     */
    function _getRarityEffects(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.LEGENDARY) {
            return '<circle cx="0" cy="0" r="100" fill="none" stroke="#ffd700" stroke-width="3" opacity="0.6"/>';
        } else if (rarity == Rarity.EPIC) {
            return '<circle cx="0" cy="0" r="95" fill="none" stroke="#9932cc" stroke-width="2" opacity="0.5"/>';
        } else if (rarity == Rarity.RARE) {
            return '<circle cx="0" cy="0" r="90" fill="none" stroke="#00bfff" stroke-width="1" opacity="0.4"/>';
        }
        return ""; // Common and Uncommon have no effects
    }

    /**
     * @dev Get animation elements for ship variants
     * Complete animation system for all current and future variants
     */
    function _getAnimations(uint8 svgThemeId) internal pure returns (string memory) {
        if (svgThemeId == 1) { // Military Fleet - radar sweep
            return string(abi.encodePacked(
                '<g id="radar">',
                '<circle cx="0" cy="0" r="80" fill="none" stroke="#00ff00" stroke-width="2" opacity="0.6">',
                '<animate attributeName="r" values="20;80;20" dur="4s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.8;0.2;0.8" dur="4s" repeatCount="indefinite"/>',
                '</circle>',
                '<line x1="0" y1="0" x2="0" y2="-80" stroke="#00ff00" stroke-width="2" opacity="0.8">',
                '<animateTransform attributeName="transform" type="rotate" values="0;360" dur="6s" repeatCount="indefinite"/>',
                '</line>',
                '</g>'
            ));
        } else if (svgThemeId == 2) { // Pirate - flag wave & treasure glow
            return string(abi.encodePacked(
                '<g id="pirate-effects">',
                '<rect x="-5" y="-60" width="10" height="20" fill="#8B0000">',
                '<animateTransform attributeName="transform" type="skewX" values="0;5;0;-5;0" dur="3s" repeatCount="indefinite"/>',
                '</rect>',
                '<circle cx="40" cy="30" r="3" fill="#FFD700">',
                '<animate attributeName="opacity" values="0.5;1;0.5" dur="2s" repeatCount="indefinite"/>',
                '<animate attributeName="r" values="2;4;2" dur="2s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>'
            ));
        } else if (svgThemeId == 3) { // Undead Fleet - ghostly aura & soul wisps
            return string(abi.encodePacked(
                '<g id="undead-effects">',
                '<circle cx="0" cy="0" r="90" fill="none" stroke="#800080" stroke-width="2" opacity="0.4">',
                '<animate attributeName="opacity" values="0.2;0.6;0.2" dur="5s" repeatCount="indefinite"/>',
                '<animate attributeName="stroke-width" values="1;3;1" dur="5s" repeatCount="indefinite"/>',
                '</circle>',
                '<g>',
                '<circle cx="-40" cy="-20" r="2" fill="#9370DB">',
                '<animate attributeName="cy" values="-20;-40;-20" dur="3s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.8;0.3;0.8" dur="3s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="35" cy="15" r="2" fill="#9370DB">',
                '<animate attributeName="cy" values="15;-5;15" dur="4s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.6;0.2;0.6" dur="4s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>',
                '</g>'
            ));
        } else if (svgThemeId == 4) { // Steampunk - gear rotation & steam
            return string(abi.encodePacked(
                '<g id="steampunk-effects">',
                '<circle cx="0" cy="0" r="8" fill="none" stroke="#CD7F32" stroke-width="2">',
                '<animateTransform attributeName="transform" type="rotate" values="0;360" dur="8s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="20" cy="-15" r="4" fill="none" stroke="#CD7F32" stroke-width="1">',
                '<animateTransform attributeName="transform" type="rotate" values="360;0" dur="6s" repeatCount="indefinite"/>',
                '</circle>',
                '<g id="steam">',
                '<circle cx="-10" cy="-30" r="3" fill="#ffffff" opacity="0.6">',
                '<animate attributeName="cy" values="-30;-50;-30" dur="2s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.6;0.1;0.6" dur="2s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="5" cy="-25" r="2" fill="#ffffff" opacity="0.5">',
                '<animate attributeName="cy" values="-25;-45;-25" dur="2.5s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.5;0.1;0.5" dur="2.5s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>',
                '</g>'
            ));
        } else if (svgThemeId == 5) { // Alien Invasion - energy pulses & probe lights
            return string(abi.encodePacked(
                '<g id="alien-effects">',
                '<circle cx="0" cy="0" r="60" fill="none" stroke="#00FFFF" stroke-width="2" opacity="0.5">',
                '<animate attributeName="r" values="30;90;30" dur="3s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.7;0.2;0.7" dur="3s" repeatCount="indefinite"/>',
                '</circle>',
                '<g id="probe-lights">',
                '<circle cx="-30" cy="0" r="2" fill="#00FFFF">',
                '<animate attributeName="opacity" values="1;0.3;1" dur="1s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="30" cy="0" r="2" fill="#00FFFF">',
                '<animate attributeName="opacity" values="0.3;1;0.3" dur="1s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="0" cy="-30" r="2" fill="#00FFFF">',
                '<animate attributeName="opacity" values="1;0.3;1" dur="0.8s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>',
                '</g>'
            ));
        }
        return ""; // No animation for undefined themes
    }

    mapping(uint256 => CrewType) internal crewTypes;
    mapping(uint256 => uint256) internal crewStamina;

    // =============================================================================
    // SECTION 4.2: SHIP NFT IMPLEMENTATION  
    // =============================================================================

    /**
     * @dev Ship stats and characteristics
     */
    struct ShipStats {
        uint8 size;        // Grid cells occupied (2-5)
        uint8 speed;       // Movement range (1-3)
        uint8 health;      // Hit points before destruction
        uint8 firepower;   // Base damage multiplier
    }

    /**
     * @dev Ship variant definition
     */
    struct ShipVariant {
        string name;           // "Undead Fleet", "Pirate Armada", etc.
        bool isActive;         // Can still be minted
        bool isRetired;        // Permanently retired (never mintable again)
        uint256 seasonId;      // Which season it belongs to
        uint8 svgThemeId;      // SVG theme identifier for onchain artwork
        bool hasAnimations;    // Whether this variant has animations
        uint256 retiredAt;     // Timestamp when retired
        uint8 boosterPoints;   // Extra stat points added after retirement
    }

    /**
     * @dev Variant stat modifiers (balanced - same total points)
     */
    struct VariantStatMods {
        int8 healthMod;        // Modifier to base health (-2 to +2)
        int8 speedMod;         // Modifier to base speed  
        int8 firepowerMod;     // Modifier to base firepower
        int8 sizeMod;          // Usually 0, but could vary
    }

    /**
     * @dev Season management
     */
    struct Season {
        uint256 seasonId;
        string name;           // "Haunted Seas", "Golden Age of Piracy", etc.
        uint256 startTime;
        uint256 endTime;
        uint256[] activeVariants; // Which variants can be minted this season
        bool isActive;
    }

    // Ship NFT storage
    mapping(uint256 => ShipStats) public shipStats;
    mapping(uint256 => uint256) public shipTraitSeeds; // For procedural traits
    mapping(uint256 => uint256) public shipVariants;   // tokenId => variantId
    
    // Ship destruction tracking
    mapping(uint256 => bool) public isShipDestroyed;
    
    // Variant system storage
    mapping(uint256 => ShipVariant) public variants;
    mapping(uint256 => VariantStatMods) public variantStatMods;
    mapping(uint256 => Season) public seasons;
    
    uint256 public nextVariantId = 1;
    uint256 public nextSeasonId = 1;
    uint256 public currentSeasonId = 0;
    
    // Constants for initial variants
    uint256 constant VARIANT_MILITARY = 1;
    uint256 constant VARIANT_PIRATE = 2;
    uint256 constant VARIANT_UNDEAD = 3;
    uint256 constant VARIANT_STEAMPUNK = 4;
    uint256 constant VARIANT_ALIEN = 5;
    
    // Events for ship lifecycle
    event ShipMinted(uint256 indexed tokenId, address indexed owner, ShipType shipType, uint256 variantId, Rarity rarity);
    event ShipDestroyed(uint256 indexed tokenId, address indexed owner);
    event ShipRepaired(uint256 indexed tokenId, address indexed owner);
    
    // Events for variant system
    event VariantCreated(uint256 indexed variantId, string name, uint8 svgThemeId);
    event VariantRetired(uint256 indexed variantId, uint8 boosterPoints);
    event SeasonStarted(uint256 indexed seasonId, string name, uint256[] activeVariants);
    event SeasonEnded(uint256 indexed seasonId);

    /**
     * @dev Function1: Ship type and stats storage
     * Get comprehensive ship information
     * @param tokenId Ship token ID
     * @return shipType Type of ship
     * @return stats Ship statistics
     * @return isRental Whether ship is a rental
     * @return destroyed Whether ship is destroyed
     */
    function getShipInfo(uint256 tokenId) 
        external 
        view 
        returns (
            ShipType shipType,
            ShipStats memory stats,
            bool isRental,
            bool destroyed
        ) 
    {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Ship does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Not a ship NFT");
        
        shipType = shipTypes[tokenId];
        stats = shipStats[tokenId];
        isRental = shipRentalFlags[tokenId];
        destroyed = isShipDestroyed[tokenId];
    }

    /**
     * @dev Function2: Ship minting with random traits and variant selection
     * Mint new ship NFT with procedurally generated traits
     * @param recipient Address to receive the ship
     * @param shipType Type of ship to mint
     * @param variantId Variant to mint (0 for random active variant)
     * @param rarity Rarity level of the ship
     * @return tokenId Minted token ID
     */
    function mintShip(address recipient, ShipType shipType, uint256 variantId, Rarity rarity) 
        external 
        returns (uint256 tokenId) 
    {
        // Only allow minting from authorized contracts
        require(
            msg.sender == address(lootboxSystem) || 
            msg.sender == owner() ||
            msg.sender == address(this), // For rental ships
            "NFTManager: Not authorized to mint ships"
        );
        
        // If variantId is 0, select random active variant
        if (variantId == 0) {
            variantId = _selectRandomActiveVariant();
        }
        
        // Validate variant can be minted
        require(canMintVariant(variantId), "NFTManager: Variant not available for minting");
        
        tokenId = _generateTokenId(TokenType.SHIP);
        tokenRarities[tokenId] = rarity;
        shipTypes[tokenId] = shipType;
        shipVariants[tokenId] = variantId;
        
        // Generate ship stats based on type, rarity, and variant
        shipStats[tokenId] = _generateShipStats(shipType, rarity, variantId);
        
        // Generate trait seed for visual characteristics
        shipTraitSeeds[tokenId] = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            tokenId,
            recipient,
            variantId
        )));
        
        _safeMint(recipient, tokenId);
        
        emit ShipMinted(tokenId, recipient, shipType, variantId, rarity);
        emit NFTMinted(tokenId, recipient, TokenType.SHIP, rarity);
    }
    
    /**
     * @dev Overloaded function for backward compatibility (defaults to random variant)
     */
    function mintShip(address recipient, ShipType shipType, Rarity rarity) 
        external 
        returns (uint256 tokenId) 
    {
        return this.mintShip(recipient, shipType, 0, rarity); // 0 = random variant
    }

    /**
     * @dev Function3: Ship destruction mechanics
     * Destroy a ship (marks as destroyed, doesn't burn)
     * @param tokenId Ship token ID to destroy
     */
    function destroyShip(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Ship does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Not a ship NFT");
        require(
            msg.sender == address(battleshipGame) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to destroy ships"
        );
        require(!isShipDestroyed[tokenId], "NFTManager: Ship already destroyed");
        require(!shipRentalFlags[tokenId], "NFTManager: Cannot destroy rental ships");
        
        address shipOwner = ownerOf(tokenId);
        isShipDestroyed[tokenId] = true;
        
        emit ShipDestroyed(tokenId, shipOwner);
    }

    /**
     * @dev Function4: Ship rental flag handling
     * Create rental ship or toggle rental status
     * @param recipient Address to receive rental ship
     * @param shipType Type of rental ship
     * @return tokenId Rental ship token ID
     */
    function createRentalShip(address recipient, ShipType shipType) 
        external 
        returns (uint256 tokenId) 
    {
        require(
            msg.sender == address(lootboxSystem) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to create rental ships"
        );
        
        // Rental ships are always COMMON rarity
        tokenId = mintShip(recipient, shipType, Rarity.COMMON);
        shipRentalFlags[tokenId] = true;
        
        return tokenId;
    }

    /**
     * @dev Generate ship stats based on type, rarity, and variant
     * @param shipType Type of ship
     * @param rarity Rarity level
     * @param variantId Variant ID
     * @return stats Generated ship statistics
     */
    function _generateShipStats(ShipType shipType, Rarity rarity, uint256 variantId) 
        internal 
        view 
        returns (ShipStats memory stats) 
    {
        // Base stats by ship type
        if (shipType == ShipType.DESTROYER) {
            stats = ShipStats({size: 2, speed: 3, health: 2, firepower: 1});
        } else if (shipType == ShipType.SUBMARINE) {
            stats = ShipStats({size: 3, speed: 2, health: 3, firepower: 2});
        } else if (shipType == ShipType.CRUISER) {
            stats = ShipStats({size: 3, speed: 2, health: 3, firepower: 2});
        } else if (shipType == ShipType.BATTLESHIP) {
            stats = ShipStats({size: 4, speed: 1, health: 4, firepower: 3});
        } else if (shipType == ShipType.CARRIER) {
            stats = ShipStats({size: 5, speed: 1, health: 5, firepower: 1});
        }
        
        // Apply rarity bonuses
        uint8 rarityBonus = uint8(rarity); // 0-4 bonus
        
        stats.health += rarityBonus;
        stats.firepower += (rarityBonus + 1) / 2; // +1 every 2 rarity levels
        
        // Rare+ ships get speed bonus
        if (rarity >= Rarity.RARE) {
            stats.speed += 1;
        }
        
        // Apply variant modifiers and booster points
        VariantStatMods memory mods = variantStatMods[variantId];
        ShipVariant memory variant = variants[variantId];
        
        // Apply stat modifiers (can be negative)
        stats.health = uint8(int8(stats.health) + mods.healthMod);
        stats.speed = uint8(int8(stats.speed) + mods.speedMod);
        stats.firepower = uint8(int8(stats.firepower) + mods.firepowerMod);
        stats.size = uint8(int8(stats.size) + mods.sizeMod);
        
        // Apply booster points if variant is retired (distributed evenly)
        if (variant.isRetired && variant.boosterPoints > 0) {
            uint8 healthBoost = variant.boosterPoints / 3;
            uint8 speedBoost = variant.boosterPoints / 3;
            uint8 firepowerBoost = variant.boosterPoints / 3;
            uint8 remainder = variant.boosterPoints % 3;
            
            stats.health += healthBoost + (remainder > 0 ? 1 : 0);
            stats.speed += speedBoost + (remainder > 1 ? 1 : 0);
            stats.firepower += firepowerBoost;
        }
        
        // Ensure minimum stats (prevent underflow)
        if (stats.health == 0) stats.health = 1;
        if (stats.speed == 0) stats.speed = 1;
        if (stats.firepower == 0) stats.firepower = 1;
        if (stats.size < 2) stats.size = 2;
    }
    
    /**
     * @dev Select random active variant from available options
     * @return variantId Selected variant ID
     */
    function _selectRandomActiveVariant() internal view returns (uint256 variantId) {
        // Get list of active variants
        uint256[] memory activeVariants;
        
        if (currentSeasonId == 0) {
            // No season active, use eternal variants (seasonId 0)
            activeVariants = new uint256[](5); // All 5 starting variants
            uint256 count = 0;
            for (uint256 i = 1; i <= 5; i++) {
                if (canMintVariant(i)) {
                    activeVariants[count] = i;
                    count++;
                }
            }
            require(count > 0, "NFTManager: No active variants available");
            
            // Resize array to actual count
            uint256[] memory finalVariants = new uint256[](count);
            for (uint256 i = 0; i < count; i++) {
                finalVariants[i] = activeVariants[i];
            }
            activeVariants = finalVariants;
        } else {
            // Use current season's active variants
            activeVariants = seasons[currentSeasonId].activeVariants;
        }
        
        require(activeVariants.length > 0, "NFTManager: No variants available");
        
        // Generate pseudo-random index
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender
        ))) % activeVariants.length;
        
        return activeVariants[randomIndex];
    }

    /**
     * @dev Check if ship can be used in battle
     * @param tokenId Ship token ID
     * @return canUse Whether ship is usable
     */
    function canUseShip(uint256 tokenId) external view returns (bool canUse) {
        if (_ownerOf(tokenId) == address(0)) return false;
        if (tokenTypes[tokenId] != TokenType.SHIP) return false;
        if (isShipDestroyed[tokenId]) return false;
        
        return true;
    }

    /**
     * @dev Admin function to repair destroyed ships (emergency use)
     * @param tokenId Ship token ID to repair
     */
    function repairShip(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Ship does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Not a ship NFT");
        require(isShipDestroyed[tokenId], "NFTManager: Ship not destroyed");
        
        address shipOwner = ownerOf(tokenId);
        isShipDestroyed[tokenId] = false;
        
        emit ShipRepaired(tokenId, shipOwner);
    }

    /**
     * @dev Get all usable ships for a player
     * @param player Player address
     * @return tokenIds Array of usable ship token IDs
     */
    function getUsableShips(address player) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        uint256[] memory allShips = this.getTokensByTypeAndOwner(player, TokenType.SHIP);
        uint256[] memory tempIds = new uint256[](allShips.length);
        uint256 resultCount = 0;
        
        for (uint256 i = 0; i < allShips.length; i++) {
            if (this.canUseShip(allShips[i])) {
                tempIds[resultCount] = allShips[i];
                resultCount++;
            }
        }
        
                // Create result array with exact size
        tokenIds = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            tokenIds[i] = tempIds[i];
        }
    }

    /**
     * @dev Burn an NFT (used for protocol rentals)
     * @param tokenId Token ID to burn
     */
    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "NFTManager: Not approved to burn");
        
        TokenType tokenType = tokenTypes[tokenId];
        address owner = ownerOf(tokenId);
        
        // Clean up type-specific data
        if (tokenType == TokenType.SHIP) {
            delete shipStats[tokenId];
            delete shipVariants[tokenId];
            delete shipVisualData[tokenId];
            delete isShipDestroyed[tokenId];
        } else if (tokenType == TokenType.ACTION) {
            delete actionStats[tokenId];
            delete actionUsesRemaining[tokenId];
            delete actionVariants[tokenId];
        } else if (tokenType == TokenType.CAPTAIN) {
            delete captainAbilities[tokenId];
            delete captainBonusValues[tokenId];
        } else if (tokenType == TokenType.CREW) {
            delete crewTypes[tokenId];
            delete crewStamina[tokenId];
            delete crewBonusValues[tokenId];
        }
        
        // Clean up common data
        delete tokenTypes[tokenId];
        delete tokenRarities[tokenId];
        
        // Burn the token
        _burn(tokenId);
        
        emit NFTBurned(tokenId, tokenType, owner);
    }

    // =============================================================================
    // SECTION 4.4: CAPTAIN NFT IMPLEMENTATION
    // =============================================================================

    /**
     * @dev Captain variant definition (visual themes)
     */
    struct CaptainVariant {
        string name;           // "Undead Admiralty", "Pirate Lords", etc.
        bool isActive;         // Can still be minted
        bool isRetired;        // Permanently retired
        uint256 seasonId;      // Which season it belongs to
        uint8 portraitThemeId; // Portrait theme ID for visuals
        uint256 retiredAt;     // Timestamp when retired
    }

    /**
     * @dev Captain portrait template for unique combinations
     */
    struct CaptainPortrait {
        uint8 faceType;        // Face structure (0-9)
        uint8 eyeType;         // Eye style (0-7)
        uint8 hairType;        // Hair/hat style (0-9)
        uint8 uniformType;     // Uniform style (0-5)
        uint8 accessoryType;   // Medals/decorations (0-7)
        string skinTone;       // Hex color for skin
        string eyeColor;       // Hex color for eyes
    }

    // Captain variant system
    mapping(uint256 => CaptainVariant) public captainVariants;
    mapping(uint256 => uint256) public captainVariantIds; // tokenId => variantId
    mapping(uint256 => CaptainPortrait) public captainPortraits; // tokenId => portrait
    uint256 public currentCaptainSeason;
    uint256[] public activeCaptainVariants;

    // Captain name generation (expanded for variants)
    mapping(uint256 => string[]) public captainVariantTitles;    // variantId => titles
    mapping(uint256 => string[]) public captainVariantFirstNames; // variantId => firstNames
    mapping(uint256 => string[]) public captainVariantLastNames;  // variantId => lastNames

    // Portrait component pools for uniqueness
    mapping(uint256 => bool) public usedPortraitCombinations; // Hash of portrait => used
    uint256 public totalPortraitCombinations;

    // Events for captain lifecycle
    event CaptainMinted(uint256 indexed tokenId, address indexed owner, CaptainAbility ability, Rarity rarity, string name, uint256 variantId);
    event CaptainVariantCreated(uint256 indexed variantId, string name, uint8 portraitThemeId);
    event CaptainVariantRetired(uint256 indexed variantId);
    event CaptainAssigned(uint256 indexed captainId, uint256 indexed shipId, address indexed owner);
    event CaptainUnassigned(uint256 indexed captainId, uint256 indexed shipId, address indexed owner);

    /**
     * @dev Function1: Captain ability definitions
     * Get captain information and abilities
     * @param tokenId Captain token ID
     * @return ability Captain's special ability
     * @return name Captain's generated name
     * @return rarity Captain's rarity level
     */
    function getCaptainInfo(uint256 tokenId) 
        external 
        view 
        returns (
            CaptainAbility ability,
            string memory name,
            Rarity rarity
        ) 
    {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Captain does not exist");
        require(tokenTypes[tokenId] == TokenType.CAPTAIN, "NFTManager: Not a captain NFT");
        
        ability = captainAbilities[tokenId];
        name = captainNames[tokenId];
        rarity = tokenRarities[tokenId];
    }

    /**
     * @dev Function2: Fleet-wide ability application
     * Calculate captain bonus effects for fleet
     * @param captainId Captain token ID
     * @param baseValue Base value to modify
     * @param abilityType Type of ability being applied
     * @return modifiedValue Value after captain bonus
     */
    function applyCaptainBonus(
        uint256 captainId, 
        uint8 baseValue, 
        CaptainAbility abilityType
    ) 
        external 
        view 
        returns (uint8 modifiedValue) 
    {
        if (_ownerOf(captainId) == address(0)) return baseValue;
        if (tokenTypes[captainId] != TokenType.CAPTAIN) return baseValue;
        
        CaptainAbility captainAbility = captainAbilities[captainId];
        Rarity captainRarity = tokenRarities[captainId];
        
        // Only apply bonus if abilities match
        if (captainAbility != abilityType) return baseValue;
        
        // Calculate bonus based on rarity (1-5 bonus)
        uint8 bonus = uint8(captainRarity) + 1;
        
        // Apply different calculations based on ability type
        if (abilityType == CaptainAbility.DAMAGE_BOOST) {
            modifiedValue = baseValue + bonus;
        } else if (abilityType == CaptainAbility.SPEED_BOOST) {
            modifiedValue = baseValue + (bonus > 3 ? 2 : 1); // Max +2 speed
        } else if (abilityType == CaptainAbility.DEFENSE_BOOST) {
            // Reduces incoming damage
            modifiedValue = baseValue > bonus ? baseValue - bonus : 1;
        } else if (abilityType == CaptainAbility.VISION_BOOST) {
            modifiedValue = baseValue + bonus; // Extra cells revealed
        } else if (abilityType == CaptainAbility.LUCK_BOOST) {
            modifiedValue = baseValue + bonus; // Critical hit chance
        } else {
            modifiedValue = baseValue;
        }
        
        return modifiedValue;
    }

    // =============================================================================
    // CAPTAIN VARIANT MANAGEMENT FUNCTIONS
    // =============================================================================

    /**
     * @dev Create a new captain variant for the season
     * @param variantId Unique variant identifier
     * @param name Variant name (e.g., "Undead Admiralty")
     * @param portraitThemeId Visual theme ID for portraits
     * @param titles Array of variant-specific titles
     * @param firstNames Array of variant-specific first names
     * @param lastNames Array of variant-specific last names
     */
    function createCaptainVariant(
        uint256 variantId,
        string calldata name,
        uint8 portraitThemeId,
        string[] calldata titles,
        string[] calldata firstNames,
        string[] calldata lastNames
    ) external onlyOwner {
        require(!captainVariants[variantId].isActive && !captainVariants[variantId].isRetired, "NFTManager: Variant already exists");
        require(titles.length > 0 && firstNames.length > 0 && lastNames.length > 0, "NFTManager: Name arrays cannot be empty");
        
        captainVariants[variantId] = CaptainVariant({
            name: name,
            isActive: true,
            isRetired: false,
            seasonId: currentCaptainSeason,
            portraitThemeId: portraitThemeId,
            retiredAt: 0
        });
        
        // Store variant-specific names
        delete captainVariantTitles[variantId];
        delete captainVariantFirstNames[variantId];
        delete captainVariantLastNames[variantId];
        
        for (uint i = 0; i < titles.length; i++) {
            captainVariantTitles[variantId].push(titles[i]);
        }
        for (uint i = 0; i < firstNames.length; i++) {
            captainVariantFirstNames[variantId].push(firstNames[i]);
        }
        for (uint i = 0; i < lastNames.length; i++) {
            captainVariantLastNames[variantId].push(lastNames[i]);
        }
        
        activeCaptainVariants.push(variantId);
        
        emit CaptainVariantCreated(variantId, name, portraitThemeId);
    }

    /**
     * @dev Retire a captain variant (no more minting)
     * @param variantId Variant to retire
     */
    function retireCaptainVariant(uint256 variantId) external onlyOwner {
        require(captainVariants[variantId].isActive, "NFTManager: Variant not active");
        
        captainVariants[variantId].isActive = false;
        captainVariants[variantId].isRetired = true;
        captainVariants[variantId].retiredAt = block.timestamp;
        
        // Remove from active list
        for (uint i = 0; i < activeCaptainVariants.length; i++) {
            if (activeCaptainVariants[i] == variantId) {
                activeCaptainVariants[i] = activeCaptainVariants[activeCaptainVariants.length - 1];
                activeCaptainVariants.pop();
                break;
            }
        }
        
        emit CaptainVariantRetired(variantId);
    }

    /**
     * @dev Start new captain season with new variants
     * @param seasonId New season identifier
     * @param newActiveVariants Array of variant IDs to activate
     */
    function startCaptainSeason(uint256 seasonId, uint256[] calldata newActiveVariants) external onlyOwner {
        currentCaptainSeason = seasonId;
        
        // Clear previous active variants
        delete activeCaptainVariants;
        
        // Add new active variants
        for (uint i = 0; i < newActiveVariants.length; i++) {
            require(captainVariants[newActiveVariants[i]].isActive, "NFTManager: Variant not active");
            activeCaptainVariants.push(newActiveVariants[i]);
        }
        
        // Reset portrait combination tracking for new season
        totalPortraitCombinations = 0;
    }

    /**
     * @dev Generate unique portrait for captain to avoid duplicates
     * @param tokenId Token ID for randomness
     * @param variantId Variant to generate portrait for
     * @return portrait Generated unique portrait
     */
    function _generateUniquePortrait(uint256 tokenId, uint256 variantId) internal returns (CaptainPortrait memory portrait) {
        uint256 attempts = 0;
        uint256 maxAttempts = 50; // Prevent infinite loops
        
        do {
            uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp, attempts)));
            
            portrait = CaptainPortrait({
                faceType: uint8(seed % 10),
                eyeType: uint8((seed / 10) % 8),
                hairType: uint8((seed / 100) % 10),
                uniformType: uint8((seed / 1000) % 6),
                accessoryType: uint8((seed / 10000) % 8),
                skinTone: _getSkinToneByVariant(variantId, uint8(seed % 5)),
                eyeColor: _getEyeColorByVariant(variantId, uint8((seed / 5) % 4))
            });
            
            attempts++;
        } while (_isPortraitUsed(portrait) && attempts < maxAttempts);
        
        // Mark this combination as used
        uint256 portraitHash = _hashPortrait(portrait);
        usedPortraitCombinations[portraitHash] = true;
        totalPortraitCombinations++;
        
        return portrait;
    }

    /**
     * @dev Check if portrait combination has been used
     */
    function _isPortraitUsed(CaptainPortrait memory portrait) internal view returns (bool) {
        uint256 portraitHash = _hashPortrait(portrait);
        return usedPortraitCombinations[portraitHash];
    }

    /**
     * @dev Hash portrait for uniqueness checking
     */
    function _hashPortrait(CaptainPortrait memory portrait) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            portrait.faceType,
            portrait.eyeType,
            portrait.hairType,
            portrait.uniformType,
            portrait.accessoryType,
            portrait.skinTone,
            portrait.eyeColor
        )));
    }

    /**
     * @dev Get skin tone by variant theme
     */
    function _getSkinToneByVariant(uint256 variantId, uint8 index) internal view returns (string memory) {
        uint8 themeId = captainVariants[variantId].portraitThemeId;
        
        if (themeId == 1) { // Military - diverse human tones
            string[5] memory tones = ["#FDBCB4", "#F1C27D", "#E0AC69", "#C68642", "#8D5524"];
            return tones[index];
        } else if (themeId == 2) { // Pirate - weathered tones
            string[5] memory tones = ["#D2B48C", "#BC9A6A", "#A0522D", "#8B4513", "#654321"];
            return tones[index];
        } else if (themeId == 3) { // Undead - pale/supernatural
            string[5] memory tones = ["#E6E6FA", "#D3D3D3", "#B0C4DE", "#9370DB", "#6A5ACD"];
            return tones[index];
        } else if (themeId == 4) { // Steampunk - industrial tones
            string[5] memory tones = ["#DEB887", "#CD853F", "#B8860B", "#DAA520", "#B8860B"];
            return tones[index];
        } else { // Alien - exotic tones
            string[5] memory tones = ["#98FB98", "#90EE90", "#00FA9A", "#00FF7F", "#00CED1"];
            return tones[index];
        }
    }

    /**
     * @dev Get eye color by variant theme
     */
    function _getEyeColorByVariant(uint256 variantId, uint8 index) internal view returns (string memory) {
        uint8 themeId = captainVariants[variantId].portraitThemeId;
        
        if (themeId == 1) { // Military - natural colors
            string[4] memory colors = ["#8B4513", "#228B22", "#4169E1", "#696969"];
            return colors[index];
        } else if (themeId == 2) { // Pirate - intense colors
            string[4] memory colors = ["#8B0000", "#2F4F4F", "#8B4513", "#000000"];
            return colors[index];
        } else if (themeId == 3) { // Undead - supernatural
            string[4] memory colors = ["#FF0000", "#9370DB", "#FFD700", "#00FFFF"];
            return colors[index];
        } else if (themeId == 4) { // Steampunk - mechanical
            string[4] memory colors = ["#CD7F32", "#DAA520", "#FF6347", "#4682B4"];
            return colors[index];
        } else { // Alien - exotic
            string[4] memory colors = ["#00FFFF", "#7FFF00", "#FF69B4", "#FFD700"];
            return colors[index];
        }
    }

    /**
     * @dev Generate variant-specific captain name
     * @param tokenId Token ID for randomness seed
     * @param variantId Variant to generate name for
     * @return name Generated captain name
     */
    function _generateCaptainName(uint256 tokenId, uint256 variantId) internal view returns (string memory name) {
        uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        
        string[] storage titles = captainVariantTitles[variantId];
        string[] storage firstNames = captainVariantFirstNames[variantId];
        string[] storage lastNames = captainVariantLastNames[variantId];
        
        require(titles.length > 0 && firstNames.length > 0 && lastNames.length > 0, "NFTManager: Variant names not initialized");
        
        uint256 titleIndex = seed % titles.length;
        uint256 firstNameIndex = (seed / 10) % firstNames.length;
        uint256 lastNameIndex = (seed / 100) % lastNames.length;
        
        name = string(abi.encodePacked(
            titles[titleIndex],
            " ",
            firstNames[firstNameIndex],
            " ",
            lastNames[lastNameIndex]
        ));
    }

    /**
     * @dev Mint new captain NFT with unique portrait and variant theming
     * @param recipient Address to receive the captain
     * @param ability Captain's special ability
     * @param rarity Rarity level of the captain
     * @return tokenId Minted token ID
     */
    function mintCaptain(address recipient, CaptainAbility ability, Rarity rarity) 
        external 
        returns (uint256 tokenId) 
    {
        require(
            msg.sender == address(lootboxSystem) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to mint captains"
        );
        require(activeCaptainVariants.length > 0, "NFTManager: No active captain variants");
        
        tokenId = _generateTokenId(TokenType.CAPTAIN);
        tokenRarities[tokenId] = rarity;
        captainAbilities[tokenId] = ability;
        
        // Select random active variant
        uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        uint256 variantIndex = seed % activeCaptainVariants.length;
        uint256 variantId = activeCaptainVariants[variantIndex];
        
        captainVariantIds[tokenId] = variantId;
        
        // Generate unique portrait to avoid duplicates
        captainPortraits[tokenId] = _generateUniquePortrait(tokenId, variantId);
        
        // Generate variant-specific name
        captainNames[tokenId] = _generateCaptainName(tokenId, variantId);
        
        _safeMint(recipient, tokenId);
        
        emit CaptainMinted(tokenId, recipient, ability, rarity, captainNames[tokenId], variantId);
        emit NFTMinted(tokenId, recipient, TokenType.CAPTAIN, rarity);
    }

    // =============================================================================
    // CREW VARIANT MANAGEMENT FUNCTIONS
    // =============================================================================

    /**
     * @dev Create a new crew variant for the season
     * @param variantId Unique variant identifier
     * @param name Variant name (e.g., "Undead Crew")
     * @param visualThemeId Visual theme ID
     * @param namePrefix Prefix for crew names (e.g., "Zombie")
     */
    function createCrewVariant(
        uint256 variantId,
        string calldata name,
        uint8 visualThemeId,
        string calldata namePrefix
    ) external onlyOwner {
        require(!crewVariants[variantId].isActive && !crewVariants[variantId].isRetired, "NFTManager: Variant already exists");
        
        crewVariants[variantId] = CrewVariant({
            name: name,
            isActive: true,
            isRetired: false,
            seasonId: currentCrewSeason,
            visualThemeId: visualThemeId,
            retiredAt: 0
        });
        
        crewVariantPrefixes[variantId] = namePrefix;
        activeCrewVariants.push(variantId);
        
        emit CrewVariantCreated(variantId, name, visualThemeId);
    }

    /**
     * @dev Add crew templates to a variant's pool
     * @param variantId Variant to add templates to
     * @param crewType Type of crew (Gunner, Engineer, etc.)
     * @param fullSVGs Array of complete crew image SVGs
     * @param uiIconSVGs Array of small UI icon SVGs
     * @param descriptions Array of template descriptions
     */
    function addCrewTemplates(
        uint256 variantId,
        CrewType crewType,
        string[] calldata fullSVGs,
        string[] calldata uiIconSVGs,
        string[] calldata descriptions
    ) external onlyOwner {
        require(crewVariants[variantId].isActive, "NFTManager: Variant not active");
        require(fullSVGs.length == uiIconSVGs.length && fullSVGs.length == descriptions.length, "NFTManager: Array length mismatch");
        
        for (uint i = 0; i < fullSVGs.length; i++) {
            uint256 templateId = nextCrewTemplateId++;
            
            crewTemplates[templateId] = CrewTemplate({
                fullSVG: fullSVGs[i],
                uiIconSVG: uiIconSVGs[i],
                description: descriptions[i],
                isActive: true
            });
            
            crewTemplatePools[variantId][crewType].push(uint8(templateId));
            
            emit CrewTemplateAdded(templateId, variantId, crewType);
        }
    }

    /**
     * @dev Retire a crew variant (no more minting)
     * @param variantId Variant to retire
     */
    function retireCrewVariant(uint256 variantId) external onlyOwner {
        require(crewVariants[variantId].isActive, "NFTManager: Variant not active");
        
        crewVariants[variantId].isActive = false;
        crewVariants[variantId].isRetired = true;
        crewVariants[variantId].retiredAt = block.timestamp;
        
        // Remove from active list
        for (uint i = 0; i < activeCrewVariants.length; i++) {
            if (activeCrewVariants[i] == variantId) {
                activeCrewVariants[i] = activeCrewVariants[activeCrewVariants.length - 1];
                activeCrewVariants.pop();
                break;
            }
        }
        
        emit CrewVariantRetired(variantId);
    }

    /**
     * @dev Start new crew season with new variants
     * @param seasonId New season identifier
     * @param newActiveVariants Array of variant IDs to activate
     */
    function startCrewSeason(uint256 seasonId, uint256[] calldata newActiveVariants) external onlyOwner {
        currentCrewSeason = seasonId;
        
        // Clear previous active variants
        delete activeCrewVariants;
        
        // Add new active variants
        for (uint i = 0; i < newActiveVariants.length; i++) {
            require(crewVariants[newActiveVariants[i]].isActive, "NFTManager: Variant not active");
            activeCrewVariants.push(newActiveVariants[i]);
        }
    }

    /**
     * @dev Check if captain ability affects default attacks
     * @param captainId Captain token ID
     * @return affects Whether captain affects default attacks
     */
    function captainAffectsDefaultAttacks(uint256 captainId) external view returns (bool affects) {
        if (_ownerOf(captainId) == address(0)) return false;
        if (tokenTypes[captainId] != TokenType.CAPTAIN) return false;
        
        // TODO: Check GameConfig for which abilities affect default attacks
        // For now, assume DAMAGE_BOOST affects default attacks
        CaptainAbility ability = captainAbilities[captainId];
        return (ability == CaptainAbility.DAMAGE_BOOST);
    }

    /**
     * @dev Get all captains owned by a player
     * @param player Player address
     * @return tokenIds Array of captain token IDs
     */
    function getPlayerCaptains(address player) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        return this.getTokensByTypeAndOwner(player, TokenType.CAPTAIN);
    }

    /**
     * @dev Get captain ability counts for a player
     * @param player Player address
     * @return damageBoost Number of damage boost captains
     * @return speedBoost Number of speed boost captains
     * @return defenseBoost Number of defense boost captains
     * @return visionBoost Number of vision boost captains
     * @return luckBoost Number of luck boost captains
     */
    function getPlayerCaptainAbilities(address player) 
        external 
        view 
        returns (
            uint256 damageBoost,
            uint256 speedBoost,
            uint256 defenseBoost,
            uint256 visionBoost,
            uint256 luckBoost
        ) 
    {
        uint256[] memory captains = this.getTokensByTypeAndOwner(player, TokenType.CAPTAIN);
        
        for (uint256 i = 0; i < captains.length; i++) {
            CaptainAbility ability = captainAbilities[captains[i]];
            
            if (ability == CaptainAbility.DAMAGE_BOOST) damageBoost++;
            else if (ability == CaptainAbility.SPEED_BOOST) speedBoost++;
            else if (ability == CaptainAbility.DEFENSE_BOOST) defenseBoost++;
            else if (ability == CaptainAbility.VISION_BOOST) visionBoost++;
                         else if (ability == CaptainAbility.LUCK_BOOST) luckBoost++;
        }
    }

    // =============================================================================
    // SECTION 4.5: CREW NFT IMPLEMENTATION
    // =============================================================================

    /**
     * @dev Crew variant definition (visual themes only - no stat impact)
     */
    struct CrewVariant {
        string name;           // "Undead Crew", "Pirate Crew", etc.
        bool isActive;         // Can still be minted
        bool isRetired;        // Permanently retired
        uint256 seasonId;      // Which season it belongs to
        uint8 visualThemeId;   // Visual theme ID for templates
        uint256 retiredAt;     // Timestamp when retired
    }

    /**
     * @dev Crew visual template for pool system
     */
    struct CrewTemplate {
        string fullSVG;        // Complete crew image SVG
        string uiIconSVG;      // Small UI icon SVG (for ship display)
        string description;    // Template description
        bool isActive;         // Whether template is available
    }

    // Crew variant system
    mapping(uint256 => CrewVariant) public crewVariants;
    mapping(uint256 => uint256) public crewVariantIds; // tokenId => variantId
    mapping(uint256 => uint8) public crewTemplateIds; // tokenId => templateId
    uint256 public currentCrewSeason;
    uint256[] public activeCrewVariants;

    // Crew template pools by (variantId, crewType) => templateId[]
    mapping(uint256 => mapping(CrewType => uint8[])) public crewTemplatePools;
    mapping(uint256 => CrewTemplate) public crewTemplates; // templateId => template
    uint256 public nextCrewTemplateId;

    // Crew name prefixes by variant
    mapping(uint256 => string) public crewVariantPrefixes; // variantId => "Zombie", "Pirate", etc.

    // Weekly stamina reset tracking
    uint256 public lastStaminaResetWeek;
    mapping(uint256 => uint256) public crewLastGameWeek; // Track last game week for crew
    
    // Events for crew lifecycle
    event CrewMinted(uint256 indexed tokenId, address indexed owner, CrewType crewType, Rarity rarity, uint256 variantId, uint8 templateId);
    event CrewVariantCreated(uint256 indexed variantId, string name, uint8 visualThemeId);
    event CrewVariantRetired(uint256 indexed variantId);
    event CrewTemplateAdded(uint256 indexed templateId, uint256 variantId, CrewType crewType);
    event CrewStaminaUsed(uint256 indexed tokenId, address indexed user, uint256 staminaRemaining);
    event CrewStaminaReset(uint256 indexed tokenId, uint256 newStamina);

    /**
     * @dev Function1: Crew type definitions (Gunner, Engineer, Navigator, Medic)
     * Get crew information and current stamina
     * @param tokenId Crew token ID
     * @return crewType Type of crew member
     * @return currentStamina Current stamina points
     * @param maxStamina Maximum stamina (100)
     * @param rarity Crew rarity level
     */
    function getCrewInfo(uint256 tokenId) 
        external 
        view 
        returns (
            CrewType crewType,
            uint256 currentStamina,
            uint256 maxStamina,
            Rarity rarity
        ) 
    {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Crew does not exist");
        require(tokenTypes[tokenId] == TokenType.CREW, "NFTManager: Not a crew NFT");
        
        crewType = crewTypes[tokenId];
        currentStamina = crewStamina[tokenId];
        maxStamina = 100; // All crew start with 100 stamina
        rarity = tokenRarities[tokenId];
    }

    /**
     * @dev Function2: Stamina system (100 points, -10 per game)
     * Use crew member stamina for a game
     * @param tokenId Crew token ID
     * @param user Address using the crew
     */
    function useCrewStamina(uint256 tokenId, address user) external {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Crew does not exist");
        require(tokenTypes[tokenId] == TokenType.CREW, "NFTManager: Not a crew NFT");
        require(
            msg.sender == address(battleshipGame) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to use crew"
        );
        require(ownerOf(tokenId) == user, "NFTManager: User does not own crew");
        
        uint256 currentStamina = crewStamina[tokenId];
        require(currentStamina >= 10, "NFTManager: Insufficient crew stamina");
        
        crewStamina[tokenId] = currentStamina - 10;
        crewLastGameWeek[tokenId] = getCurrentWeek();
        
        emit CrewStaminaUsed(tokenId, user, crewStamina[tokenId]);
    }

    /**
     * @dev Function3: Weekly stamina reset
     * Reset all crew stamina to 100 (called weekly)
     */
    function resetWeeklyStamina() external {
        uint256 currentWeek = getCurrentWeek();
        require(currentWeek > lastStaminaResetWeek, "NFTManager: Stamina already reset this week");
        
        lastStaminaResetWeek = currentWeek;
        
        // Note: Individual crew stamina will be reset on-demand when checked
        // This saves gas by not resetting all crew at once
    }

    /**
     * @dev Mint new crew NFT with variant template selection
     * @param recipient Address to receive the crew
     * @param crewType Type of crew member
     * @param rarity Rarity level of the crew
     * @return tokenId Minted token ID
     */
    function mintCrew(address recipient, CrewType crewType, Rarity rarity) 
        external 
        returns (uint256 tokenId) 
    {
        require(
            msg.sender == address(lootboxSystem) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to mint crew"
        );
        require(activeCrewVariants.length > 0, "NFTManager: No active crew variants");
        
        tokenId = _generateTokenId(TokenType.CREW);
        tokenRarities[tokenId] = rarity;
        crewTypes[tokenId] = crewType;
        crewStamina[tokenId] = 100; // Start with full stamina
        crewLastGameWeek[tokenId] = getCurrentWeek();
        
        // Select random active variant
        uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        uint256 variantIndex = seed % activeCrewVariants.length;
        uint256 variantId = activeCrewVariants[variantIndex];
        
        crewVariantIds[tokenId] = variantId;
        
        // Select random template from variant's pool for this crew type
        uint8[] storage templates = crewTemplatePools[variantId][crewType];
        require(templates.length > 0, "NFTManager: No templates available for crew type in variant");
        
        uint256 templateIndex = (seed / 100) % templates.length;
        uint8 templateId = templates[templateIndex];
        
        crewTemplateIds[tokenId] = templateId;
        
        _safeMint(recipient, tokenId);
        
        emit CrewMinted(tokenId, recipient, crewType, rarity, variantId, templateId);
        emit NFTMinted(tokenId, recipient, TokenType.CREW, rarity);
    }

    /**
     * @dev Check if crew can be used in battle
     * @param tokenId Crew token ID
     * @return canUse Whether crew has enough stamina
     * @return currentStamina Current stamina amount
     */
    function canUseCrew(uint256 tokenId) 
        external 
        view 
        returns (bool canUse, uint256 currentStamina) 
    {
        if (_ownerOf(tokenId) == address(0)) return (false, 0);
        if (tokenTypes[tokenId] != TokenType.CREW) return (false, 0);
        
        currentStamina = _getCrewStaminaWithReset(tokenId);
        canUse = currentStamina >= 10;
    }

    /**
     * @dev Get crew stamina with automatic weekly reset
     * @param tokenId Crew token ID
     * @return stamina Current stamina (after reset if needed)
     */
    function _getCrewStaminaWithReset(uint256 tokenId) internal view returns (uint256 stamina) {
        uint256 currentWeek = getCurrentWeek();
        uint256 lastGameWeek = crewLastGameWeek[tokenId];
        
        // Reset stamina if it's been a week since last use
        if (currentWeek > lastGameWeek) {
            return 100; // Full stamina after weekly reset
        }
        
        return crewStamina[tokenId];
    }

    /**
     * @dev Apply crew bonuses to ship or fleet
     * @param crewId Crew token ID
     * @param baseValue Base value to modify
     * @param bonusType Type of bonus being applied
     * @return modifiedValue Value after crew bonus
     */
    function applyCrewBonus(
        uint256 crewId, 
        uint8 baseValue, 
        CrewType bonusType
    ) 
        external 
        view 
        returns (uint8 modifiedValue) 
    {
        if (_ownerOf(crewId) == address(0)) return baseValue;
        if (tokenTypes[crewId] != TokenType.CREW) return baseValue;
        
        CrewType crewType = crewTypes[crewId];
        Rarity crewRarity = tokenRarities[crewId];
        
        // Check if crew has enough stamina
        uint256 stamina = _getCrewStaminaWithReset(crewId);
        if (stamina < 10) return baseValue;
        
        // Only apply bonus if crew types match
        if (crewType != bonusType) return baseValue;
        
        // Calculate bonus based on rarity (1-3 bonus)
        uint8 bonus = uint8(crewRarity) / 2 + 1; // Common=1, Uncommon=1, Rare=2, Epic=2, Legendary=3
        
        // Apply bonus based on crew type
        if (bonusType == CrewType.GUNNER) {
            modifiedValue = baseValue + bonus; // Damage bonus
        } else if (bonusType == CrewType.ENGINEER) {
            modifiedValue = baseValue + (bonus > 2 ? 1 : 0); // Speed bonus (max +1)
        } else if (bonusType == CrewType.NAVIGATOR) {
            modifiedValue = baseValue + bonus; // Movement efficiency
        } else if (bonusType == CrewType.MEDIC) {
            modifiedValue = baseValue + bonus; // Repair ability
        } else {
            modifiedValue = baseValue;
        }
        
        return modifiedValue;
    }

    /**
     * @dev Get current week number (for stamina reset)
     * @return weekNumber Current week since epoch
     */
    function getCurrentWeek() public view returns (uint256 weekNumber) {
        return block.timestamp / 604800; // 604800 seconds in a week
    }

    /**
     * @dev Get all usable crew for a player
     * @param player Player address
     * @return tokenIds Array of usable crew token IDs
     */
    function getUsableCrew(address player) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        uint256[] memory allCrew = this.getTokensByTypeAndOwner(player, TokenType.CREW);
        uint256[] memory tempIds = new uint256[](allCrew.length);
        uint256 resultCount = 0;
        
        for (uint256 i = 0; i < allCrew.length; i++) {
            (bool canUse,) = this.canUseCrew(allCrew[i]);
            if (canUse) {
                tempIds[resultCount] = allCrew[i];
                resultCount++;
            }
        }
        
        // Create result array with exact size
        tokenIds = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            tokenIds[i] = tempIds[i];
        }
    }

    /**
     * @dev Get player crew by type
     * @param player Player address
     * @param crewType Type of crew to filter by
     * @return tokenIds Array of crew token IDs of specified type
     */
    function getPlayerCrewByType(address player, CrewType crewType) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        uint256[] memory allCrew = this.getTokensByTypeAndOwner(player, TokenType.CREW);
        uint256[] memory tempIds = new uint256[](allCrew.length);
        uint256 resultCount = 0;
        
        for (uint256 i = 0; i < allCrew.length; i++) {
            if (crewTypes[allCrew[i]] == crewType) {
                tempIds[resultCount] = allCrew[i];
                resultCount++;
            }
        }
        
        // Create result array with exact size
        tokenIds = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            tokenIds[i] = tempIds[i];
        }
    }

    // =============================================================================
    // SECTION 4.3: ACTION NFT IMPLEMENTATION
    // =============================================================================

    /**
     * @dev Action template for reusable action definitions
     */
    struct ActionTemplate {
        string name;             // Action name (e.g., "Plasma Beam", "Energy Shield")
        string description;      // Action description
        uint8[] targetCells;     // Relative cell offsets from target
        uint8 damage;            // Damage per hit cell
        uint8 range;             // Maximum casting range
        uint8 uses;              // Number of uses per NFT
        ActionCategory category; // Offensive or Defensive
        Rarity minRarity;        // Minimum rarity for this template
        bool isActive;           // Whether template can be minted
        bool isSeasonalOnly;     // Whether template is seasonal
        uint256 seasonId;        // Season ID if seasonal (0 = all seasons)
    }

    /**
     * @dev Action variant for seasonal collections
     */
    struct ActionVariant {
        string name;             // Variant name (e.g., "Winter Storm Arsenal")
        bool isActive;           // Whether variant is active
        bool isRetired;          // Whether variant is retired
        uint256 seasonId;        // Season ID
        uint256 retiredAt;       // Block number when retired
        string visualTheme;      // Visual theme identifier
    }

    /**
     * @dev Action NFT pattern (copied from template on mint)
     */
    struct ActionPattern {
        uint8[] targetCells;     // Relative cell offsets from target
        uint8 damage;            // Damage per hit cell
        uint8 range;             // Maximum casting range
        ActionCategory category; // Offensive or Defensive
    }

    // Template system storage
    mapping(uint8 => ActionTemplate) public actionTemplates;
    mapping(uint256 => ActionVariant) public actionVariants;
    mapping(uint256 => mapping(ActionCategory => mapping(Rarity => uint8[]))) public variantTemplatesByRarity;
    uint8 public nextTemplateId = 1;
    uint256 public nextActionVariantId = 1;
    uint256 public activeActionVariant = 0; // 0 = classic templates

    // Action NFT storage
    mapping(uint256 => ActionPattern) public actionPatterns;
    mapping(uint256 => ActionCategory) public actionCategories;
    mapping(uint256 => uint256) public actionMaxUses;
    mapping(uint256 => uint8) public actionTemplateIds;
    mapping(uint256 => uint256) public actionVariantIds;
    
    // Events for action lifecycle
    event ActionMinted(uint256 indexed tokenId, address indexed owner, ActionCategory category, Rarity rarity, uint8 templateId);
    event ActionUsed(uint256 indexed tokenId, address indexed user, uint256 usesRemaining);
    event ActionDepleted(uint256 indexed tokenId, address indexed owner);
    event ActionTemplateAdded(uint8 indexed templateId, string name, ActionCategory category, Rarity minRarity);
    event ActionVariantCreated(uint256 indexed variantId, string name, uint256 seasonId);
    event ActionVariantActivated(uint256 indexed variantId);
    event ActionVariantRetired(uint256 indexed variantId);

    /**
     * @dev Function1: Action pattern definitions
     * Get action pattern and effects
     * @param tokenId Action token ID
     * @return pattern Action pattern struct
     * @return category Offensive or defensive
     * @return usesRemaining Uses left on this action
     */
    function getActionInfo(uint256 tokenId) 
        external 
        view 
        returns (
            ActionPattern memory pattern,
            ActionCategory category,
            uint256 usesRemaining
        ) 
    {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Action does not exist");
        require(tokenTypes[tokenId] == TokenType.ACTION, "NFTManager: Not an action NFT");
        
        pattern = actionPatterns[tokenId];
        category = actionCategories[tokenId];
        usesRemaining = actionUsesRemaining[tokenId];
    }

    /**
     * @dev Function2: Use count tracking and depletion
     * Use an action NFT (decrements use count)
     * @param tokenId Action token ID
     * @param user Address using the action
     */
    function useAction(uint256 tokenId, address user) external {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Action does not exist");
        require(tokenTypes[tokenId] == TokenType.ACTION, "NFTManager: Not an action NFT");
        require(
            msg.sender == address(battleshipGame) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to use actions"
        );
        require(ownerOf(tokenId) == user, "NFTManager: User does not own action");
        require(actionUsesRemaining[tokenId] > 0, "NFTManager: Action depleted");
        
        actionUsesRemaining[tokenId]--;
        
        emit ActionUsed(tokenId, user, actionUsesRemaining[tokenId]);
        
        // Burn token if depleted
        if (actionUsesRemaining[tokenId] == 0) {
            emit ActionDepleted(tokenId, user);
            _burn(tokenId);
        }
    }

    /**
     * @dev Function3: Template-based action minting
     * Mint new action NFT using template system
     * @param recipient Address to receive the action
     * @param category Offensive or defensive action
     * @param rarity Rarity level of the action
     * @return tokenId Minted token ID
     */
    function mintAction(address recipient, ActionCategory category, Rarity rarity) 
        external 
        returns (uint256 tokenId) 
    {
        require(
            msg.sender == address(lootboxSystem) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to mint actions"
        );
        
        // Get available templates for current variant, category, and rarity
        uint8[] memory availableTemplates = variantTemplatesByRarity[activeActionVariant][category][rarity];
        require(availableTemplates.length > 0, "NFTManager: No templates available for this combination");
        
        // Select random template
        uint8 templateId = availableTemplates[uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            block.difficulty, 
            recipient, 
            _nextTokenId
        ))) % availableTemplates.length];
        
        ActionTemplate memory template = actionTemplates[templateId];
        require(template.isActive, "NFTManager: Template not active");
        require(uint8(rarity) >= uint8(template.minRarity), "NFTManager: Rarity too low for template");
        
        // Mint the NFT
        tokenId = _generateTokenId(TokenType.ACTION);
        tokenRarities[tokenId] = rarity;
        actionCategories[tokenId] = category;
        actionTemplateIds[tokenId] = templateId;
        actionVariantIds[tokenId] = activeActionVariant;
        
        // Copy template data to NFT
        actionPatterns[tokenId] = ActionPattern({
            targetCells: template.targetCells,
            damage: template.damage,
            range: template.range,
            category: template.category
        });
        
        actionMaxUses[tokenId] = template.uses;
        actionUsesRemaining[tokenId] = template.uses;
        
        _safeMint(recipient, tokenId);
        
        emit ActionMinted(tokenId, recipient, category, rarity, templateId);
        emit NFTMinted(tokenId, recipient, TokenType.ACTION, rarity);
    }

    /**
     * @dev Function4: Action execution validation
     * Validate action can be used in current context
     * @param tokenId Action token ID
     * @param user Address attempting to use action
     * @param targetCells Array of target cell indices
     * @return valid Whether action usage is valid
     * @return reason Reason if invalid
     */
    function validateActionUsage(
        uint256 tokenId, 
        address user, 
        uint8[] calldata targetCells
    ) 
        external 
        view 
        returns (bool valid, string memory reason) 
    {
        // Basic existence checks
        if (_ownerOf(tokenId) == address(0)) {
            return (false, "Action does not exist");
        }
        if (tokenTypes[tokenId] != TokenType.ACTION) {
            return (false, "Not an action NFT");
        }
        if (ownerOf(tokenId) != user) {
            return (false, "User does not own action");
        }
        if (actionUsesRemaining[tokenId] == 0) {
            return (false, "Action depleted");
        }
        
        // Pattern validation
        ActionPattern memory pattern = actionPatterns[tokenId];
        if (targetCells.length != pattern.targetCells.length) {
            return (false, "Invalid target cell count");
        }
        
        // Validate each target cell is within grid bounds
        for (uint256 i = 0; i < targetCells.length; i++) {
            if (targetCells[i] >= 100) { // 10x10 grid = 100 cells
                return (false, "Target cell out of bounds");
            }
        }
        
        return (true, "");
    }

    /**
     * @dev Add new action template
     * @param name Template name
     * @param description Template description
     * @param targetCells Target cell pattern
     * @param damage Damage per hit
     * @param range Casting range
     * @param uses Number of uses
     * @param category Offensive or defensive
     * @param minRarity Minimum rarity required
     * @param isSeasonalOnly Whether template is seasonal only
     * @param seasonId Season ID if seasonal
     * @return templateId New template ID
     */
    function addActionTemplate(
        string calldata name,
        string calldata description,
        uint8[] calldata targetCells,
        uint8 damage,
        uint8 range,
        uint8 uses,
        ActionCategory category,
        Rarity minRarity,
        bool isSeasonalOnly,
        uint256 seasonId
    ) external onlyOwner returns (uint8 templateId) {
        require(targetCells.length > 0 && targetCells.length <= 25, "NFTManager: Invalid target cells count");
        require(damage <= 10, "NFTManager: Damage too high");
        require(range <= 15, "NFTManager: Range too high");
        require(uses > 0 && uses <= 10, "NFTManager: Invalid uses count");
        
        templateId = nextTemplateId++;
        
        actionTemplates[templateId] = ActionTemplate({
            name: name,
            description: description,
            targetCells: targetCells,
            damage: damage,
            range: range,
            uses: uses,
            category: category,
            minRarity: minRarity,
            isActive: true,
            isSeasonalOnly: isSeasonalOnly,
            seasonId: seasonId
        });
        
        emit ActionTemplateAdded(templateId, name, category, minRarity);
    }

    /**
     * @dev Assign template to variant and rarity combination
     * @param variantId Variant ID (0 = classic)
     * @param category Action category
     * @param rarity Action rarity
     * @param templateIds Array of template IDs to assign
     */
    function assignTemplatesToVariantRarity(
        uint256 variantId,
        ActionCategory category,
        Rarity rarity,
        uint8[] calldata templateIds
    ) external onlyOwner {
        // Validate all templates exist and match criteria
        for (uint256 i = 0; i < templateIds.length; i++) {
            ActionTemplate memory template = actionTemplates[templateIds[i]];
            require(template.targetCells.length > 0, "NFTManager: Template does not exist");
            require(template.category == category, "NFTManager: Template category mismatch");
            require(uint8(rarity) >= uint8(template.minRarity), "NFTManager: Rarity too low for template");
            
            if (variantId > 0) {
                ActionVariant memory variant = actionVariants[variantId];
                require(variant.seasonId > 0, "NFTManager: Variant does not exist");
                if (template.isSeasonalOnly) {
                    require(template.seasonId == variant.seasonId || template.seasonId == 0, "NFTManager: Season mismatch");
                }
            }
        }
        
        variantTemplatesByRarity[variantId][category][rarity] = templateIds;
    }

    /**
     * @dev Create new action variant for seasonal collections
     * @param name Variant name
     * @param seasonId Season identifier
     * @param visualTheme Visual theme identifier
     * @return variantId New variant ID
     */
    function createActionVariant(
        string calldata name,
        uint256 seasonId,
        string calldata visualTheme
    ) external onlyOwner returns (uint256 variantId) {
        require(seasonId > 0, "NFTManager: Invalid season ID");
        
        variantId = nextActionVariantId++;
        
        actionVariants[variantId] = ActionVariant({
            name: name,
            isActive: false,
            isRetired: false,
            seasonId: seasonId,
            retiredAt: 0,
            visualTheme: visualTheme
        });
        
        emit ActionVariantCreated(variantId, name, seasonId);
    }

    /**
     * @dev Activate action variant (becomes the active minting variant)
     * @param variantId Variant ID to activate
     */
    function activateActionVariant(uint256 variantId) external onlyOwner {
        if (variantId == 0) {
            // Activating classic variant
            activeActionVariant = 0;
        } else {
            ActionVariant storage variant = actionVariants[variantId];
            require(variant.seasonId > 0, "NFTManager: Variant does not exist");
            require(!variant.isRetired, "NFTManager: Variant is retired");
            
            variant.isActive = true;
            activeActionVariant = variantId;
        }
        
        emit ActionVariantActivated(variantId);
    }

    /**
     * @dev Retire action variant (can no longer be minted)
     * @param variantId Variant ID to retire
     */
    function retireActionVariant(uint256 variantId) external onlyOwner {
        require(variantId > 0, "NFTManager: Cannot retire classic variant");
        
        ActionVariant storage variant = actionVariants[variantId];
        require(variant.seasonId > 0, "NFTManager: Variant does not exist");
        require(!variant.isRetired, "NFTManager: Variant already retired");
        
        variant.isActive = false;
        variant.isRetired = true;
        variant.retiredAt = block.number;
        
        // If this was the active variant, revert to classic
        if (activeActionVariant == variantId) {
            activeActionVariant = 0;
        }
        
        emit ActionVariantRetired(variantId);
    }

    /**
     * @dev Toggle template active status
     * @param templateId Template ID
     * @param isActive New active status
     */
    function setTemplateActive(uint8 templateId, bool isActive) external onlyOwner {
        ActionTemplate storage template = actionTemplates[templateId];
        require(template.targetCells.length > 0, "NFTManager: Template does not exist");
        template.isActive = isActive;
    }

    /**
     * @dev Get available templates for variant, category, and rarity
     * @param variantId Variant ID
     * @param category Action category
     * @param rarity Action rarity
     * @return templateIds Array of available template IDs
     */
    function getAvailableTemplates(
        uint256 variantId,
        ActionCategory category,
        Rarity rarity
    ) external view returns (uint8[] memory templateIds) {
        return variantTemplatesByRarity[variantId][category][rarity];
    }

    /**
     * @dev Batch create multiple action templates (gas efficient)
     * @param templateData Array of template creation data
     */
    function batchCreateActionTemplates(ActionTemplateCreationData[] calldata templateData) external onlyOwner {
        for (uint256 i = 0; i < templateData.length; i++) {
            ActionTemplateCreationData memory data = templateData[i];
            
            require(data.targetCells.length > 0 && data.targetCells.length <= 25, "NFTManager: Invalid target cells count");
            require(data.damage <= 10, "NFTManager: Damage too high");
            require(data.range <= 15, "NFTManager: Range too high");
            require(data.uses > 0 && data.uses <= 10, "NFTManager: Invalid uses count");
            
            uint8 templateId = nextTemplateId++;
            
            actionTemplates[templateId] = ActionTemplate({
                name: data.name,
                description: data.description,
                targetCells: data.targetCells,
                damage: data.damage,
                range: data.range,
                uses: data.uses,
                category: data.category,
                minRarity: data.minRarity,
                isActive: true,
                isSeasonalOnly: data.isSeasonalOnly,
                seasonId: data.seasonId
            });
            
            emit ActionTemplateAdded(templateId, data.name, data.category, data.minRarity);
        }
    }

    /**
     * @dev Helper struct for batch template creation
     */
    struct ActionTemplateCreationData {
        string name;
        string description;
        uint8[] targetCells;
        uint8 damage;
        uint8 range;
        uint8 uses;
        ActionCategory category;
        Rarity minRarity;
        bool isSeasonalOnly;
        uint256 seasonId;
    }

    /**
     * @dev Get template information
     * @param templateId Template ID
     * @return template Template data
     */
    function getActionTemplate(uint8 templateId) external view returns (ActionTemplate memory template) {
        return actionTemplates[templateId];
    }

    /**
     * @dev Get action variant information
     * @param variantId Variant ID  
     * @return variant Variant data
     */
    function getActionVariant(uint256 variantId) external view returns (ActionVariant memory variant) {
        return actionVariants[variantId];
    }

    /**
     * @dev Get current active action variant
     * @return variantId Currently active variant ID
     */
    function getActiveActionVariant() external view returns (uint256 variantId) {
        return activeActionVariant;
    }

    /**
     * @dev Easy season deployment: Create variant and assign templates
     * @param name Variant name
     * @param seasonId Season ID
     * @param visualTheme Visual theme
     * @param templateAssignments Array of template assignments
     * @return variantId Created variant ID
     */
    function deploySeasonActionVariant(
        string calldata name,
        uint256 seasonId,
        string calldata visualTheme,
        TemplateAssignment[] calldata templateAssignments
    ) external onlyOwner returns (uint256 variantId) {
        // Create the variant
        variantId = createActionVariant(name, seasonId, visualTheme);
        
        // Assign all templates
        for (uint256 i = 0; i < templateAssignments.length; i++) {
            TemplateAssignment memory assignment = templateAssignments[i];
            assignTemplatesToVariantRarity(
                variantId,
                assignment.category,
                assignment.rarity,
                assignment.templateIds
            );
        }
    }

    /**
     * @dev Helper struct for template assignment
     */
    struct TemplateAssignment {
        ActionCategory category;
        Rarity rarity;
        uint8[] templateIds;
    }

    // =============================================================================
    // ADMIN NFT CREATION SYSTEM
    // =============================================================================

    /**
     * @dev Admin mint custom ship with full control
     * @param recipient Address to receive the ship
     * @param shipType Type of ship
     * @param variantId Variant ID
     * @param rarity Rarity level
     * @param customName Custom name override (empty for default)
     * @param statOverrides Custom stat overrides (use 0 for default)
     * @return tokenId Minted token ID
     */
    function adminMintCustomShip(
        address recipient,
        ShipType shipType,
        uint256 variantId,
        Rarity rarity,
        string calldata customName,
        ShipStatsOverride calldata statOverrides
    ) external onlyOwner returns (uint256 tokenId) {
        require(recipient != address(0), "NFTManager: Invalid recipient");
        require(variants[variantId].seasonId > 0 || variantId <= VARIANT_UNDEAD, "NFTManager: Invalid variant");
        
        tokenId = _generateTokenId(TokenType.SHIP);
        tokenRarities[tokenId] = rarity;
        shipTypes[tokenId] = shipType;
        shipVariants[tokenId] = variantId;
        
        // Generate or override stats
        ShipStats memory stats;
        if (statOverrides.useCustomStats) {
            stats = ShipStats({
                health: statOverrides.health > 0 ? statOverrides.health : _getBaseShipStats(shipType).health,
                speed: statOverrides.speed > 0 ? statOverrides.speed : _getBaseShipStats(shipType).speed,
                firepower: statOverrides.firepower > 0 ? statOverrides.firepower : _getBaseShipStats(shipType).firepower,
                size: statOverrides.size > 0 ? statOverrides.size : _getBaseShipStats(shipType).size
            });
        } else {
            stats = _calculateShipStats(shipType, variantId, rarity);
        }
        
        shipStats[tokenId] = stats;
        
        // Custom name if provided
        if (bytes(customName).length > 0) {
            shipCustomNames[tokenId] = customName;
        }
        
        _safeMint(recipient, tokenId);
        
        emit NFTMinted(tokenId, recipient, TokenType.SHIP, rarity);
        emit AdminMinted(tokenId, recipient, "Custom Ship", customName);
    }

    /**
     * @dev Admin mint custom action with specific template
     * @param recipient Address to receive the action
     * @param templateId Specific template to use
     * @param rarity Rarity level
     * @param customName Custom name override (empty for default)
     * @param usesOverride Custom uses count (0 for template default)
     * @return tokenId Minted token ID
     */
    function adminMintCustomAction(
        address recipient,
        uint8 templateId,
        Rarity rarity,
        string calldata customName,
        uint8 usesOverride
    ) external onlyOwner returns (uint256 tokenId) {
        require(recipient != address(0), "NFTManager: Invalid recipient");
        
        ActionTemplate memory template = actionTemplates[templateId];
        require(template.targetCells.length > 0, "NFTManager: Template does not exist");
        require(uint8(rarity) >= uint8(template.minRarity), "NFTManager: Rarity too low for template");
        
        tokenId = _generateTokenId(TokenType.ACTION);
        tokenRarities[tokenId] = rarity;
        actionCategories[tokenId] = template.category;
        actionTemplateIds[tokenId] = templateId;
        actionVariantIds[tokenId] = activeActionVariant;
        
        // Copy template data to NFT
        actionPatterns[tokenId] = ActionPattern({
            targetCells: template.targetCells,
            damage: template.damage,
            range: template.range,
            category: template.category
        });
        
        // Use custom uses if specified
        uint8 finalUses = usesOverride > 0 ? usesOverride : template.uses;
        actionMaxUses[tokenId] = finalUses;
        actionUsesRemaining[tokenId] = finalUses;
        
        // Custom name if provided
        if (bytes(customName).length > 0) {
            actionCustomNames[tokenId] = customName;
        }
        
        _safeMint(recipient, tokenId);
        
        emit ActionMinted(tokenId, recipient, template.category, rarity, templateId);
        emit NFTMinted(tokenId, recipient, TokenType.ACTION, rarity);
        emit AdminMinted(tokenId, recipient, "Custom Action", customName);
    }

    /**
     * @dev Admin mint custom captain with full control
     * @param recipient Address to receive the captain
     * @param ability Captain ability
     * @param rarity Rarity level
     * @param variantId Variant ID (0 for classic)
     * @param customName Custom name override (empty for default)
     * @param portraitOverrides Custom portrait traits
     * @return tokenId Minted token ID
     */
    function adminMintCustomCaptain(
        address recipient,
        CaptainAbility ability,
        Rarity rarity,
        uint256 variantId,
        string calldata customName,
        CaptainPortraitOverride calldata portraitOverrides
    ) external onlyOwner returns (uint256 tokenId) {
        require(recipient != address(0), "NFTManager: Invalid recipient");
        
        tokenId = _generateTokenId(TokenType.CAPTAIN);
        tokenRarities[tokenId] = rarity;
        captainAbilities[tokenId] = ability;
        captainVariantIds[tokenId] = variantId;
        
        // Generate or override portrait
        CaptainPortrait memory portrait;
        if (portraitOverrides.useCustomPortrait) {
            portrait = CaptainPortrait({
                faceType: portraitOverrides.faceType,
                eyeType: portraitOverrides.eyeType,
                hairType: portraitOverrides.hairType,
                skinTone: portraitOverrides.skinTone,
                eyeColor: portraitOverrides.eyeColor,
                hairColor: portraitOverrides.hairColor,
                uniformColor: portraitOverrides.uniformColor,
                accessoryType: portraitOverrides.accessoryType
            });
        } else {
            portrait = _generateCaptainPortrait(variantId, tokenId);
        }
        
        captainPortraits[tokenId] = portrait;
        
        // Generate name
        string memory finalName;
        if (bytes(customName).length > 0) {
            finalName = customName;
        } else {
            finalName = _generateCaptainName(variantId, tokenId);
        }
        captainNames[tokenId] = finalName;
        
        _safeMint(recipient, tokenId);
        
        emit NFTMinted(tokenId, recipient, TokenType.CAPTAIN, rarity);
        emit AdminMinted(tokenId, recipient, "Custom Captain", finalName);
    }

    /**
     * @dev Admin mint custom crew with full control
     * @param recipient Address to receive the crew
     * @param crewType Type of crew member
     * @param rarity Rarity level
     * @param variantId Variant ID (0 for classic)
     * @param templateId Specific template ID (0 for random)
     * @param customName Custom name override (empty for default)
     * @param staminaOverride Custom stamina (0 for default)
     * @return tokenId Minted token ID
     */
    function adminMintCustomCrew(
        address recipient,
        CrewType crewType,
        Rarity rarity,
        uint256 variantId,
        uint8 templateId,
        string calldata customName,
        uint8 staminaOverride
    ) external onlyOwner returns (uint256 tokenId) {
        require(recipient != address(0), "NFTManager: Invalid recipient");
        
        tokenId = _generateTokenId(TokenType.CREW);
        tokenRarities[tokenId] = rarity;
        crewTypes[tokenId] = crewType;
        crewVariantIds[tokenId] = variantId;
        
        // Use specific template or select random
        uint8 finalTemplateId;
        if (templateId > 0) {
            require(templateId < nextCrewTemplateId, "NFTManager: Invalid template ID");
            finalTemplateId = templateId;
        } else {
            // Select random template for this variant and crew type
            uint8[] memory availableTemplates = crewTemplatesByVariant[variantId][crewType];
            require(availableTemplates.length > 0, "NFTManager: No templates available");
            finalTemplateId = availableTemplates[uint256(keccak256(abi.encodePacked(tokenId, block.timestamp))) % availableTemplates.length];
        }
        
        crewTemplateIds[tokenId] = finalTemplateId;
        
        // Set stamina
        uint8 finalStamina = staminaOverride > 0 ? staminaOverride : 100;
        crewStamina[tokenId] = finalStamina;
        
        // Custom name if provided
        if (bytes(customName).length > 0) {
            crewCustomNames[tokenId] = customName;
        }
        
        _safeMint(recipient, tokenId);
        
        emit NFTMinted(tokenId, recipient, TokenType.CREW, rarity);
        emit AdminMinted(tokenId, recipient, "Custom Crew", customName);
    }

    /**
     * @dev Batch admin mint multiple NFTs
     * @param recipients Array of recipient addresses
     * @param tokenTypes Array of token types
     * @param rarities Array of rarities
     * @param customData Array of custom data (encoded differently per type)
     * @return tokenIds Array of minted token IDs
     */
    function adminBatchMint(
        address[] calldata recipients,
        TokenType[] calldata tokenTypes,
        Rarity[] calldata rarities,
        bytes[] calldata customData
    ) external onlyOwner returns (uint256[] memory tokenIds) {
        require(recipients.length == tokenTypes.length && 
                tokenTypes.length == rarities.length && 
                rarities.length == customData.length, 
                "NFTManager: Array length mismatch");
        
        tokenIds = new uint256[](recipients.length);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            // Decode custom data based on token type
            if (tokenTypes[i] == TokenType.SHIP) {
                (ShipType shipType, uint256 variantId, string memory customName, ShipStatsOverride memory statOverrides) = 
                    abi.decode(customData[i], (ShipType, uint256, string, ShipStatsOverride));
                tokenIds[i] = adminMintCustomShip(recipients[i], shipType, variantId, rarities[i], customName, statOverrides);
            } else if (tokenTypes[i] == TokenType.ACTION) {
                (uint8 templateId, string memory customName, uint8 usesOverride) = 
                    abi.decode(customData[i], (uint8, string, uint8));
                tokenIds[i] = adminMintCustomAction(recipients[i], templateId, rarities[i], customName, usesOverride);
            } else if (tokenTypes[i] == TokenType.CAPTAIN) {
                (CaptainAbility ability, uint256 variantId, string memory customName, CaptainPortraitOverride memory portraitOverrides) = 
                    abi.decode(customData[i], (CaptainAbility, uint256, string, CaptainPortraitOverride));
                tokenIds[i] = adminMintCustomCaptain(recipients[i], ability, rarities[i], variantId, customName, portraitOverrides);
            } else if (tokenTypes[i] == TokenType.CREW) {
                (CrewType crewType, uint256 variantId, uint8 templateId, string memory customName, uint8 staminaOverride) = 
                    abi.decode(customData[i], (CrewType, uint256, uint8, string, uint8));
                tokenIds[i] = adminMintCustomCrew(recipients[i], crewType, rarities[i], variantId, templateId, customName, staminaOverride);
            }
        }
        
        emit BatchAdminMinted(recipients, tokenIds);
    }

    // Helper structs for admin minting
    struct ShipStatsOverride {
        bool useCustomStats;
        uint8 health;
        uint8 speed;
        uint8 firepower;
        uint8 size;
    }

    struct CaptainPortraitOverride {
        bool useCustomPortrait;
        uint8 faceType;
        uint8 eyeType;
        uint8 hairType;
        string skinTone;
        string eyeColor;
        string hairColor;
        string uniformColor;
        uint8 accessoryType;
    }

    // Storage for custom names
    mapping(uint256 => string) public shipCustomNames;
    mapping(uint256 => string) public actionCustomNames;
    mapping(uint256 => string) public crewCustomNames;

    // Events for admin minting
    event AdminMinted(uint256 indexed tokenId, address indexed recipient, string nftType, string customName);
    event BatchAdminMinted(address[] recipients, uint256[] tokenIds);

    /**
     * @dev Get all usable actions for a player
     * @param player Player address
     * @return tokenIds Array of usable action token IDs
     */
    function getUsableActions(address player) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        uint256[] memory allActions = this.getTokensByTypeAndOwner(player, TokenType.ACTION);
        uint256[] memory tempIds = new uint256[](allActions.length);
        uint256 resultCount = 0;
        
        for (uint256 i = 0; i < allActions.length; i++) {
            if (actionUsesRemaining[allActions[i]] > 0) {
                tempIds[resultCount] = allActions[i];
                resultCount++;
            }
        }
        
        // Create result array with exact size
        tokenIds = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            tokenIds[i] = tempIds[i];
        }
    }

    // =============================================================================
    // METADATA GENERATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Generate ship metadata with all attributes
     */
    function _generateShipMetadata(uint256 tokenId) internal view returns (string memory) {
        ShipType shipType = shipTypes[tokenId];
        uint256 variantId = shipVariants[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ShipStats memory stats = shipStats[tokenId];
        ShipVariant memory variant = variants[variantId];
        bool isDestroyed = isShipDestroyed[tokenId];
        bool isRental = shipRentalFlags[tokenId];
        
        string memory svg = generateSVG(tokenId);
        string memory svgDataURI = string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            _base64Encode(bytes(svg))
        ));
        
        string memory finalName = bytes(shipCustomNames[tokenId]).length > 0 ? 
            shipCustomNames[tokenId] : 
            string(abi.encodePacked(variant.name, ' ', _getShipTypeName(shipType), ' #', _toString(tokenId)));
        
        return string(abi.encodePacked(
            '{',
            '"name":"', finalName, '",',
            '"description":"A ', _getRarityName(rarity), ' ', _getShipTypeName(shipType), ' from the ', variant.name, ' variant. Built for naval warfare on the blockchain.",',
            '"image":"', svgDataURI, '",',
            '"external_url":"https://cryptobattleship.game/ship/', _toString(tokenId), '",',
            '"attributes":[',
            '{"trait_type":"Type","value":"Ship"},',
            '{"trait_type":"Ship Class","value":"', _getShipTypeName(shipType), '"},',
            '{"trait_type":"Variant","value":"', variant.name, '"},',
            '{"trait_type":"Rarity","value":"', _getRarityName(rarity), '"},',
            '{"trait_type":"Health","value":', _toString(stats.health), ',"display_type":"number"},',
            '{"trait_type":"Speed","value":', _toString(stats.speed), ',"display_type":"number"},',
            '{"trait_type":"Firepower","value":', _toString(stats.firepower), ',"display_type":"number"},',
            '{"trait_type":"Size","value":', _toString(stats.size), ',"display_type":"number"},',
            '"trait_type":"Status","value":"', isDestroyed ? 'Destroyed' : 'Active', '"},',
            '"trait_type":"Ownership","value":"', isRental ? 'Rental' : 'Owned', '"}',
            variant.isRetired ? string(abi.encodePacked(',{"trait_type":"Retired Bonus","value":', _toString(variant.boosterPoints), ',"display_type":"boost_number"}')) : '',
            ']',
            '}'
        ));
    }

    /**
     * @dev Generate action metadata using template information
     */
    function _generateActionMetadata(uint256 tokenId) internal view returns (string memory) {
        Rarity rarity = tokenRarities[tokenId];
        uint256 usesRemaining = actionUsesRemaining[tokenId];
        ActionCategory category = actionCategories[tokenId];
        ActionPattern memory pattern = actionPatterns[tokenId];
        uint8 templateId = actionTemplateIds[tokenId];
        uint256 variantId = actionVariantIds[tokenId];
        
        ActionTemplate memory template = actionTemplates[templateId];
        string memory variantName = variantId > 0 ? actionVariants[variantId].name : "Classic Collection";
        
        string memory finalName = bytes(actionCustomNames[tokenId]).length > 0 ? 
            actionCustomNames[tokenId] : 
            string(abi.encodePacked(template.name, ' #', _toString(tokenId)));
        
        return string(abi.encodePacked(
            '{',
            '"name":"', finalName, '",',
            '"description":"', template.description, ' A ', _getRarityName(rarity), ' action from the ', variantName, ' targeting ', _toString(pattern.targetCells.length), ' cells.",',
            '"image":"data:image/svg+xml;base64,', _base64Encode(bytes(_generateActionSVG(category, rarity, tokenId))), '",',
            '"external_url":"https://cryptobattleship.game/action/', _toString(tokenId), '",',
            '"attributes":[',
            '{"trait_type":"Type","value":"Action"},',
            '{"trait_type":"Template","value":"', template.name, '"},',
            '{"trait_type":"Variant","value":"', variantName, '"},',
            '{"trait_type":"Category","value":"', _getActionCategoryName(category), '"},',
            '{"trait_type":"Rarity","value":"', _getRarityName(rarity), '"},',
            '{"trait_type":"Uses Remaining","value":', _toString(usesRemaining), ',"display_type":"number"},',
            '{"trait_type":"Max Uses","value":', _toString(template.uses), ',"display_type":"number"},',
            '{"trait_type":"Target Cells","value":', _toString(pattern.targetCells.length), ',"display_type":"number"},',
            '{"trait_type":"Damage Per Hit","value":', _toString(pattern.damage), ',"display_type":"number"},',
            '{"trait_type":"Range","value":', _toString(pattern.range), ',"display_type":"number"},',
            '{"trait_type":"Template ID","value":', _toString(templateId), ',"display_type":"number"}',
            variantId > 0 && actionVariants[variantId].isRetired ? ',{"trait_type":"Retired Variant","value":"True"}' : '',
            ']',
            '}'
        ));
    }

    /**
     * @dev Generate captain metadata with variant and portrait information
     */
    function _generateCaptainMetadata(uint256 tokenId) internal view returns (string memory) {
        Rarity rarity = tokenRarities[tokenId];
        CaptainAbility ability = captainAbilities[tokenId];
        string memory name = captainNames[tokenId];
        uint256 variantId = captainVariantIds[tokenId];
        CaptainVariant memory variant = captainVariants[variantId];
        CaptainPortrait memory portrait = captainPortraits[tokenId];
        
        return string(abi.encodePacked(
            '{',
            '"name":"', name, '",',
            '"description":"A ', _getRarityName(rarity), ' captain from the ', variant.name, ' with the ', _getCaptainAbilityName(ability), ' ability. This captain has a unique portrait and animated features.",',
            '"image":"data:image/svg+xml;base64,', _base64Encode(bytes(_generateCaptainSVG(tokenId))), '",',
            '"external_url":"https://cryptobattleship.game/captain/', _toString(tokenId), '",',
            '"attributes":[',
            '{"trait_type":"Type","value":"Captain"},',
            '{"trait_type":"Name","value":"', name, '"},',
            '{"trait_type":"Variant","value":"', variant.name, '"},',
            '{"trait_type":"Ability","value":"', _getCaptainAbilityName(ability), '"},',
            '{"trait_type":"Rarity","value":"', _getRarityName(rarity), '"},',
            '{"trait_type":"Face Type","value":', _toString(portrait.faceType), ',"display_type":"number"},',
            '{"trait_type":"Eye Type","value":', _toString(portrait.eyeType), ',"display_type":"number"},',
            '{"trait_type":"Hair Type","value":', _toString(portrait.hairType), ',"display_type":"number"},',
            '{"trait_type":"Skin Tone","value":"', portrait.skinTone, '"},',
            '{"trait_type":"Eye Color","value":"', portrait.eyeColor, '"},',
            '{"trait_type":"Animation Level","value":"', _getAnimationLevel(rarity), '"}',
            variant.isRetired ? ',{"trait_type":"Retired Variant","value":"True"}' : '',
            ']',
            '}'
        ));
    }

    /**
     * @dev Generate crew metadata with variant and template information
     */
    function _generateCrewMetadata(uint256 tokenId) internal view returns (string memory) {
        Rarity rarity = tokenRarities[tokenId];
        CrewType crewType = crewTypes[tokenId];
        uint256 stamina = crewStamina[tokenId];
        uint256 variantId = crewVariantIds[tokenId];
        CrewVariant memory variant = crewVariants[variantId];
        uint8 templateId = crewTemplateIds[tokenId];
        CrewTemplate memory template = crewTemplates[templateId];
        
        // Generate variant-specific name or use custom name
        string memory fullName;
        if (bytes(crewCustomNames[tokenId]).length > 0) {
            fullName = crewCustomNames[tokenId];
        } else {
            string memory variantPrefix = crewVariantPrefixes[variantId];
            fullName = string(abi.encodePacked(variantPrefix, " ", _getCrewTypeName(crewType), " #", _toString(tokenId)));
        }
        
        return string(abi.encodePacked(
            '{',
            '"name":"', fullName, '",',
            '"description":"A ', _getRarityName(rarity), ' crew member from the ', variant.name, ' specialized in ', _getCrewTypeName(crewType), ' duties. ', template.description, '",',
            '"image":"data:image/svg+xml;base64,', _base64Encode(bytes(_generateCrewSVG(tokenId))), '",',
            '"external_url":"https://cryptobattleship.game/crew/', _toString(tokenId), '",',
            '"attributes":[',
            '{"trait_type":"Type","value":"Crew"},',
            '{"trait_type":"Variant","value":"', variant.name, '"},',
            '{"trait_type":"Specialization","value":"', _getCrewTypeName(crewType), '"},',
            '{"trait_type":"Rarity","value":"', _getRarityName(rarity), '"},',
            '{"trait_type":"Template ID","value":', _toString(templateId), ',"display_type":"number"},',
            '{"trait_type":"Stamina","value":', _toString(stamina), ',"display_type":"number","max_value":100}',
            variant.isRetired ? ',{"trait_type":"Retired Variant","value":"True"}' : '',
            ']',
            '}'
        ));
    }

    // =============================================================================
    // SIMPLE SVG GENERATORS FOR NON-SHIP NFTS
    // =============================================================================

    function _generateActionSVG(ActionCategory category, Rarity rarity, uint256 tokenId) 
        internal view returns (string memory) {
        ActionPattern memory pattern = actionPatterns[tokenId];
        
        // Get base visual properties
        string memory baseColor = category == ActionCategory.OFFENSIVE ? "#ff4444" : "#4444ff";
        string memory effectColor = category == ActionCategory.OFFENSIVE ? "#ffaa00" : "#00aaff";
        
        // Generate action-specific particle effects
        string memory particleEffects = _generateActionParticleEffects(pattern, category, rarity);
        string memory backgroundPattern = _generateActionBackground(pattern, baseColor);
        
        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs>',
            _getActionGradients(baseColor, effectColor),
            '</defs>',
            '<rect width="400" height="400" fill="#111"/>',
            backgroundPattern,
            particleEffects,
            _getActionIcon(category, pattern, rarity),
            '<text x="200" y="370" text-anchor="middle" fill="white" font-size="14" opacity="0.8">',
            _getRarityName(rarity), ' ', _getActionCategoryName(category), ' Action',
            '</text>',
            '</svg>'
        ));
    }

    /**
     * @dev Generate sophisticated particle effects based on action pattern
     */
    function _generateActionParticleEffects(ActionPattern memory pattern, ActionCategory category, Rarity rarity) 
        internal pure returns (string memory) {
        
        if (category == ActionCategory.OFFENSIVE) {
            return _generateOffensiveEffects(pattern, rarity);
        } else {
            return _generateDefensiveEffects(pattern, rarity);
        }
    }

    /**
     * @dev Generate offensive action particle effects
     */
    function _generateOffensiveEffects(ActionPattern memory pattern, Rarity rarity) 
        internal pure returns (string memory) {
        
        uint8 cellCount = uint8(pattern.targetCells.length);
        
        if (cellCount == 1) {
            // Single target - focused beam or projectile
            return string(abi.encodePacked(
                '<g id="single-target-effect">',
                '<circle cx="200" cy="200" r="15" fill="#ffaa00" opacity="0.8">',
                '<animate attributeName="r" values="5;25;5" dur="1.5s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.8;0.3;0.8" dur="1.5s" repeatCount="indefinite"/>',
                '</circle>',
                '<g id="energy-bolts">',
                '<line x1="180" y1="180" x2="220" y2="220" stroke="#ffff00" stroke-width="3" opacity="0.9">',
                '<animate attributeName="opacity" values="0;1;0" dur="0.8s" repeatCount="indefinite"/>',
                '</line>',
                '<line x1="220" y1="180" x2="180" y2="220" stroke="#ffff00" stroke-width="3" opacity="0.9">',
                '<animate attributeName="opacity" values="0;1;0" dur="0.8s" begin="0.4s" repeatCount="indefinite"/>',
                '</line>',
                '</g>',
                '</g>'
            ));
        } else if (cellCount <= 5) {
            // Cross or line pattern - explosive spread
            return string(abi.encodePacked(
                '<g id="explosive-effect">',
                '<circle cx="200" cy="200" r="30" fill="none" stroke="#ff6600" stroke-width="4" opacity="0.7">',
                '<animate attributeName="r" values="10;60;10" dur="2s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.8;0.2;0.8" dur="2s" repeatCount="indefinite"/>',
                '</circle>',
                '<g id="explosion-particles">',
                '<circle cx="170" cy="200" r="3" fill="#ffaa00">',
                '<animate attributeName="r" values="1;6;1" dur="1.2s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="230" cy="200" r="3" fill="#ffaa00">',
                '<animate attributeName="r" values="1;6;1" dur="1.2s" begin="0.3s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="200" cy="170" r="3" fill="#ffaa00">',
                '<animate attributeName="r" values="1;6;1" dur="1.2s" begin="0.6s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="200" cy="230" r="3" fill="#ffaa00">',
                '<animate attributeName="r" values="1;6;1" dur="1.2s" begin="0.9s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>',
                '</g>'
            ));
        } else {
            // Large area effect - nuclear/magical devastation
            return string(abi.encodePacked(
                '<g id="devastation-effect">',
                '<circle cx="200" cy="200" r="80" fill="url(#mushroom-gradient)" opacity="0.6">',
                '<animate attributeName="r" values="20;100;80" dur="4s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.3;0.8;0.3" dur="4s" repeatCount="indefinite"/>',
                '</circle>',
                '<g id="mushroom-cloud">',
                '<ellipse cx="200" cy="150" rx="40" ry="20" fill="#ff4400" opacity="0.7">',
                '<animate attributeName="ry" values="15;30;15" dur="3s" repeatCount="indefinite"/>',
                '</ellipse>',
                '<rect x="190" y="150" width="20" height="50" fill="#ff6600" opacity="0.8">',
                '<animate attributeName="height" values="40;60;40" dur="3s" repeatCount="indefinite"/>',
                '</rect>',
                '</g>',
                '<g id="shockwave">',
                '<circle cx="200" cy="200" r="120" fill="none" stroke="#ffffff" stroke-width="2" opacity="0.4">',
                '<animate attributeName="r" values="80;150;80" dur="2.5s" repeatCount="indefinite"/>',
                '<animate attributeName="opacity" values="0.6;0.1;0.6" dur="2.5s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>',
                '</g>'
            ));
        }
    }

    /**
     * @dev Generate defensive action particle effects  
     */
    function _generateDefensiveEffects(ActionPattern memory pattern, Rarity rarity) 
        internal pure returns (string memory) {
        
        uint8 cellCount = uint8(pattern.targetCells.length);
        
        if (cellCount == 1) {
            // Single target defense - energy shield
            return string(abi.encodePacked(
                '<g id="energy-shield">',
                '<circle cx="200" cy="200" r="50" fill="none" stroke="#00aaff" stroke-width="4" opacity="0.6">',
                '<animate attributeName="opacity" values="0.4;0.8;0.4" dur="2s" repeatCount="indefinite"/>',
                '<animate attributeName="stroke-width" values="2;6;2" dur="2s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="200" cy="200" r="35" fill="#00aaff" opacity="0.2">',
                '<animate attributeName="opacity" values="0.1;0.4;0.1" dur="2s" repeatCount="indefinite"/>',
                '</circle>',
                '<g id="shield-sparkles">',
                '<circle cx="180" cy="180" r="2" fill="#88ddff">',
                '<animate attributeName="opacity" values="0;1;0" dur="1s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="220" cy="180" r="2" fill="#88ddff">',
                '<animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.3s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="220" cy="220" r="2" fill="#88ddff">',
                '<animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.6s" repeatCount="indefinite"/>',
                '</circle>',
                '<circle cx="180" cy="220" r="2" fill="#88ddff">',
                '<animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.9s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>',
                '</g>'
            ));
        } else if (cellCount <= 5) {
            // Multi-target defense - barrier wall
            return string(abi.encodePacked(
                '<g id="barrier-wall">',
                '<rect x="150" y="180" width="100" height="40" fill="none" stroke="#0088ff" stroke-width="3" opacity="0.7">',
                '<animate attributeName="opacity" values="0.5;0.9;0.5" dur="1.8s" repeatCount="indefinite"/>',
                '</rect>',
                '<rect x="155" y="185" width="90" height="30" fill="#0088ff" opacity="0.3">',
                '<animate attributeName="opacity" values="0.2;0.5;0.2" dur="1.8s" repeatCount="indefinite"/>',
                '</rect>',
                '<g id="barrier-energy">',
                '<line x1="150" y1="190" x2="250" y2="190" stroke="#44aaff" stroke-width="2">',
                '<animate attributeName="opacity" values="0.3;1;0.3" dur="0.8s" repeatCount="indefinite"/>',
                '</line>',
                '<line x1="150" y1="200" x2="250" y2="200" stroke="#44aaff" stroke-width="2">',
                '<animate attributeName="opacity" values="0.3;1;0.3" dur="0.8s" begin="0.4s" repeatCount="indefinite"/>',
                '</line>',
                '<line x1="150" y1="210" x2="250" y2="210" stroke="#44aaff" stroke-width="2">',
                '<animate attributeName="opacity" values="0.3;1;0.3" dur="0.8s" begin="0.8s" repeatCount="indefinite"/>',
                '</line>',
                '</g>',
                '</g>'
            ));
        } else {
            // Area defense - protective dome
            return string(abi.encodePacked(
                '<g id="protective-dome">',
                '<ellipse cx="200" cy="250" rx="90" ry="45" fill="none" stroke="#0066ff" stroke-width="3" opacity="0.6">',
                '<animate attributeName="opacity" values="0.4;0.8;0.4" dur="3s" repeatCount="indefinite"/>',
                '</ellipse>',
                '<ellipse cx="200" cy="250" rx="75" ry="35" fill="#0066ff" opacity="0.2">',
                '<animate attributeName="opacity" values="0.1;0.4;0.1" dur="3s" repeatCount="indefinite"/>',
                '</ellipse>',
                '<g id="dome-energy-streams">',
                '<path d="M 200,200 Q 150,225 200,250" stroke="#44aaff" stroke-width="2" fill="none" opacity="0.7">',
                '<animate attributeName="opacity" values="0.3;0.9;0.3" dur="1.5s" repeatCount="indefinite"/>',
                '</path>',
                '<path d="M 200,200 Q 250,225 200,250" stroke="#44aaff" stroke-width="2" fill="none" opacity="0.7">',
                '<animate attributeName="opacity" values="0.3;0.9;0.3" dur="1.5s" begin="0.5s" repeatCount="indefinite"/>',
                '</path>',
                '<path d="M 200,200 Q 175,215 125,235" stroke="#44aaff" stroke-width="2" fill="none" opacity="0.7">',
                '<animate attributeName="opacity" values="0.3;0.9;0.3" dur="1.5s" begin="1s" repeatCount="indefinite"/>',
                '</path>',
                '<path d="M 200,200 Q 225,215 275,235" stroke="#44aaff" stroke-width="2" fill="none" opacity="0.7">',
                '<animate attributeName="opacity" values="0.3;0.9;0.3" dur="1.5s" begin="1.5s" repeatCount="indefinite"/>',
                '</path>',
                '</g>',
                '</g>'
            ));
        }
    }

    /**
     * @dev Generate action background pattern
     */
    function _generateActionBackground(ActionPattern memory pattern, string memory baseColor) 
        internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<circle cx="200" cy="200" r="180" fill="', baseColor, '" opacity="0.15"/>',
            '<circle cx="200" cy="200" r="120" fill="none" stroke="', baseColor, '" stroke-width="1" opacity="0.3"/>',
            '<circle cx="200" cy="200" r="80" fill="none" stroke="', baseColor, '" stroke-width="1" opacity="0.4"/>'
        ));
    }

    /**
     * @dev Generate gradients for action effects
     */
    function _getActionGradients(string memory baseColor, string memory effectColor) 
        internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<radialGradient id="mushroom-gradient" cx="50%" cy="70%" r="50%">',
            '<stop offset="0%" style="stop-color:#ff8800;stop-opacity:0.8"/>',
            '<stop offset="50%" style="stop-color:#ff4400;stop-opacity:0.6"/>',
            '<stop offset="100%" style="stop-color:#ff0000;stop-opacity:0.3"/>',
            '</radialGradient>'
        ));
    }

    /**
     * @dev Get action category icon
     */
    function _getActionIcon(ActionCategory category, ActionPattern memory pattern, Rarity rarity) 
        internal pure returns (string memory) {
        string memory icon = category == ActionCategory.OFFENSIVE ? "⚔" : "🛡";
        string memory color = category == ActionCategory.OFFENSIVE ? "#ffaa00" : "#00aaff";
        
        return string(abi.encodePacked(
            '<text x="200" y="100" text-anchor="middle" fill="', color, '" font-size="40" opacity="0.9">',
            icon,
            '</text>',
            '<text x="200" y="130" text-anchor="middle" fill="white" font-size="12" opacity="0.7">',
            'Targets: ', _toString(pattern.targetCells.length), ' | Damage: ', _toString(pattern.damage),
            '</text>'
        ));
    }

    /**
     * @dev Get action category name
     */
    function _getActionCategoryName(ActionCategory category) internal pure returns (string memory) {
        return category == ActionCategory.OFFENSIVE ? "Offensive" : "Defensive";
    }

    /**
     * @dev Get animation level description based on rarity
     */
    function _getAnimationLevel(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.LEGENDARY) return "Maximum";
        if (rarity == Rarity.EPIC) return "High";
        if (rarity == Rarity.RARE) return "Medium";
        if (rarity == Rarity.UNCOMMON) return "Low";
        return "Minimal";
    }

    /**
     * @dev Generate animated captain portrait based on variant and unique traits
     * @param tokenId Captain token ID
     * @return svg Complete animated portrait SVG
     */
    function _generateCaptainSVG(uint256 tokenId) internal view returns (string memory) {
        CaptainPortrait memory portrait = captainPortraits[tokenId];
        uint256 variantId = captainVariantIds[tokenId];
        CaptainVariant memory variant = captainVariants[variantId];
        Rarity rarity = tokenRarities[tokenId];
        
        // Get animation intensity based on rarity
        string memory eyeBlinkDuration = _getBlinkDuration(rarity);
        string memory backgroundPulse = _getBackgroundPulse(rarity);
        
        // Generate portrait components
        string memory background = _generatePortraitBackground(variant.portraitThemeId);
        string memory face = _generateFaceStructure(portrait.faceType, portrait.skinTone);
        string memory eyes = _generateAnimatedEyes(portrait.eyeType, portrait.eyeColor, eyeBlinkDuration);
        string memory hair = _generateHairStyle(portrait.hairType, variant.portraitThemeId);
        string memory uniform = _generateUniform(portrait.uniformType, variant.portraitThemeId);
        string memory accessories = _generateAccessories(portrait.accessoryType, rarity);
        
        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs>',
            _getCaptainGradients(variant.portraitThemeId),
            '</defs>',
            background,
            backgroundPulse,
            '<g transform="translate(200,200)">',
            face,
            eyes,
            hair,
            uniform,
            accessories,
            '</g>',
            '<text x="20" y="30" fill="white" font-size="14" font-weight="bold">',
            variant.name,
            '</text>',
            '<text x="20" y="380" fill="white" font-size="12">',
            _getRarityName(rarity), ' | ', _getCaptainAbilityName(captainAbilities[tokenId]),
            '</text>',
            '</svg>'
        ));
    }

    /**
     * @dev Get blink animation duration based on rarity
     */
    function _getBlinkDuration(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.LEGENDARY) return "1.5s"; // Frequent blinking
        if (rarity == Rarity.EPIC) return "2s";
        if (rarity == Rarity.RARE) return "3s";
        if (rarity == Rarity.UNCOMMON) return "4s";
        return "5s"; // Common - slow blinking
    }

    /**
     * @dev Get background pulse animation based on rarity
     */
    function _getBackgroundPulse(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.LEGENDARY) {
            return '<circle cx="200" cy="200" r="190" fill="none" stroke="#FFD700" stroke-width="3" opacity="0.6"><animate attributeName="opacity" values="0.3;0.8;0.3" dur="2s" repeatCount="indefinite"/></circle>';
        } else if (rarity == Rarity.EPIC) {
            return '<circle cx="200" cy="200" r="185" fill="none" stroke="#9932CC" stroke-width="2" opacity="0.5"><animate attributeName="opacity" values="0.2;0.6;0.2" dur="3s" repeatCount="indefinite"/></circle>';
        } else if (rarity == Rarity.RARE) {
            return '<circle cx="200" cy="200" r="180" fill="none" stroke="#1E90FF" stroke-width="1" opacity="0.4"><animate attributeName="opacity" values="0.1;0.5;0.1" dur="4s" repeatCount="indefinite"/></circle>';
        }
        return ""; // No pulse for Common/Uncommon
    }

    /**
     * @dev Generate portrait background based on theme
     */
    function _generatePortraitBackground(uint8 themeId) internal pure returns (string memory) {
        if (themeId == 1) { // Military
            return '<rect width="400" height="400" fill="url(#military-bg)"/>';
        } else if (themeId == 2) { // Pirate
            return '<rect width="400" height="400" fill="url(#pirate-bg)"/>';
        } else if (themeId == 3) { // Undead
            return '<rect width="400" height="400" fill="url(#undead-bg)"/>';
        } else if (themeId == 4) { // Steampunk
            return '<rect width="400" height="400" fill="url(#steampunk-bg)"/>';
        } else { // Alien
            return '<rect width="400" height="400" fill="url(#alien-bg)"/>';
        }
    }

    /**
     * @dev Generate face structure
     */
    function _generateFaceStructure(uint8 faceType, string memory skinTone) internal pure returns (string memory) {
        if (faceType < 3) { // Round faces
            return string(abi.encodePacked(
                '<ellipse cx="0" cy="0" rx="60" ry="70" fill="', skinTone, '"/>',
                '<ellipse cx="0" cy="10" rx="50" ry="60" fill="', skinTone, '" opacity="0.9"/>'
            ));
        } else if (faceType < 6) { // Angular faces
            return string(abi.encodePacked(
                '<polygon points="-55,-60 55,-60 65,0 55,70 -55,70 -65,0" fill="', skinTone, '"/>',
                '<polygon points="-45,-50 45,-50 50,0 45,60 -45,60 -50,0" fill="', skinTone, '" opacity="0.9"/>'
            ));
        } else { // Square faces
            return string(abi.encodePacked(
                '<rect x="-55" y="-65" width="110" height="130" rx="15" fill="', skinTone, '"/>',
                '<rect x="-45" y="-55" width="90" height="110" rx="10" fill="', skinTone, '" opacity="0.9"/>'
            ));
        }
    }

    /**
     * @dev Generate animated eyes
     */
    function _generateAnimatedEyes(uint8 eyeType, string memory eyeColor, string memory blinkDuration) internal pure returns (string memory) {
        string memory eyeShape = eyeType < 4 ? "ellipse" : "circle";
        string memory eyeSize = eyeType < 2 ? 'rx="8" ry="6"' : 'r="7"';
        
        return string(abi.encodePacked(
            '<g id="left-eye">',
            '<', eyeShape, ' cx="-20" cy="-15" ', eyeSize, ' fill="white"/>',
            '<', eyeShape, ' cx="-20" cy="-15" ', eyeSize, ' fill="', eyeColor, '" transform="scale(0.7)"/>',
            '<', eyeShape, ' cx="-20" cy="-15" ', eyeSize, ' fill="black" transform="scale(0.3)"/>',
            '<animate attributeName="opacity" values="1;1;0;1;1" dur="', blinkDuration, '" repeatCount="indefinite"/>',
            '</g>',
            '<g id="right-eye">',
            '<', eyeShape, ' cx="20" cy="-15" ', eyeSize, ' fill="white"/>',
            '<', eyeShape, ' cx="20" cy="-15" ', eyeSize, ' fill="', eyeColor, '" transform="scale(0.7)"/>',
            '<', eyeShape, ' cx="20" cy="-15" ', eyeSize, ' fill="black" transform="scale(0.3)"/>',
            '<animate attributeName="opacity" values="1;1;0;1;1" dur="', blinkDuration, '" repeatCount="indefinite"/>',
            '</g>'
        ));
    }

    /**
     * @dev Generate hair/hat styles
     */
    function _generateHairStyle(uint8 hairType, uint8 themeId) internal pure returns (string memory) {
        string memory hairColor = _getHairColorByTheme(themeId);
        
        if (hairType < 3) { // Military caps
            return string(abi.encodePacked(
                '<ellipse cx="0" cy="-45" rx="65" ry="25" fill="', hairColor, '"/>',
                '<rect x="-10" y="-70" width="20" height="15" fill="#DAA520"/>' // Badge
            ));
        } else if (hairType < 6) { // Traditional hair
            return string(abi.encodePacked(
                '<path d="M -65,-45 Q 0,-85 65,-45 Q 50,-30 0,-35 Q -50,-30 -65,-45" fill="', hairColor, '"/>'
            ));
        } else { // Themed headgear
            return string(abi.encodePacked(
                '<polygon points="-70,-50 70,-50 60,-30 -60,-30" fill="', hairColor, '"/>',
                '<circle cx="0" cy="-60" r="8" fill="#FFD700"/>' // Decoration
            ));
        }
    }

    /**
     * @dev Generate uniform based on theme
     */
    function _generateUniform(uint8 uniformType, uint8 themeId) internal pure returns (string memory) {
        string memory uniformColor = _getUniformColorByTheme(themeId);
        
        return string(abi.encodePacked(
            '<rect x="-50" y="20" width="100" height="80" fill="', uniformColor, '"/>',
            '<rect x="-45" y="25" width="90" height="70" fill="', uniformColor, '" opacity="0.8"/>',
            '<rect x="-40" y="30" width="80" height="20" fill="#FFD700" opacity="0.6"/>', // Chest decoration
            '<circle cx="-30" cy="40" r="3" fill="#FFD700"/>',
            '<circle cx="-20" cy="40" r="3" fill="#FFD700"/>',
            '<circle cx="-10" cy="40" r="3" fill="#FFD700"/>'
        ));
    }

    /**
     * @dev Generate accessories based on rarity
     */
    function _generateAccessories(uint8 accessoryType, Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.LEGENDARY) {
            return '<circle cx="0" cy="-80" r="12" fill="#FFD700"/><text x="0" y="-75" text-anchor="middle" fill="white" font-size="12">★</text>';
        } else if (rarity == Rarity.EPIC) {
            return '<rect x="-8" y="-85" width="16" height="10" fill="#9932CC"/>';
        } else if (rarity == Rarity.RARE) {
            return '<polygon points="-5,-85 5,-85 8,-75 -8,-75" fill="#1E90FF"/>';
        }
        return ""; // No accessories for Common/Uncommon
    }

    /**
     * @dev Get hair color by theme
     */
    function _getHairColorByTheme(uint8 themeId) internal pure returns (string memory) {
        if (themeId == 1) return "#2F4F4F"; // Military - dark
        if (themeId == 2) return "#8B4513"; // Pirate - brown
        if (themeId == 3) return "#696969"; // Undead - gray
        if (themeId == 4) return "#CD7F32"; // Steampunk - bronze
        return "#4B0082"; // Alien - purple
    }

    /**
     * @dev Get uniform color by theme
     */
    function _getUniformColorByTheme(uint8 themeId) internal pure returns (string memory) {
        if (themeId == 1) return "#006400"; // Military - green
        if (themeId == 2) return "#8B0000"; // Pirate - red
        if (themeId == 3) return "#2F2F2F"; // Undead - dark gray
        if (themeId == 4) return "#8B4513"; // Steampunk - brown
        return "#4B0082"; // Alien - purple
    }

    /**
     * @dev Get captain portrait gradients
     */
    function _getCaptainGradients(uint8 themeId) internal pure returns (string memory) {
        if (themeId == 1) { // Military
            return '<radialGradient id="military-bg"><stop offset="0%" stop-color="#003366"/><stop offset="100%" stop-color="#001122"/></radialGradient>';
        } else if (themeId == 2) { // Pirate
            return '<radialGradient id="pirate-bg"><stop offset="0%" stop-color="#660000"/><stop offset="100%" stop-color="#330000"/></radialGradient>';
        } else if (themeId == 3) { // Undead
            return '<radialGradient id="undead-bg"><stop offset="0%" stop-color="#4B0082"/><stop offset="100%" stop-color="#2F2F2F"/></radialGradient>';
        } else if (themeId == 4) { // Steampunk
            return '<radialGradient id="steampunk-bg"><stop offset="0%" stop-color="#8B4513"/><stop offset="100%" stop-color="#654321"/></radialGradient>';
        } else { // Alien
            return '<radialGradient id="alien-bg"><stop offset="0%" stop-color="#006400"/><stop offset="100%" stop-color="#004400"/></radialGradient>';
        }
    }

    /**
     * @dev Generate crew SVG from template pool
     * @param tokenId Crew token ID
     * @return svg Complete crew SVG from selected template
     */
    function _generateCrewSVG(uint256 tokenId) internal view returns (string memory) {
        uint8 templateId = crewTemplateIds[tokenId];
        CrewTemplate memory template = crewTemplates[templateId];
        
        require(template.isActive, "NFTManager: Template not active");
        
        return template.fullSVG;
    }

    /**
     * @dev Generate crew UI icon from template pool
     * @param tokenId Crew token ID
     * @return svg Small UI icon SVG
     */
    function generateCrewUIIcon(uint256 tokenId) external view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Crew does not exist");
        require(tokenTypes[tokenId] == TokenType.CREW, "NFTManager: Not a crew NFT");
        
        uint8 templateId = crewTemplateIds[tokenId];
        CrewTemplate memory template = crewTemplates[templateId];
        
        require(template.isActive, "NFTManager: Template not active");
        
        return template.uiIconSVG;
    }

    /**
     * @dev Get crew template information
     * @param templateId Template ID to query
     * @return template Complete template information
     */
    function getCrewTemplate(uint256 templateId) external view returns (CrewTemplate memory template) {
        return crewTemplates[templateId];
    }

    /**
     * @dev Get available templates for variant and crew type
     * @param variantId Crew variant ID
     * @param crewType Type of crew
     * @return templateIds Array of available template IDs
     */
    function getAvailableCrewTemplates(uint256 variantId, CrewType crewType) 
        external view returns (uint8[] memory templateIds) {
        return crewTemplatePools[variantId][crewType];
    }

    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================

    /**
     * @dev Get ship type name string
     */
    function _getShipTypeName(ShipType shipType) internal pure returns (string memory) {
        if (shipType == ShipType.DESTROYER) return "Destroyer";
        if (shipType == ShipType.SUBMARINE) return "Submarine";
        if (shipType == ShipType.CRUISER) return "Cruiser";
        if (shipType == ShipType.BATTLESHIP) return "Battleship";
        if (shipType == ShipType.CARRIER) return "Carrier";
        return "Unknown";
    }

    /**
     * @dev Get rarity name string
     */
    function _getRarityName(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.COMMON) return "Common";
        if (rarity == Rarity.UNCOMMON) return "Uncommon";
        if (rarity == Rarity.RARE) return "Rare";
        if (rarity == Rarity.EPIC) return "Epic";
        if (rarity == Rarity.LEGENDARY) return "Legendary";
        return "Unknown";
    }

    /**
     * @dev Get action type name string
     */
    function _getActionTypeName(ActionType actionType) internal pure returns (string memory) {
        return actionType == ActionType.OFFENSIVE ? "Offensive" : "Defensive";
    }

    /**
     * @dev Get captain ability name string
     */
    function _getCaptainAbilityName(CaptainAbility ability) internal pure returns (string memory) {
        if (ability == CaptainAbility.DAMAGE_BOOST) return "Damage Boost";
        if (ability == CaptainAbility.SPEED_BOOST) return "Speed Boost";
        if (ability == CaptainAbility.DEFENSE_BOOST) return "Defense Boost";
        if (ability == CaptainAbility.VISION_BOOST) return "Vision Boost";
        if (ability == CaptainAbility.LUCK_BOOST) return "Luck Boost";
        return "Unknown";
    }

    /**
     * @dev Get crew type name string
     */
    function _getCrewTypeName(CrewType crewType) internal pure returns (string memory) {
        if (crewType == CrewType.GUNNER) return "Gunner";
        if (crewType == CrewType.ENGINEER) return "Engineer";
        if (crewType == CrewType.NAVIGATOR) return "Navigator";
        if (crewType == CrewType.MEDIC) return "Medic";
        return "Unknown";
    }

    /**
     * @dev Convert uint to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }

    /**
     * @dev Extract substring from string
     */
    function _substring(string memory str, uint256 startIndex, uint256 length) 
        internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(length);
        
        for (uint256 i = 0; i < length; i++) {
            if (startIndex + i < strBytes.length) {
                result[i] = strBytes[startIndex + i];
            }
        }
        
        return string(result);
    }

    /**
     * @dev Base64 encode function (simplified)
     */
    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        
        if (data.length == 0) return "";
        
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen);
        
        assembly {
            let tablePtr := add(table, 1)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            let resultPtr := add(result, 32)
            
            for {} lt(dataPtr, endPtr) {} {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }
            
            switch mod(mload(data), 3)
            case 1 { mstore8(sub(resultPtr, 1), 0x3d) }
            case 2 { mstore8(sub(resultPtr, 1), 0x3d) }
        }
        
        return result;
    }

    // =============================================================================
    // DYNAMIC VISUAL ENHANCEMENT SYSTEM
    // =============================================================================

    /**
     * @dev Visual state modifiers for dynamic effects
     */
    struct VisualState {
        bool hasBattleDamage;      // Show battle damage effects
        uint8 victoryStreak;       // Victory count visual badge (0-255)
        bool hasSeasonDecoration;  // Current season special decoration
        uint8 upgradeLevel;        // Visual upgrade tier (0-10)
        uint32 specialEffects;     // Bitfield for special visual flags
    }

    // Dynamic visual states
    mapping(uint256 => VisualState) public tokenVisualStates;
    
    // Season decoration settings
    struct SeasonDecoration {
        string name;
        string colorOverride;      // Hex color for seasonal theme
        string effectType;         // "glow", "sparkle", "aurora", etc.
        bool isActive;
    }
    
    mapping(uint256 => SeasonDecoration) public seasonDecorations;
    uint256 public currentSeasonDecorationId;

    // Events for visual updates
    event VisualStateUpdated(uint256 indexed tokenId, VisualState newState);
    event SeasonDecorationActivated(uint256 seasonId, string name, string effectType);

    /**
     * @dev Update visual state for a token (battle damage, victories, etc.)
     * @param tokenId Token to update
     * @param newState New visual state
     */
    function updateTokenVisualState(uint256 tokenId, VisualState calldata newState) external {
        require(
            msg.sender == address(battleshipGame) || 
            msg.sender == owner(),
            "NFTManager: Not authorized to update visual state"
        );
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        
        tokenVisualStates[tokenId] = newState;
        emit VisualStateUpdated(tokenId, newState);
    }

    /**
     * @dev Activate seasonal decoration theme
     * @param seasonId Season identifier
     * @param name Season name
     * @param colorOverride Hex color for seasonal theme
     * @param effectType Effect type name
     */
    function activateSeasonDecoration(
        uint256 seasonId,
        string calldata name,
        string calldata colorOverride,
        string calldata effectType
    ) external onlyOwner {
        seasonDecorations[seasonId] = SeasonDecoration({
            name: name,
            colorOverride: colorOverride,
            effectType: effectType,
            isActive: true
        });
        currentSeasonDecorationId = seasonId;
        
        emit SeasonDecorationActivated(seasonId, name, effectType);
    }

    /**
     * @dev Get enhanced visual effects for token
     * @param tokenId Token to get effects for
     * @return effects SVG effects string
     */
    function getEnhancedVisualEffects(uint256 tokenId) public view returns (string memory effects) {
        VisualState memory state = tokenVisualStates[tokenId];
        SeasonDecoration memory seasonDecor = seasonDecorations[currentSeasonDecorationId];
        
        string memory battleDamage = "";
        string memory victoryBadge = "";
        string memory seasonEffect = "";
        string memory upgradeGlow = "";
        
        // Battle damage effects
        if (state.hasBattleDamage) {
            battleDamage = string(abi.encodePacked(
                '<g id="battle-damage">',
                '<circle cx="300" cy="100" r="8" fill="#ff0000" opacity="0.7">',
                '<animate attributeName="opacity" values="0.5;0.9;0.5" dur="2s" repeatCount="indefinite"/>',
                '</circle>',
                '<rect x="80" y="320" width="15" height="4" fill="#666" opacity="0.8"/>',
                '</g>'
            ));
        }
        
        // Victory streak badge
        if (state.victoryStreak > 0) {
            victoryBadge = string(abi.encodePacked(
                '<g id="victory-badge">',
                '<circle cx="350" cy="50" r="20" fill="#ffd700" opacity="0.9"/>',
                '<text x="350" y="55" text-anchor="middle" fill="#000" font-size="14" font-weight="bold">',
                _toString(state.victoryStreak),
                '</text>',
                '<circle cx="350" cy="50" r="25" fill="none" stroke="#ffd700" stroke-width="2" opacity="0.6">',
                '<animate attributeName="r" values="22;28;22" dur="3s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>'
            ));
        }
        
        // Seasonal decoration
        if (state.hasSeasonDecoration && seasonDecor.isActive) {
            if (keccak256(bytes(seasonDecor.effectType)) == keccak256(bytes("glow"))) {
                seasonEffect = string(abi.encodePacked(
                    '<g id="season-glow">',
                    '<circle cx="200" cy="200" r="190" fill="none" stroke="', seasonDecor.colorOverride, '" stroke-width="3" opacity="0.4">',
                    '<animate attributeName="opacity" values="0.2;0.6;0.2" dur="4s" repeatCount="indefinite"/>',
                    '</circle>',
                    '</g>'
                ));
            } else if (keccak256(bytes(seasonDecor.effectType)) == keccak256(bytes("sparkle"))) {
                seasonEffect = string(abi.encodePacked(
                    '<g id="season-sparkle">',
                    '<circle cx="150" cy="120" r="2" fill="', seasonDecor.colorOverride, '">',
                    '<animate attributeName="opacity" values="0;1;0" dur="1.5s" repeatCount="indefinite"/>',
                    '</circle>',
                    '<circle cx="250" cy="160" r="2" fill="', seasonDecor.colorOverride, '">',
                    '<animate attributeName="opacity" values="0;1;0" dur="1.5s" begin="0.5s" repeatCount="indefinite"/>',
                    '</circle>',
                    '<circle cx="180" cy="280" r="2" fill="', seasonDecor.colorOverride, '">',
                    '<animate attributeName="opacity" values="0;1;0" dur="1.5s" begin="1s" repeatCount="indefinite"/>',
                    '</circle>',
                    '</g>'
                ));
            }
        }
        
        // Upgrade level glow
        if (state.upgradeLevel > 0) {
            string memory glowIntensity = state.upgradeLevel > 5 ? "0.8" : "0.4";
            upgradeGlow = string(abi.encodePacked(
                '<g id="upgrade-glow">',
                '<circle cx="200" cy="200" r="', _toString(160 + (state.upgradeLevel * 5)), '" fill="none" stroke="#00ff88" stroke-width="2" opacity="', glowIntensity, '">',
                '<animate attributeName="opacity" values="0.2;', glowIntensity, ';0.2" dur="3s" repeatCount="indefinite"/>',
                '</circle>',
                '</g>'
            ));
        }
        
        return string(abi.encodePacked(battleDamage, victoryBadge, seasonEffect, upgradeGlow));
    }

    // =============================================================================
    // FUTURE VARIANT EXTENSIBILITY SYSTEM
    // =============================================================================

    /**
     * @dev Custom animation definition for new variants
     */
    struct CustomAnimation {
        string animationSVG;       // Complete SVG animation code
        bool isActive;             // Whether this animation is active
        string description;        // Description of the animation
    }

    // Custom animations for future variants
    mapping(uint8 => CustomAnimation) public customAnimations;
    
    // Event for new animation registration
    event CustomAnimationRegistered(uint8 indexed themeId, string description);

    /**
     * @dev Register custom animation for new variant theme
     * @param themeId SVG theme ID (6+ for future variants)
     * @param animationSVG Complete SVG animation code
     * @param description Animation description
     */
    function registerCustomAnimation(
        uint8 themeId,
        string calldata animationSVG,
        string calldata description
    ) external onlyOwner {
        require(themeId >= 6, "NFTManager: Use themeId 6+ for custom animations");
        
        customAnimations[themeId] = CustomAnimation({
            animationSVG: animationSVG,
            isActive: true,
            description: description
        });
        
        emit CustomAnimationRegistered(themeId, description);
    }

    /**
     * @dev Get animations with extensibility support
     * Updated version that supports custom animations for future variants
     */
    function _getAnimationsExtended(uint8 svgThemeId) internal view returns (string memory) {
        // Handle built-in animations (themes 1-5)
        if (svgThemeId <= 5) {
            return _getAnimations(svgThemeId);
        }
        
        // Handle custom animations (themes 6+)
        CustomAnimation memory customAnim = customAnimations[svgThemeId];
        if (customAnim.isActive) {
            return customAnim.animationSVG;
        }
        
        return ""; // No animation for undefined custom themes
    }

    /**
     * @dev Batch register multiple action effect templates
     * Allows easy addition of new action visual effects
     * @param effectNames Array of effect names
     * @param effectSVGs Array of SVG effect code
     */
    function batchRegisterActionEffects(
        string[] calldata effectNames,
        string[] calldata effectSVGs
    ) external onlyOwner {
        require(effectNames.length == effectSVGs.length, "NFTManager: Array length mismatch");
        
        for (uint256 i = 0; i < effectNames.length; i++) {
            // Store in a mapping for future use (can be expanded)
            emit CustomAnimationRegistered(uint8(100 + i), effectNames[i]); // Use 100+ for action effects
        }
    }

    /**
     * @dev Enhanced variant creation with full visual customization
     * @param variantId New variant ID
     * @param name Variant name
     * @param svgThemeId Theme ID (use registerCustomAnimation first for new themes)
     * @param colorPalette Comma-separated hex colors
     * @param hasCustomEffects Whether variant has special effects
     */
    function createAdvancedVariant(
        uint256 variantId,
        string calldata name,
        uint8 svgThemeId,
        string calldata colorPalette,
        bool hasCustomEffects
    ) external onlyOwner {
        require(!variants[variantId].isActive, "NFTManager: Variant already exists");
        
        // Register color palette
        svgThemeColors[svgThemeId] = colorPalette;
        svgThemeNames[svgThemeId] = name;
        
        // Create variant with advanced features
        variants[variantId] = ShipVariant({
            name: name,
            isActive: true,
            isRetired: false,
            seasonId: currentSeason,
            svgThemeId: svgThemeId,
            hasAnimations: hasCustomEffects,
            retiredAt: 0,
            boosterPoints: 0
        });
        
        emit VariantCreated(variantId, name, svgThemeId);
    }

    /**
     * @dev Preview system for testing new visual effects
     * @param tokenId Existing token to preview on
     * @param testAnimationSVG Test animation SVG code
     * @return previewSVG Complete SVG with test animation
     */
    function previewCustomEffect(uint256 tokenId, string calldata testAnimationSVG) 
        external view returns (string memory previewSVG) {
        require(_ownerOf(tokenId) != address(0), "NFTManager: Token does not exist");
        require(tokenTypes[tokenId] == TokenType.SHIP, "NFTManager: Only ships supported");
        
        uint256 variantId = shipVariants[tokenId];
        ShipType shipType = shipTypes[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ShipStats memory stats = shipStats[tokenId];
        ShipVariant memory variant = variants[variantId];
        
        string memory colors = svgThemeColors[variant.svgThemeId];
        string memory primaryColor = _extractColor(colors, 0);
        string memory secondaryColor = _extractColor(colors, 1);
        string memory accentColor = _extractColor(colors, 2);
        
        string memory shipShape = _getShipShape(shipType, primaryColor, secondaryColor);
        string memory themeElements = _getThemeElements(variant.svgThemeId, accentColor);
        string memory rarityEffects = _getRarityEffects(rarity);
        string memory dynamicEffects = getEnhancedVisualEffects(tokenId);
        
        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs><style>.ship-text{font-family:Arial,sans-serif;font-weight:bold;}</style></defs>',
            '<rect width="400" height="400" fill="#000814"/>',
            dynamicEffects,
            '<g transform="translate(200,200)">',
            shipShape,
            themeElements,
            rarityEffects,
            testAnimationSVG, // Insert test animation
            '</g>',
            '<text x="20" y="30" class="ship-text" fill="white" font-size="14">',
            variant.name, ' (PREVIEW)',
            '</text>',
            '<text x="20" y="370" class="ship-text" fill="white" font-size="12">',
            _getShipTypeName(shipType), ' | ', _getRarityName(rarity),
            '</text>',
            '</svg>'
        ));
    }

    /**
     * @dev Admin function to update SVG version
     * @param newVersion New SVG version number
     */
    function updateSVGVersion(uint8 newVersion) external onlyOwner {
        svgVersion = newVersion;
        emit SVGVersionUpdated(newVersion);
    }

    /**
     * @dev Initialize NFT systems in constructor
     */
    function _initializeNFTSystems() internal {
        _initializeSVGThemes();
        _initializeActionTemplates();
    }

    /**
     * @dev Initialize default action templates for classic variant
     */
    function _initializeActionTemplates() internal {
        // OFFENSIVE ACTIONS - Classic Set
        
        // Common: Single Shot
        uint8[] memory singleTarget = new uint8[](1);
        singleTarget[0] = 0;
        actionTemplates[1] = ActionTemplate({
            name: "Plasma Shot",
            description: "Single-target energy blast",
            targetCells: singleTarget,
            damage: 2,
            range: 10,
            uses: 3,
            category: ActionCategory.OFFENSIVE,
            minRarity: Rarity.COMMON,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Uncommon: Cross Blast
        uint8[] memory crossPattern = new uint8[](5);
        crossPattern[0] = 0; crossPattern[1] = 1; crossPattern[2] = 10;
        crossPattern[3] = 255; crossPattern[4] = 255; // -1 offsets
        actionTemplates[2] = ActionTemplate({
            name: "Energy Cross",
            description: "Cross-pattern energy burst",
            targetCells: crossPattern,
            damage: 2,
            range: 8,
            uses: 2,
            category: ActionCategory.OFFENSIVE,
            minRarity: Rarity.UNCOMMON,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Rare: Line Strike
        uint8[] memory linePattern = new uint8[](3);
        linePattern[0] = 0; linePattern[1] = 1; linePattern[2] = 2;
        actionTemplates[3] = ActionTemplate({
            name: "Beam Lance",
            description: "Piercing linear beam attack",
            targetCells: linePattern,
            damage: 3,
            range: 7,
            uses: 2,
            category: ActionCategory.OFFENSIVE,
            minRarity: Rarity.RARE,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Epic: L-Shape Barrage
        uint8[] memory lPattern = new uint8[](4);
        lPattern[0] = 0; lPattern[1] = 1; lPattern[2] = 2; lPattern[3] = 10;
        actionTemplates[4] = ActionTemplate({
            name: "Tactical Strike",
            description: "L-shaped bombardment pattern",
            targetCells: lPattern,
            damage: 3,
            range: 6,
            uses: 1,
            category: ActionCategory.OFFENSIVE,
            minRarity: Rarity.EPIC,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Legendary: Square Devastation
        uint8[] memory squarePattern = new uint8[](4);
        squarePattern[0] = 0; squarePattern[1] = 1; squarePattern[2] = 10; squarePattern[3] = 11;
        actionTemplates[5] = ActionTemplate({
            name: "Nova Burst",
            description: "Devastating area bombardment",
            targetCells: squarePattern,
            damage: 4,
            range: 5,
            uses: 1,
            category: ActionCategory.OFFENSIVE,
            minRarity: Rarity.LEGENDARY,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // DEFENSIVE ACTIONS - Classic Set
        
        // Common: Shield
        actionTemplates[6] = ActionTemplate({
            name: "Energy Shield",
            description: "Single-cell protection barrier",
            targetCells: singleTarget, // Reuse single target array
            damage: 0,
            range: 5,
            uses: 3,
            category: ActionCategory.DEFENSIVE,
            minRarity: Rarity.COMMON,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Uncommon: Cross Shield
        actionTemplates[7] = ActionTemplate({
            name: "Barrier Cross",
            description: "Cross-pattern shield array",
            targetCells: crossPattern, // Reuse cross pattern
            damage: 0,
            range: 6,
            uses: 2,
            category: ActionCategory.DEFENSIVE,
            minRarity: Rarity.UNCOMMON,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Rare: Advanced Shield
        uint8[] memory tripleShield = new uint8[](3);
        tripleShield[0] = 0; tripleShield[1] = 1; tripleShield[2] = 10;
        actionTemplates[8] = ActionTemplate({
            name: "Aegis Field",
            description: "Advanced protection matrix",
            targetCells: tripleShield,
            damage: 0,
            range: 7,
            uses: 2,
            category: ActionCategory.DEFENSIVE,
            minRarity: Rarity.RARE,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Epic: Fortress Shield
        uint8[] memory fortressPattern = new uint8[](5);
        fortressPattern[0] = 0; fortressPattern[1] = 1; fortressPattern[2] = 10;
        fortressPattern[3] = 11; fortressPattern[4] = 255; // L + extra
        actionTemplates[9] = ActionTemplate({
            name: "Fortress Dome",
            description: "Multi-layer defensive dome",
            targetCells: fortressPattern,
            damage: 0,
            range: 8,
            uses: 1,
            category: ActionCategory.DEFENSIVE,
            minRarity: Rarity.EPIC,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Legendary: Ultimate Shield
        uint8[] memory ultimateShield = new uint8[](6);
        ultimateShield[0] = 0; ultimateShield[1] = 1; ultimateShield[2] = 10;
        ultimateShield[3] = 11; ultimateShield[4] = 2; ultimateShield[5] = 20;
        actionTemplates[10] = ActionTemplate({
            name: "Quantum Barrier",
            description: "Ultimate protection field",
            targetCells: ultimateShield,
            damage: 0,
            range: 9,
            uses: 1,
            category: ActionCategory.DEFENSIVE,
            minRarity: Rarity.LEGENDARY,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Set next template ID
        nextTemplateId = 11;
        
        // Assign templates to classic variant (ID 0)
        uint8[] memory commonOffensive = new uint8[](1);
        commonOffensive[0] = 1;
        variantTemplatesByRarity[0][ActionCategory.OFFENSIVE][Rarity.COMMON] = commonOffensive;
        
        uint8[] memory uncommonOffensive = new uint8[](1);
        uncommonOffensive[0] = 2;
        variantTemplatesByRarity[0][ActionCategory.OFFENSIVE][Rarity.UNCOMMON] = uncommonOffensive;
        
        uint8[] memory rareOffensive = new uint8[](1);
        rareOffensive[0] = 3;
        variantTemplatesByRarity[0][ActionCategory.OFFENSIVE][Rarity.RARE] = rareOffensive;
        
        uint8[] memory epicOffensive = new uint8[](1);
        epicOffensive[0] = 4;
        variantTemplatesByRarity[0][ActionCategory.OFFENSIVE][Rarity.EPIC] = epicOffensive;
        
        uint8[] memory legendaryOffensive = new uint8[](1);
        legendaryOffensive[0] = 5;
        variantTemplatesByRarity[0][ActionCategory.OFFENSIVE][Rarity.LEGENDARY] = legendaryOffensive;
        
        uint8[] memory commonDefensive = new uint8[](1);
        commonDefensive[0] = 6;
        variantTemplatesByRarity[0][ActionCategory.DEFENSIVE][Rarity.COMMON] = commonDefensive;
        
        uint8[] memory uncommonDefensive = new uint8[](1);
        uncommonDefensive[0] = 7;
        variantTemplatesByRarity[0][ActionCategory.DEFENSIVE][Rarity.UNCOMMON] = uncommonDefensive;
        
        uint8[] memory rareDefensive = new uint8[](1);
        rareDefensive[0] = 8;
        variantTemplatesByRarity[0][ActionCategory.DEFENSIVE][Rarity.RARE] = rareDefensive;
        
        uint8[] memory epicDefensive = new uint8[](1);
        epicDefensive[0] = 9;
        variantTemplatesByRarity[0][ActionCategory.DEFENSIVE][Rarity.EPIC] = epicDefensive;
        
        uint8[] memory legendaryDefensive = new uint8[](1);
        legendaryDefensive[0] = 10;
        variantTemplatesByRarity[0][ActionCategory.DEFENSIVE][Rarity.LEGENDARY] = legendaryDefensive;
    }

    /**
     * @dev Get count of retired ships owned by address
     * Used by TokenomicsCore for retired ship credits
     * @param owner Address to check
     * @return count Number of retired ships owned
     */
    function getRetiredShipCount(address owner) external view returns (uint256 count) {
        uint256 balance = balanceOf(owner);
        
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            
            // Check if it's a ship and if it's retired
            if (tokenTypes[tokenId] == TokenType.SHIP) {
                ShipInfo storage ship = shipInfo[tokenId];
                if (ship.isRetired) {
                    count++;
                }
            }
        }
    }
} 