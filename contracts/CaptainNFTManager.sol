// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CaptainNFTManager
 * @dev Manages Captain NFTs with simple placards
 * @notice Handles fleet leadership NFTs
 */
contract CaptainNFTManager is ERC721, ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // =============================================================================
    // ENUMS AND STRUCTS
    // =============================================================================

    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
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

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    uint256 private _nextTokenId = 1;
    mapping(uint256 => Rarity) public tokenRarities;
    mapping(uint256 => CaptainInfo) public captainInfo;
    mapping(address => bool) public authorizedMinters;

    // =============================================================================
    // EVENTS
    // =============================================================================

    event CaptainMinted(uint256 indexed tokenId, address indexed owner, Rarity rarity);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _initialAdmin) ERC721("CryptoBattleship Captains", "CBCAP") Ownable(_initialAdmin) {
        require(_initialAdmin != address(0), "CaptainNFTManager: Initial admin cannot be zero address");
    }

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "CaptainNFTManager: Not authorized to mint");
        _;
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "CaptainNFTManager: Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterUpdated(minter, authorized);
    }

    // =============================================================================
    // MINTING FUNCTIONS
    // =============================================================================

    function mintCaptain(address recipient, CaptainAbility ability, Rarity rarity) 
        external 
        onlyAuthorizedMinter
        whenNotPaused
        returns (uint256 tokenId) 
    {
        require(recipient != address(0), "CaptainNFTManager: Cannot mint to zero address");
        
        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        
        tokenRarities[tokenId] = rarity;
        captainInfo[tokenId] = _generateCaptainInfo(tokenId, ability, rarity);
        
        emit CaptainMinted(tokenId, recipient, rarity);
        return tokenId;
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getCaptainInfo(uint256 tokenId) external view returns (CaptainInfo memory info) {
        require(_ownerOf(tokenId) != address(0), "CaptainNFTManager: Captain does not exist");
        return captainInfo[tokenId];
    }

    function getOwnedCaptains(address owner) external view returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    function _generateCaptainInfo(uint256 tokenId, CaptainAbility ability, Rarity rarity) internal view returns (CaptainInfo memory info) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, tokenId)));
        
        info.name = "Captain";
        info.ability = ability;
        info.abilityPower = uint8((seed % 5) + uint8(rarity) + 1);
        info.experience = (seed % 1000) * (uint8(rarity) + 1);
        info.leadership = uint8((seed % 50) + 50 + uint8(rarity) * 5);
        info.tactics = uint8(((seed >> 8) % 50) + 50 + uint8(rarity) * 5);
        info.morale = uint8(((seed >> 16) % 50) + 50 + uint8(rarity) * 5);
        
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
        require(_ownerOf(tokenId) != address(0), "CaptainNFTManager: URI query for nonexistent token");
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(string(abi.encodePacked(
                '{"name":"Captain",',
                '"description":"A skilled captain ready to lead your fleet",',
                '"image":"data:image/svg+xml;base64,', _base64Encode(bytes('<svg width="300" height="420" xmlns="http://www.w3.org/2000/svg"><rect width="300" height="420" fill="#000"/><text x="150" y="210" text-anchor="middle" fill="white">Captain NFT</text></svg>')), '"}'
            ))))
        ));
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        return "placeholder_base64";
    }
}