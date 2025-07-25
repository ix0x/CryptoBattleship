// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ActionNFTManager
 * @dev Manages Action NFTs with placard and animation SVGs
 * @notice Handles offensive and defensive action cards with template system
 */
contract ActionNFTManager is ERC721, ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {
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
     * @dev Action NFT categories
     */
    enum ActionCategory {
        OFFENSIVE,  // 0: Attack-based actions
        DEFENSIVE   // 1: Defense-based actions
    }

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
        uint8 svgThemeId;        // SVG theme for artwork
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

    /**
     * @dev Template creation helper struct
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

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    // Token tracking
    uint256 private _nextTokenId = 1;
    mapping(uint256 => Rarity) public tokenRarities;
    mapping(uint256 => uint256) public tokenUsesRemaining;

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

    // SVG system
    uint8 public svgVersion = 1;
    mapping(uint8 => string) private svgThemeColors;
    mapping(uint8 => string) private svgThemeNames;

    // Authorized minters
    mapping(address => bool) public authorizedMinters;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event ActionMinted(uint256 indexed tokenId, address indexed owner, ActionCategory category, Rarity rarity, uint8 templateId);
    event ActionUsed(uint256 indexed tokenId, address indexed user, uint256 usesRemaining);
    event ActionDepleted(uint256 indexed tokenId, address indexed owner);
    event ActionTemplateAdded(uint8 indexed templateId, string name, ActionCategory category, Rarity minRarity);
    event ActionVariantCreated(uint256 indexed variantId, string name, uint256 seasonId);
    event ActionVariantActivated(uint256 indexed variantId);
    event ActionVariantRetired(uint256 indexed variantId);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);
    event SVGVersionUpdated(uint8 newVersion);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _initialAdmin) ERC721("CryptoBattleship Actions", "CBACTION") Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "ActionNFTManager: Initial admin cannot be zero address");
        _initializeDefaultTemplates();
        _initializeSVGThemes();
    }

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "ActionNFTManager: Not authorized to mint");
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
        require(minter != address(0), "ActionNFTManager: Invalid minter address");
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
     * @dev Mint action NFT based on template system
     * @param recipient Address to receive the action
     * @param category Offensive or defensive action
     * @param rarity Rarity level of the action
     * @return tokenId Minted token ID
     */
    function mintAction(address recipient, ActionCategory category, Rarity rarity) 
        external 
        onlyAuthorizedMinter
        whenNotPaused
        returns (uint256 tokenId) 
    {
        require(recipient != address(0), "ActionNFTManager: Cannot mint to zero address");

        // Get available templates for current variant
        uint8[] memory availableTemplates = variantTemplatesByRarity[activeActionVariant][category][rarity];
        require(availableTemplates.length > 0, "ActionNFTManager: No templates available for this rarity/category");

        // Select template pseudo-randomly
        uint8 templateId = availableTemplates[uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            block.prevrandao, 
            recipient, 
            _nextTokenId
        ))) % availableTemplates.length];
        
        ActionTemplate memory template = actionTemplates[templateId];
        require(template.isActive, "ActionNFTManager: Template not active");
        require(uint8(rarity) >= uint8(template.minRarity), "ActionNFTManager: Rarity too low for template");
        
        // Mint the NFT
        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        
        // Set token properties
        tokenRarities[tokenId] = rarity;
        tokenUsesRemaining[tokenId] = template.uses;
        actionTemplateIds[tokenId] = templateId;
        actionVariantIds[tokenId] = activeActionVariant;
        actionMaxUses[tokenId] = template.uses;
        actionCategories[tokenId] = category;
        
        // Copy template pattern
        actionPatterns[tokenId] = ActionPattern({
            targetCells: template.targetCells,
            damage: template.damage,
            range: template.range,
            category: template.category
        });
        
        emit ActionMinted(tokenId, recipient, category, rarity, templateId);
        return tokenId;
    }

    // =============================================================================
    // SVG GENERATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Generate placard SVG for action NFT (trading card view)
     * @param tokenId Token ID to generate placard for
     * @return svg Complete placard SVG string
     */
    function generatePlacardSVG(uint256 tokenId) external view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "ActionNFTManager: Token does not exist");
        
        ActionCategory category = actionCategories[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ActionTemplate memory template = actionTemplates[actionTemplateIds[tokenId]];
        
        return _buildPlacardSVG(tokenId, template, category, rarity);
    }

    /**
     * @dev Generate animation SVG for action NFT (in-game animation)
     * @param tokenId Token ID to generate animation for
     * @return svg Complete animation SVG string
     */
    function generateAnimationSVG(uint256 tokenId) external view returns (string memory svg) {
        require(_ownerOf(tokenId) != address(0), "ActionNFTManager: Token does not exist");
        
        ActionCategory category = actionCategories[tokenId];
        Rarity rarity = tokenRarities[tokenId];
        ActionPattern memory pattern = actionPatterns[tokenId];
        
        return _buildAnimationSVG(tokenId, pattern, category, rarity);
    }

    /**
     * @dev Build placard SVG with stats and flavor
     */
    function _buildPlacardSVG(
        uint256 tokenId,
        ActionTemplate memory template,
        ActionCategory category,
        Rarity rarity
    ) internal view returns (string memory) {
        string memory rarityColor = _getRarityColor(rarity);
        string memory categoryColor = category == ActionCategory.OFFENSIVE ? "#ff4444" : "#4444ff";
        
        return string(abi.encodePacked(
            '<svg width="300" height="420" xmlns="http://www.w3.org/2000/svg">',
            '<defs><style>.text{font-family:Arial,sans-serif;font-weight:bold;}</style></defs>',
            '<rect width="300" height="420" fill="#1a1a2e" stroke="', rarityColor, '" stroke-width="3"/>',
            '<rect x="10" y="10" width="280" height="60" fill="', categoryColor, '" opacity="0.8"/>',
            '<text x="150" y="35" text-anchor="middle" fill="white" class="text" font-size="16">', template.name, '</text>',
            '<text x="150" y="55" text-anchor="middle" fill="white" class="text" font-size="12">', _getRarityName(rarity), ' ', _getCategoryName(category), '</text>',
            
            // Stats section
            '<rect x="10" y="320" width="280" height="90" fill="#333" stroke="', rarityColor, '"/>',
            '<text x="20" y="340" fill="white" class="text" font-size="12">Damage: ', _toString(template.damage), '</text>',
            '<text x="20" y="355" fill="white" class="text" font-size="12">Range: ', _toString(template.range), '</text>',
            '<text x="20" y="370" fill="white" class="text" font-size="12">Uses: ', _toString(tokenUsesRemaining[tokenId]), '/', _toString(template.uses), '</text>',
            '<text x="20" y="385" fill="white" class="text" font-size="12">Pattern: ', _toString(template.targetCells.length), ' cells</text>',
            
            // Action pattern visualization
            _generatePatternVisualization(template.targetCells, categoryColor),
            '</svg>'
        ));
    }

    /**
     * @dev Build animation SVG for in-game use
     */
    function _buildAnimationSVG(
        uint256 tokenId,
        ActionPattern memory pattern,
        ActionCategory category,
        Rarity rarity
    ) internal view returns (string memory) {
        string memory effectColor = category == ActionCategory.OFFENSIVE ? "#ff6b35" : "#4ecdc4";
        
        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs>',
            _generateAnimationDefs(category, rarity),
            '</defs>',
            '<rect width="400" height="400" fill="transparent"/>',
            _generateActionEffect(pattern, effectColor, rarity),
            '</svg>'
        ));
    }

    // =============================================================================
    // ACTION USAGE FUNCTIONS
    // =============================================================================

    /**
     * @dev Use an action NFT (decrements uses)
     * @param tokenId Token ID to use
     * @param user Address using the action
     */
    function useAction(uint256 tokenId, address user) external {
        require(_ownerOf(tokenId) != address(0), "ActionNFTManager: Action does not exist");
        require(ownerOf(tokenId) == user, "ActionNFTManager: Not owner of action");
        require(tokenUsesRemaining[tokenId] > 0, "ActionNFTManager: No uses remaining");
        
        tokenUsesRemaining[tokenId]--;
        
        emit ActionUsed(tokenId, user, tokenUsesRemaining[tokenId]);
        
        if (tokenUsesRemaining[tokenId] == 0) {
            emit ActionDepleted(tokenId, user);
        }
    }

    /**
     * @dev Get action information
     * @param tokenId Token ID to query
     * @return pattern Action pattern data
     * @return category Action category
     * @return usesRemaining Remaining uses
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
        require(_ownerOf(tokenId) != address(0), "ActionNFTManager: Action does not exist");
        
        return (
            actionPatterns[tokenId],
            actionCategories[tokenId],
            tokenUsesRemaining[tokenId]
        );
    }

    // =============================================================================
    // TEMPLATE MANAGEMENT
    // =============================================================================

    /**
     * @dev Add new action template
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
        require(targetCells.length > 0 && targetCells.length <= 25, "ActionNFTManager: Invalid target cells count");
        require(damage <= 10, "ActionNFTManager: Damage too high");
        require(range <= 15, "ActionNFTManager: Range too high");
        require(uses > 0 && uses <= 10, "ActionNFTManager: Invalid uses count");
        
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
     * @dev Assign templates to variant and rarity combination
     */
    function assignTemplatesToVariantRarity(
        uint256 variantId,
        ActionCategory category,
        Rarity rarity,
        uint8[] calldata templateIds
    ) external onlyOwner {
        for (uint256 i = 0; i < templateIds.length; i++) {
            ActionTemplate memory template = actionTemplates[templateIds[i]];
            require(template.targetCells.length > 0, "ActionNFTManager: Template does not exist");
            require(template.category == category, "ActionNFTManager: Template category mismatch");
            require(uint8(rarity) >= uint8(template.minRarity), "ActionNFTManager: Rarity too low for template");
        }
        
        variantTemplatesByRarity[variantId][category][rarity] = templateIds;
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    function _initializeDefaultTemplates() internal {
        // Add some default templates for testing
        uint8[] memory singleCell = new uint8[](1);
        singleCell[0] = 0;
        
        // Offensive template
        actionTemplates[1] = ActionTemplate({
            name: "Basic Shot",
            description: "Simple single-cell attack",
            targetCells: singleCell,
            damage: 1,
            range: 5,
            uses: 3,
            category: ActionCategory.OFFENSIVE,
            minRarity: Rarity.COMMON,
            isActive: true,
            isSeasonalOnly: false,
            seasonId: 0
        });
        
        // Assign to classic variant
        uint8[] memory template1 = new uint8[](1);
        template1[0] = 1;
        variantTemplatesByRarity[0][ActionCategory.OFFENSIVE][Rarity.COMMON] = template1;
        
        nextTemplateId = 2;
    }

    function _initializeSVGThemes() internal {
        svgThemeColors[1] = "4a5d3a,708238,8fbc8f"; // Military greens
        svgThemeNames[1] = "Military";
        
        svgThemeColors[2] = "8b4513,daa520,cd853f"; // Pirate browns/gold
        svgThemeNames[2] = "Pirate";
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

    function _getCategoryName(ActionCategory category) internal pure returns (string memory) {
        return category == ActionCategory.OFFENSIVE ? "Offensive" : "Defensive";
    }

    function _generatePatternVisualization(uint8[] memory targetCells, string memory color) internal pure returns (string memory) {
        // Simple grid visualization of the attack pattern
        return string(abi.encodePacked(
            '<g transform="translate(150, 100)">',
            '<rect x="-50" y="-50" width="100" height="100" fill="#222" stroke="#555"/>',
            '<circle cx="0" cy="0" r="3" fill="', color, '"/>',
            '</g>'
        ));
    }

    function _generateAnimationDefs(ActionCategory category, Rarity rarity) internal pure returns (string memory) {
        if (category == ActionCategory.OFFENSIVE) {
            return '<radialGradient id="explosion"><stop offset="0%" stop-color="#ff6b35"/><stop offset="100%" stop-color="#ff0000"/></radialGradient>';
        } else {
            return '<radialGradient id="shield"><stop offset="0%" stop-color="#4ecdc4"/><stop offset="100%" stop-color="#0080ff"/></radialGradient>';
        }
    }

    function _generateActionEffect(ActionPattern memory pattern, string memory color, Rarity rarity) internal pure returns (string memory) {
        // Generate visual effect based on pattern
        return string(abi.encodePacked(
            '<circle cx="200" cy="200" r="50" fill="', color, '" opacity="0.7">',
            '<animate attributeName="r" values="10;50;10" dur="1s" repeatCount="indefinite"/>',
            '</circle>'
        ));
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

    // Required overrides for ERC721 + ERC721Enumerable in OpenZeppelin v5
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ActionNFTManager: URI query for nonexistent token");
        
        ActionTemplate memory template = actionTemplates[actionTemplateIds[tokenId]];
        string memory placardSVG = this.generatePlacardSVG(tokenId);
        
        // Return base64 encoded JSON metadata with embedded SVG
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(string(abi.encodePacked(
                '{"name":"', template.name, 
                '","description":"', template.description,
                '","image":"data:image/svg+xml;base64,', _base64Encode(bytes(placardSVG)), '"}'
            ))))
        ));
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        // Simplified base64 encoding - in production use a proper library
        return "placeholder_base64";
    }
}