// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BattleshipToken (SHIP)
 * @dev ERC20 token for CryptoBattleship game ecosystem
 * @notice The S Token with 10 million total supply, minting capability for emissions,
 *         and pausable functionality for emergencies
 */
contract BattleshipToken is ERC20, ERC20Pausable, Ownable, ReentrancyGuard {
    
    // =============================================================================
    // CONSTANTS AND STATE VARIABLES
    // =============================================================================
    
    // Total supply: 10 million tokens (18 decimals)
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 10**18;
    
    // Authorized minter (TokenomicsCore contract)
    address public minter;
    
    // Total minted through emissions (excluding initial supply)
    uint256 public totalMinted;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event MinterSet(address indexed oldMinter, address indexed newMinter);
    event TokensMinted(address indexed to, uint256 amount, uint256 totalMinted);
    event EmergencyPauseActivated(address indexed admin, string reason);
    event EmergencyPauseDeactivated(address indexed admin);
    
    // =============================================================================
    // SECTION 2.1: BASIC ERC20 IMPLEMENTATION
    // =============================================================================

    /**
     * @dev Function1: Contract initialization with 10M total supply
     * @param _initialAdmin Address to be granted admin privileges
     * @param _initialSupplyRecipient Address to receive the initial token supply
     */
    constructor(address _initialAdmin, address _initialSupplyRecipient) 
        ERC20("SHIP", "SHIP") 
    {
        require(_initialAdmin != address(0), "BattleshipToken: Initial admin cannot be zero address");
        require(_initialSupplyRecipient != address(0), "BattleshipToken: Initial supply recipient cannot be zero address");
        
        // Set contract deployer as owner (OpenZeppelin Ownable)
        _transferOwnership(_initialAdmin);
        
        // Mint initial supply to designated recipient
        _mint(_initialSupplyRecipient, TOTAL_SUPPLY);
    }

    /**
     * @dev Function2: Standard transfer and approve functions
     * @notice Inherits from ERC20, but adds pause checking
     */
    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
        return super.approve(spender, amount);
    }

    /**
     * @dev Function3: Pausable functionality for emergencies
     * @param _reason Reason for the emergency pause
     * @notice Only owner can pause the contract
     */
    function emergencyPause(string calldata _reason) external onlyOwner {
        require(bytes(_reason).length > 0, "BattleshipToken: Pause reason cannot be empty");
        
        _pause();
        emit EmergencyPauseActivated(msg.sender, _reason);
    }

    /**
     * @dev Unpause the contract after emergency
     * @notice Only owner can unpause the contract
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();
        emit EmergencyPauseDeactivated(msg.sender);
    }

    /**
     * @dev Get current pause status
     * @return bool True if contract is paused
     */
    function isPaused() external view returns (bool) {
        return paused();
    }

    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Get token information for frontend
     * @return tokenName Name of the token
     * @return tokenSymbol Symbol of the token
     * @return tokenDecimals Number of decimals
     * @return tokenTotalSupply Current total supply
     */
    function getTokenInfo() external view returns (
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 tokenTotalSupply
    ) {
        return (name(), symbol(), decimals(), totalSupply());
    }

    // =============================================================================
    // SECTION 2.2: MINTING CONTROLS
    // =============================================================================

    /**
     * @dev Modifier to restrict minting to authorized minter only
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "BattleshipToken: Caller is not the authorized minter");
        _;
    }

    /**
     * @dev Function1: Minting function restricted to TokenomicsCore
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @notice Only the authorized minter (TokenomicsCore) can mint new tokens
     */
    function mint(address to, uint256 amount) external onlyMinter whenNotPaused nonReentrant {
        require(to != address(0), "BattleshipToken: Cannot mint to zero address");
        require(amount > 0, "BattleshipToken: Amount must be greater than zero");
        
        // Update total minted tracking
        totalMinted += amount;
        
        // Mint tokens
        _mint(to, amount);
        
        emit TokensMinted(to, amount, totalMinted);
    }

    /**
     * @dev Function2: Minter role management
     * @param _newMinter Address of the new authorized minter
     * @notice Only owner can set the minter address
     */
    function setMinter(address _newMinter) external onlyOwner {
        require(_newMinter != address(0), "BattleshipToken: Minter cannot be zero address");
        
        address oldMinter = minter;
        minter = _newMinter;
        
        emit MinterSet(oldMinter, _newMinter);
    }

    /**
     * @dev Remove minter privileges (emergency function)
     * @notice Only owner can remove minter privileges
     */
    function removeMinter() external onlyOwner {
        address oldMinter = minter;
        minter = address(0);
        
        emit MinterSet(oldMinter, address(0));
    }

    /**
     * @dev Function3: Minting event emissions
     * @notice Events are already emitted in mint() function
     * This function provides minting statistics for frontend
     */
    function getMintingStats() external view returns (
        address currentMinter,
        uint256 totalTokensMinted,
        uint256 initialSupply,
        uint256 currentTotalSupply
    ) {
        return (
            minter,
            totalMinted,
            TOTAL_SUPPLY,
            totalSupply()
        );
    }

    /**
     * @dev Check if an address is the authorized minter
     * @param _address Address to check
     * @return bool True if address is the authorized minter
     */
    function isMinter(address _address) external view returns (bool) {
        return _address == minter && _address != address(0);
    }

    /**
     * @dev Get remaining mintable supply
     * @notice Returns the difference between max supply and current supply
     * Note: This contract doesn't enforce a max supply beyond initial allocation,
     * but provides this view for frontend/monitoring purposes
     */
    function getRemainingMintableSupply() external view returns (uint256) {
        // Since there's no hard cap beyond initial supply, this returns
        // a theoretical "unlimited" value represented as max uint256
        // The actual limit will be enforced by TokenomicsCore emission schedules
        return type(uint256).max - totalSupply();
    }

    // =============================================================================
    // SECTION 2.3: INTEGRATION INTERFACES
    // =============================================================================

    /**
     * @dev Function1: Interface for TokenomicsCore integration
     * @notice Provides all necessary functions for TokenomicsCore to manage emissions
     */
    
    /**
     * @dev Batch mint tokens to multiple recipients
     * @param recipients Array of addresses to mint tokens to
     * @param amounts Array of amounts to mint to each recipient
     * @notice Only authorized minter can batch mint, arrays must be same length
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) 
        external 
        onlyMinter 
        whenNotPaused 
        nonReentrant 
    {
        require(recipients.length == amounts.length, "BattleshipToken: Arrays length mismatch");
        require(recipients.length <= 100, "BattleshipToken: Too many recipients in batch");
        
        uint256 totalBatchAmount = 0;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "BattleshipToken: Cannot mint to zero address");
            require(amounts[i] > 0, "BattleshipToken: Amount must be greater than zero");
            
            totalBatchAmount += amounts[i];
            _mint(recipients[i], amounts[i]);
        }
        
        // Update total minted tracking
        totalMinted += totalBatchAmount;
        
        emit TokensMinted(address(0), totalBatchAmount, totalMinted); // address(0) indicates batch mint
    }

    /**
     * @dev Function2: Interface for StakingPool integration
     * @notice Provides additional functionality for staking pool operations
     */
    
    /**
     * @dev Check allowance for staking pool operations
     * @param owner Token owner address
     * @param spender Spender address (typically staking pool)
     * @return uint256 Current allowance amount
     */
    function checkAllowanceForStaking(address owner, address spender) external view returns (uint256) {
        return allowance(owner, spender);
    }

    /**
     * @dev Get balance information for staking calculations
     * @param account Account to check balance for
     * @return balance Current token balance
     * @return canTransfer Whether transfers are currently allowed (not paused)
     */
    function getBalanceInfo(address account) external view returns (uint256 balance, bool canTransfer) {
        return (balanceOf(account), !paused());
    }

    /**
     * @dev Emergency function to recover stuck tokens
     * @param tokenAddress Address of token to recover (use address(0) for ETH)
     * @param to Address to send recovered tokens
     * @param amount Amount to recover
     * @notice Only owner can recover tokens, cannot recover SHIP tokens
     */
    function emergencyTokenRecovery(
        address tokenAddress, 
        address to, 
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(to != address(0), "BattleshipToken: Cannot recover to zero address");
        require(tokenAddress != address(this), "BattleshipToken: Cannot recover SHIP tokens");
        
        if (tokenAddress == address(0)) {
            // Recover ETH
            require(amount <= address(this).balance, "BattleshipToken: Insufficient ETH balance");
            payable(to).transfer(amount);
        } else {
            // Recover ERC20 tokens
            IERC20 token = IERC20(tokenAddress);
            require(amount <= token.balanceOf(address(this)), "BattleshipToken: Insufficient token balance");
            token.transfer(to, amount);
        }
    }

    /**
     * @dev Get comprehensive contract state for frontend integration
     * @return contractInfo Struct containing all key contract information
     */
    function getContractState() external view returns (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        uint256 totalMinted,
        address minter,
        bool isPaused,
        address owner
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            totalMinted,
            minter,
            paused(),
            owner()
        );
    }

    /**
     * @dev Support for receiving ETH (for emergency recovery purposes)
     */
    receive() external payable {
        // Allow contract to receive ETH for emergency recovery purposes
        // No special logic needed
    }

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        revert("BattleshipToken: Function not found");
    }
} 