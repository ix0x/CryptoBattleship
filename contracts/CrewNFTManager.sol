// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CrewNFTManager
 * @dev Manages Crew NFTs with simple placards
 * @notice Handles individual ship crew member NFTs
 */
contract CrewNFTManager is ERC721, ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // =============================================================================
    // ENUMS AND STRUCTS
    // =============================================================================

    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
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

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    uint256 private _nextTokenId = 1;
    mapping(uint256 => Rarity) public tokenRarities;
    mapping(uint256 => CrewInfo) public crewInfo;
    mapping(address => bool) public authorizedMinters;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event CrewMinted(uint256 indexed tokenId, address indexed owner, CrewType crewType, Rarity rarity);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _initialAdmin) ERC721("CryptoBattleship Crew", "CBCREW") Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "CrewNFTManager: Initial admin cannot be zero address");
    }

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "CrewNFTManager: Not authorized to mint");
        _;
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "CrewNFTManager: Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterUpdated(minter, authorized);
    }

    // =============================================================================
    // MINTING FUNCTIONS
    // =============================================================================

    function mintCrew(address recipient, CrewType crewType, Rarity rarity) 
        external 
        onlyAuthorizedMinter
        whenNotPaused
        returns (uint256 tokenId) 
    {
        require(recipient != address(0), "CrewNFTManager: Cannot mint to zero address");
        
        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        
        tokenRarities[tokenId] = rarity;
        crewInfo[tokenId] = _generateCrewInfo(tokenId, crewType, rarity);
        
        emit CrewMinted(tokenId, recipient, crewType, rarity);
        return tokenId;
    }

    // =============================================================================
    // CREW MANAGEMENT FUNCTIONS
    // =============================================================================

    function canUseCrew(uint256 tokenId) external view returns (bool canUse, uint8 currentStamina) {
        if (_ownerOf(tokenId) == address(0)) return (false, 0);
        
        CrewInfo memory info = crewInfo[tokenId];
        return (info.stamina > 0, info.stamina);
    }

    function useCrewStamina(uint256 tokenId, address user) external {
        require(_ownerOf(tokenId) != address(0), "CrewNFTManager: Crew does not exist");
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(), 
            "CrewNFTManager: Not authorized"
        );
        
        CrewInfo storage info = crewInfo[tokenId];
        if (info.stamina > 0) {
            info.stamina -= 1;
            info.lastUsed = block.timestamp;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getCrewInfo(uint256 tokenId) external view returns (CrewInfo memory info) {
        require(_ownerOf(tokenId) != address(0), "CrewNFTManager: Crew does not exist");
        return crewInfo[tokenId];
    }

    function getOwnedCrew(address owner) external view returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    function _generateCrewInfo(uint256 tokenId, CrewType crewType, Rarity rarity) internal view returns (CrewInfo memory info) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, tokenId)));
        
        info.name = "Crew";
        info.crewType = crewType;
        info.skillLevel = uint8((seed % 5) + uint8(rarity) + 1);
        info.maxStamina = uint8(80 + uint8(rarity) * 4);
        info.stamina = info.maxStamina;
        info.experience = (seed % 500) * (uint8(rarity) + 1);
        info.efficiency = uint8((seed % 40) + 60 + uint8(rarity) * 8);
        info.loyalty = uint8(((seed >> 8) % 40) + 50 + uint8(rarity) * 5);
        info.lastUsed = 0;
        info.variantId = 1;
        
        return info;
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
        require(_ownerOf(tokenId) != address(0), "CrewNFTManager: URI query for nonexistent token");
        
        CrewInfo memory info = crewInfo[tokenId];
        string memory crewTypeName = _getCrewTypeName(info.crewType);
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(string(abi.encodePacked(
                '{"name":"', crewTypeName, '",',
                '"description":"A skilled crew member ready to serve your fleet",',
                '"image":"data:image/svg+xml;base64,', _base64Encode(bytes('<svg width="300" height="420" xmlns="http://www.w3.org/2000/svg"><rect width="300" height="420" fill="#000"/><text x="150" y="210" text-anchor="middle" fill="white">Crew NFT</text></svg>')), '"}'
            ))))
        ));
    }

    function _getCrewTypeName(CrewType crewType) internal pure returns (string memory) {
        if (crewType == CrewType.GUNNER) return "Gunner";
        if (crewType == CrewType.ENGINEER) return "Engineer";
        if (crewType == CrewType.NAVIGATOR) return "Navigator";
        return "Medic";
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        return "placeholder_base64";
    }
}