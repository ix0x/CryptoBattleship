// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CaptainAndCrewNFTManager
 * @dev Manages Captain and Crew NFTs with placard SVGs
 * @notice Handles fleet leadership and crew member NFTs
 */
contract CaptainAndCrewNFTManager is ERC721, ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // =============================================================================
    // ENUMS AND STRUCTS
    // =============================================================================

    /**
     * @dev NFT Type enumeration
     */
    enum NFTType {
        CAPTAIN,   // 0: Fleet-wide ability providers
        CREW       // 1: Individual ship enhancers
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

    /**
     * @dev Captain portrait characteristics
     */
    struct CaptainPortrait {
        uint8 faceType;      // Face structure variant (1-10)
        uint8 eyeType;       // Eye shape variant (1-8)
        uint8 hairType;      // Hair style variant (1-12)
        uint8 uniformType;   // Uniform variant (1-6)
        uint8 accessoryType; // Accessory variant (1-15)
        string skinTone;     // Skin color hex
        string eyeColor;     // Eye color hex
        string hairColor;    // Hair color hex
    }

    /**
     * @dev Captain statistics and info
     */
    struct CaptainInfo {
        string name;                    // Generated captain name
        CaptainAbility ability;         // Primary ability
        uint8 abilityPower;            // Ability strength (1-10)
        uint256 experience;            // Experience points
        uint8 leadership;              // Leadership rating (1-100)
        uint8 tactics;                 // Tactical skill (1-100)
        uint8 morale;                  // Morale bonus (1-100)
        CaptainPortrait portrait;      // Visual characteristics
        uint256 variantId;             // Variant/theme ID
    }

    /**
     * @dev Crew member info and stats
     */
    struct CrewInfo {
        string name;           // Generated crew name
        CrewType crewType;     // Specialization type
        uint8 skillLevel;      // Skill level (1-10)
        uint8 stamina;         // Current stamina (0-100)
        uint8 maxStamina;      // Maximum stamina
        uint256 experience;    // Experience points
        uint8 efficiency;      // Work efficiency (1-100)
        uint8 loyalty;         // Loyalty rating (1-100)
        uint256 lastUsed;      // Last time stamina was used
        uint256 variantId;     // Variant/theme ID
    }

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    // Token tracking
    uint256 private _nextTokenId = 1;
    mapping(uint256 => NFTType) public tokenTypes;
    mapping(uint256 => Rarity) public tokenRarities;

    // Captain storage
    mapping(uint256 => CaptainInfo) public captainInfo;
    mapping(uint256 => CaptainAbility) public captainAbilities;

    // Crew storage
    mapping(uint256 => CrewInfo) public crewInfo;
    mapping(uint256 => CrewType) public crewTypes;

    // SVG system
    uint8 public svgVersion = 1;
    mapping(uint8 => string) private svgThemeColors;
    mapping(uint8 => string) private svgThemeNames;

    // Name generation
    string[] private captainFirstNames;
    string[] private captainLastNames;
    string[] private crewFirstNames;
    string[] private crewLastNames;

    // Stamina system constants
    uint256 public constant STAMINA_REGEN_TIME = 8 hours;   // Time to regen 1 stamina
    uint256 public constant STAMINA_USAGE_GAME = 10;        // Stamina used per game

    // Authorized minters
    mapping(address => bool) public authorizedMinters;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event CaptainMinted(uint256 indexed tokenId, address indexed owner, CaptainAbility ability, Rarity rarity);
    event CrewMinted(uint256 indexed tokenId, address indexed owner, CrewType crewType, Rarity rarity);
    event CrewStaminaUsed(uint256 indexed tokenId, address indexed user, uint8 staminaUsed, uint8 staminaRemaining);
    event CrewStaminaRegen(uint256 indexed tokenId, uint8 newStamina);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);
    event SVGVersionUpdated(uint8 newVersion);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _initialAdmin) ERC721("CryptoBattleship Captains & Crew", "CBCREW") Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "CaptainAndCrewNFTManager: Initial admin cannot be zero address");
        _initializeNames();
        _initializeSVGThemes();
    }

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "CaptainAndCrewNFTManager: Not authorized to mint");
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
        require(minter != address(0), "CaptainAndCrewNFTManager: Invalid minter address");
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
     * @dev Mint captain NFT
     * @param recipient Address to receive the captain
     * @param ability Captain's primary ability
     * @param rarity Rarity level
     * @return tokenId Minted token ID
     */
    function mintCaptain(address recipient, CaptainAbility ability, Rarity rarity) 
        external 
        onlyAuthorizedMinter
        whenNotPaused
        returns (uint256 tokenId) 
    {
        require(recipient != address(0), "CaptainAndCrewNFTManager: Cannot mint to zero address");
        
        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        
        // Set token properties
        tokenTypes[tokenId] = NFTType.CAPTAIN;
        tokenRarities[tokenId] = rarity;
        captainAbilities[tokenId] = ability;
        
        // Generate captain info
        captainInfo[tokenId] = _generateCaptainInfo(tokenId, ability, rarity);
        
        emit CaptainMinted(tokenId, recipient, ability, rarity);
        return tokenId;
    }

    /**
     * @dev Mint crew NFT
     * @param recipient Address to receive the crew
     * @param crewType Crew specialization type
     * @param rarity Rarity level
     * @return tokenId Minted token ID
     */
    function mintCrew(address recipient, CrewType crewType, Rarity rarity) 
        external 
        onlyAuthorizedMinter
        whenNotPaused
        returns (uint256 tokenId) 
    {
        require(recipient != address(0), "CaptainAndCrewNFTManager: Cannot mint to zero address");
        
        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        
        // Set token properties
        tokenTypes[tokenId] = NFTType.CREW;
        tokenRarities[tokenId] = rarity;
        crewTypes[tokenId] = crewType;
        
        // Generate crew info
        crewInfo[tokenId] = _generateCrewInfo(tokenId, crewType, rarity);
        
        emit CrewMinted(tokenId, recipient, crewType, rarity);
        return tokenId;
    }

    // =============================================================================
    // SVG GENERATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Generate placard SVG for captain NFT
     * @param tokenId Token ID to generate placard for
     * @return svg Complete placard SVG string
     */
    function generateCaptainPlacardSVG(uint256 tokenId) external view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: Token does not exist");
        require(tokenTypes[tokenId] == NFTType.CAPTAIN, "CaptainAndCrewNFTManager: Not a captain NFT");
        
        CaptainInfo memory info = captainInfo[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        
        return _buildCaptainPlacardSVG(tokenId, info, rarity);
    }

    /**
     * @dev Generate placard SVG for crew NFT
     * @param tokenId Token ID to generate placard for
     * @return svg Complete placard SVG string
     */
    function generateCrewPlacardSVG(uint256 tokenId) external view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: Token does not exist");
        require(tokenTypes[tokenId] == NFTType.CREW, "CaptainAndCrewNFTManager: Not a crew NFT");
        
        CrewInfo memory info = crewInfo[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        
        return _buildCrewPlacardSVG(tokenId, info, rarity);
    }

    /**
     * @dev Build captain placard SVG
     */
    function _buildCaptainPlacardSVG(
        uint256 tokenId,
        CaptainInfo memory info,
        Rarity rarity
    ) internal view returns (string memory) {
        string memory rarityColor = _getRarityColor(rarity);
        
        return string(abi.encodePacked(
            '<svg width="300" height="420" xmlns="http://www.w3.org/2000/svg">',
            '<defs><style>.text{font-family:Arial,sans-serif;font-weight:bold;}</style></defs>',
            '<rect width="300" height="420" fill="#0f1419" stroke="', rarityColor, '" stroke-width="3"/>',
            
            // Header
            '<rect x="10" y="10" width="280" height="60" fill="', rarityColor, '" opacity="0.8"/>',
            '<text x="150" y="35" text-anchor="middle" fill="white" class="text" font-size="16">', info.name, '</text>',
            '<text x="150" y="55" text-anchor="middle" fill="white" class="text" font-size="12">Captain - ', _getRarityName(rarity), '</text>',
            
            // Portrait area
            '<rect x="20" y="80" width="260" height="180" fill="#1a1a2e" stroke="#444"/>',
            _generateCaptainPortrait(info.portrait, rarityColor),
            
            // Stats section
            '<rect x="10" y="270" width="280" height="140" fill="#333" stroke="', rarityColor, '"/>',
            '<text x="20" y="290" fill="white" class="text" font-size="12">Ability: ', _getAbilityName(info.ability), '</text>',
            '<text x="20" y="310" fill="white" class="text" font-size="12">Power: ', _toString(info.abilityPower), '/10</text>',
            '<text x="160" y="310" fill="white" class="text" font-size="12">XP: ', _toString(info.experience), '</text>',
            '<text x="20" y="330" fill="white" class="text" font-size="12">Leadership: ', _toString(info.leadership), '</text>',
            '<text x="160" y="330" fill="white" class="text" font-size="12">Tactics: ', _toString(info.tactics), '</text>',
            '<text x="20" y="350" fill="white" class="text" font-size="12">Morale: ', _toString(info.morale), '</text>',
            
            '</svg>'
        ));
    }

    /**
     * @dev Build crew placard SVG
     */
    function _buildCrewPlacardSVG(
        uint256 tokenId,
        CrewInfo memory info,
        Rarity rarity
    ) internal view returns (string memory) {
        string memory rarityColor = _getRarityColor(rarity);
        
        return string(abi.encodePacked(
            '<svg width="300" height="420" xmlns="http://www.w3.org/2000/svg">',
            '<defs><style>.text{font-family:Arial,sans-serif;font-weight:bold;}</style></defs>',
            '<rect width="300" height="420" fill="#0f1419" stroke="', rarityColor, '" stroke-width="3"/>',
            
            // Header
            '<rect x="10" y="10" width="280" height="60" fill="', rarityColor, '" opacity="0.8"/>',
            '<text x="150" y="35" text-anchor="middle" fill="white" class="text" font-size="16">', info.name, '</text>',
            '<text x="150" y="55" text-anchor="middle" fill="white" class="text" font-size="12">', _getCrewTypeName(info.crewType), ' - ', _getRarityName(rarity), '</text>',
            
            // Avatar area
            '<rect x="20" y="80" width="260" height="180" fill="#1a1a2e" stroke="#444"/>',
            _generateCrewAvatar(info.crewType, rarity, rarityColor),
            
            // Stats section
            '<rect x="10" y="270" width="280" height="140" fill="#333" stroke="', rarityColor, '"/>',
            '<text x="20" y="290" fill="white" class="text" font-size="12">Skill Level: ', _toString(info.skillLevel), '/10</text>',
            '<text x="160" y="290" fill="white" class="text" font-size="12">XP: ', _toString(info.experience), '</text>',
            '<text x="20" y="310" fill="white" class="text" font-size="12">Stamina: ', _toString(info.stamina), '/', _toString(info.maxStamina), '</text>',
            '<text x="160" y="310" fill="white" class="text" font-size="12">Efficiency: ', _toString(info.efficiency), '</text>',
            '<text x="20" y="330" fill="white" class="text" font-size="12">Loyalty: ', _toString(info.loyalty), '</text>',
            
            // Stamina bar
            _generateStaminaBar(info.stamina, info.maxStamina),
            
            '</svg>'
        ));
    }

    // =============================================================================
    // CREW STAMINA SYSTEM
    // =============================================================================

    /**
     * @dev Use crew stamina (called by game contract)
     * @param tokenId Crew token ID
     * @param user Address using the crew
     */
    function useCrewStamina(uint256 tokenId, address user) external {
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: Crew does not exist");
        require(tokenTypes[tokenId] == NFTType.CREW, "CaptainAndCrewNFTManager: Not a crew NFT");
        require(ownerOf(tokenId) == user, "CaptainAndCrewNFTManager: Not owner of crew");
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(), 
            "CaptainAndCrewNFTManager: Not authorized to use stamina"
        );
        
        CrewInfo storage crew = crewInfo[tokenId];
        
        // Regenerate stamina first
        _regenStamina(tokenId);
        
        require(crew.stamina >= STAMINA_USAGE_GAME, "CaptainAndCrewNFTManager: Insufficient stamina");
        
        crew.stamina -= uint8(STAMINA_USAGE_GAME);
        crew.lastUsed = block.timestamp;
        
        emit CrewStaminaUsed(tokenId, user, uint8(STAMINA_USAGE_GAME), crew.stamina);
    }

    /**
     * @dev Check if crew can be used (has enough stamina)
     * @param tokenId Crew token ID
     * @return canUse True if crew has enough stamina
     * @return currentStamina Current stamina after regen
     */
    function canUseCrew(uint256 tokenId) 
        external 
        view 
        returns (bool canUse, uint8 currentStamina) 
    {
        if (_ownerOf(tokenId) == address(0)) return (false, 0);
        if (tokenTypes[tokenId] != NFTType.CREW) return (false, 0);
        
        currentStamina = _getStaminaWithRegen(tokenId);
        canUse = currentStamina >= STAMINA_USAGE_GAME;
    }

    /**
     * @dev Get crew stamina with regeneration calculated
     * @param tokenId Crew token ID
     * @return stamina Current stamina including regen
     */
    function getCrewStamina(uint256 tokenId) external view returns (uint8 stamina) {
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: Crew does not exist");
        require(tokenTypes[tokenId] == NFTType.CREW, "CaptainAndCrewNFTManager: Not a crew NFT");
        
        return _getStaminaWithRegen(tokenId);
    }

    /**
     * @dev Internal function to regenerate stamina
     * @param tokenId Crew token ID
     */
    function _regenStamina(uint256 tokenId) internal {
        CrewInfo storage crew = crewInfo[tokenId];
        
        if (crew.stamina >= crew.maxStamina) return;
        
        uint256 timePassed = block.timestamp - crew.lastUsed;
        uint256 staminaToRegen = timePassed / STAMINA_REGEN_TIME;
        
        if (staminaToRegen > 0) {
            uint8 newStamina = crew.stamina + uint8(staminaToRegen);
            if (newStamina > crew.maxStamina) newStamina = crew.maxStamina;
            
            crew.stamina = newStamina;
            emit CrewStaminaRegen(tokenId, newStamina);
        }
    }

    /**
     * @dev Get stamina with regeneration calculated (view function)
     * @param tokenId Crew token ID
     * @return stamina Current stamina including regen
     */
    function _getStaminaWithRegen(uint256 tokenId) internal view returns (uint8 stamina) {
        CrewInfo memory crew = crewInfo[tokenId];
        
        if (crew.stamina >= crew.maxStamina) return crew.stamina;
        
        uint256 timePassed = block.timestamp - crew.lastUsed;
        uint256 staminaToRegen = timePassed / STAMINA_REGEN_TIME;
        
        uint8 newStamina = crew.stamina + uint8(staminaToRegen);
        if (newStamina > crew.maxStamina) newStamina = crew.maxStamina;
        
        return newStamina;
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get complete captain information
     * @param tokenId Captain token ID
     * @return info Captain information struct
     */
    function getCaptainInfo(uint256 tokenId) external view returns (CaptainInfo memory info) {
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: Captain does not exist");
        require(tokenTypes[tokenId] == NFTType.CAPTAIN, "CaptainAndCrewNFTManager: Not a captain NFT");
        
        return captainInfo[tokenId];
    }

    /**
     * @dev Get complete crew information
     * @param tokenId Crew token ID
     * @return info Crew information struct
     */
    function getCrewInfo(uint256 tokenId) external view returns (CrewInfo memory info) {
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: Crew does not exist");
        require(tokenTypes[tokenId] == NFTType.CREW, "CaptainAndCrewNFTManager: Not a crew NFT");
        
        return crewInfo[tokenId];
    }

    /**
     * @dev Get NFTs owned by address filtered by type
     * @param owner Address to query
     * @param nftType Type filter (CAPTAIN or CREW)
     * @return tokenIds Array of owned token IDs
     */
    function getOwnedByType(address owner, NFTType nftType) external view returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(owner);
        uint256[] memory temp = new uint256[](balance);
        uint256 count = 0;
        
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            if (tokenTypes[tokenId] == nftType) {
                temp[count] = tokenId;
                count++;
            }
        }
        
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = temp[i];
        }
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    function _generateCaptainInfo(uint256 tokenId, CaptainAbility ability, Rarity rarity) internal view returns (CaptainInfo memory info) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, tokenId)));
        
        info.name = _generateCaptainName(seed);
        info.ability = ability;
        info.abilityPower = uint8((seed % 5) + uint8(rarity) + 1); // 1-10 based on rarity
        info.experience = (seed % 1000) * (uint8(rarity) + 1);
        info.leadership = uint8((seed % 50) + 50 + uint8(rarity) * 5); // 50-100+
        info.tactics = uint8(((seed >> 8) % 50) + 50 + uint8(rarity) * 5);
        info.morale = uint8(((seed >> 16) % 50) + 50 + uint8(rarity) * 5);
        info.portrait = _generateCaptainPortrait(seed);
        info.variantId = 1; // Default variant
        
        return info;
    }

    function _generateCrewInfo(uint256 tokenId, CrewType crewType, Rarity rarity) internal view returns (CrewInfo memory info) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, tokenId)));
        
        info.name = _generateCrewName(seed);
        info.crewType = crewType;
        info.skillLevel = uint8((seed % 5) + uint8(rarity) + 1); // 1-10 based on rarity
        info.maxStamina = uint8(80 + uint8(rarity) * 5); // 80-100 based on rarity
        info.stamina = info.maxStamina;
        info.experience = (seed % 500) * (uint8(rarity) + 1);
        info.efficiency = uint8((seed % 40) + 60 + uint8(rarity) * 5); // 60-100+
        info.loyalty = uint8(((seed >> 8) % 40) + 60 + uint8(rarity) * 5);
        info.lastUsed = block.timestamp;
        info.variantId = 1; // Default variant
        
        return info;
    }

    function _generateCaptainName(uint256 seed) internal view returns (string memory) {
        string memory firstName = captainFirstNames[seed % captainFirstNames.length];
        string memory lastName = captainLastNames[(seed >> 8) % captainLastNames.length];
        return string(abi.encodePacked(firstName, " ", lastName));
    }

    function _generateCrewName(uint256 seed) internal view returns (string memory) {
        string memory firstName = crewFirstNames[seed % crewFirstNames.length];
        string memory lastName = crewLastNames[(seed >> 8) % crewLastNames.length];
        return string(abi.encodePacked(firstName, " ", lastName));
    }

    function _generateCaptainPortrait(uint256 seed) internal pure returns (CaptainPortrait memory portrait) {
        portrait.faceType = uint8((seed % 10) + 1);
        portrait.eyeType = uint8(((seed >> 8) % 8) + 1);
        portrait.hairType = uint8(((seed >> 16) % 12) + 1);
        portrait.uniformType = uint8(((seed >> 24) % 6) + 1);
        portrait.accessoryType = uint8(((seed >> 32) % 15) + 1);
        portrait.skinTone = "#d4a574"; // Placeholder
        portrait.eyeColor = "#2e5984"; // Placeholder
        portrait.hairColor = "#8b4513"; // Placeholder
    }

    function _generateCaptainPortrait(CaptainPortrait memory portrait, string memory rarityColor) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(150, 170)">',
            '<circle cx="0" cy="0" r="60" fill="', portrait.skinTone, '" stroke="', rarityColor, '" stroke-width="2"/>',
            '<circle cx="-15" cy="-10" r="8" fill="', portrait.eyeColor, '"/>',
            '<circle cx="15" cy="-10" r="8" fill="', portrait.eyeColor, '"/>',
            '<rect x="-30" y="-40" width="60" height="20" fill="', portrait.hairColor, '"/>',
            '<text x="0" y="45" text-anchor="middle" fill="white" font-size="14">⭐</text>',
            '</g>'
        ));
    }

    function _generateCrewAvatar(CrewType crewType, Rarity rarity, string memory rarityColor) internal pure returns (string memory) {
        string memory specialtyIcon = "⚙️";
        if (crewType == CrewType.GUNNER) specialtyIcon = "🎯";
        else if (crewType == CrewType.ENGINEER) specialtyIcon = "🔧";
        else if (crewType == CrewType.NAVIGATOR) specialtyIcon = "🧭";
        else if (crewType == CrewType.MEDIC) specialtyIcon = "⚕️";
        
        return string(abi.encodePacked(
            '<g transform="translate(150, 170)">',
            '<circle cx="0" cy="0" r="50" fill="#4a5d6a" stroke="', rarityColor, '" stroke-width="2"/>',
            '<text x="0" y="10" text-anchor="middle" fill="white" font-size="24">', specialtyIcon, '</text>',
            '</g>'
        ));
    }

    function _generateStaminaBar(uint8 currentStamina, uint8 maxStamina) internal pure returns (string memory) {
        uint256 barWidth = (uint256(currentStamina) * 260) / uint256(maxStamina);
        
        return string(abi.encodePacked(
            '<rect x="20" y="380" width="260" height="10" fill="#333" stroke="#666"/>',
            '<rect x="20" y="380" width="', _toString(barWidth), '" height="10" fill="#00ff00"/>',
            '<text x="150" y="375" text-anchor="middle" fill="white" font-size="10">Stamina</text>'
        ));
    }

    function _initializeNames() internal {
        // Initialize name arrays for generation
        captainFirstNames = ["Admiral", "Captain", "Commander", "Commodore", "Fleet"];
        captainLastNames = ["Blackwater", "Stormwind", "Ironclad", "Seasalt", "Deepwater"];
        crewFirstNames = ["Jack", "Pete", "Sam", "Tom", "Bill"];
        crewLastNames = ["Sailor", "Seaman", "Bosun", "Mate", "Rigger"];
    }

    function _initializeSVGThemes() internal {
        svgThemeColors[1] = "4a5d3a,708238,8fbc8f"; // Military greens
        svgThemeNames[1] = "Military";
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

    function _getAbilityName(CaptainAbility ability) internal pure returns (string memory) {
        if (ability == CaptainAbility.DAMAGE_BOOST) return "Damage Boost";
        if (ability == CaptainAbility.SPEED_BOOST) return "Speed Boost";
        if (ability == CaptainAbility.DEFENSE_BOOST) return "Defense Boost";
        if (ability == CaptainAbility.VISION_BOOST) return "Vision Boost";
        return "Luck Boost";
    }

    function _getCrewTypeName(CrewType crewType) internal pure returns (string memory) {
        if (crewType == CrewType.GUNNER) return "Gunner";
        if (crewType == CrewType.ENGINEER) return "Engineer";
        if (crewType == CrewType.NAVIGATOR) return "Navigator";
        return "Medic";
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
        require(_ownerOf(tokenId) != address(0), "CaptainAndCrewNFTManager: URI query for nonexistent token");
        
        string memory placardSVG;
        string memory name;
        
        if (tokenTypes[tokenId] == NFTType.CAPTAIN) {
            placardSVG = this.generateCaptainPlacardSVG(tokenId);
            name = captainInfo[tokenId].name;
        } else {
            placardSVG = this.generateCrewPlacardSVG(tokenId);
            name = crewInfo[tokenId].name;
        }
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(string(abi.encodePacked(
                '{"name":"', name, 
                '","description":"A skilled crew member ready for battle",',
                '"image":"data:image/svg+xml;base64,', _base64Encode(bytes(placardSVG)), '"}'
            ))))
        ));
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        // Simplified base64 encoding - in production use a proper library
        return "placeholder_base64";
    }
}