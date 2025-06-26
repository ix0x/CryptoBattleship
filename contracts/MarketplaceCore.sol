// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Interface imports
interface IBattleshipToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface INFTManager {
    enum TokenType { SHIP, ACTION, CAPTAIN, CREW }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
    
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getTokenType(uint256 tokenId) external view returns (TokenType);
    function getTokenRarity(uint256 tokenId) external view returns (Rarity);
}

interface ITokenomicsCore {
    function recordMarketplaceRevenue(uint256 amount) external;
}

/**
 * @title MarketplaceCore
 * @dev NFT marketplace with fixed price listings and auction system
 * 
 * MARKETPLACE FEATURES:
 * - Fixed price listings for immediate purchase
 * - Auction system with bidding and auto-settlement
 * - Support for all NFT types (Ships, Actions, Captains, Crew)
 * - Multi-token payments (SHIP, ETH, stablecoins)
 * - Marketplace fees with revenue sharing
 * 
 * FEE STRUCTURE:
 * - 2.5% marketplace fee on all sales
 * - Revenue flows to TokenomicsCore for distribution
 * - Optional creator royalties for future expansion
 */
contract MarketplaceCore is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // =============================================================================
    // CONSTANTS AND IMMUTABLES
    // =============================================================================
    
    uint256 public constant MARKETPLACE_FEE_PERCENTAGE = 250;    // 2.5% (out of 10000)
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;     // Minimum auction time
    uint256 public constant MAX_AUCTION_DURATION = 30 days;     // Maximum auction time
    uint256 public constant MIN_BID_INCREMENT = 500;            // 5% minimum bid increment
    uint256 public constant AUCTION_EXTENSION_TIME = 10 minutes; // Extend if bid in last 10 min
    
    // =============================================================================
    // ENUMS AND STRUCTS
    // =============================================================================
    
    enum ListingType { FIXED_PRICE, AUCTION }
    enum ListingStatus { ACTIVE, SOLD, CANCELLED, EXPIRED }
    
    struct Listing {
        uint256 tokenId;                    // NFT token ID
        address seller;                     // Seller address
        address paymentToken;               // Payment token (address(0) for ETH)
        uint256 price;                      // Fixed price or starting bid
        ListingType listingType;            // Fixed price or auction
        ListingStatus status;               // Current status
        uint256 createdAt;                  // Listing creation time
        uint256 expiresAt;                  // Listing expiration time
        uint256 highestBid;                 // Current highest bid (auctions only)
        address highestBidder;              // Current highest bidder
        uint256 bidCount;                   // Number of bids placed
    }
    
    struct BidHistory {
        address bidder;                     // Bidder address
        uint256 amount;                     // Bid amount
        uint256 timestamp;                  // Bid timestamp
    }
    
    // =============================================================================
    // RENTAL SYSTEM EXTENSION
    // =============================================================================

    // Rental data structures
    struct ActiveRental {
        uint256 shipId;
        address renter;
        address owner;              // For P2P rentals (address(0) for protocol)
        uint256 gamesRemaining;
        uint256 maxHours;           // Time limit set by renter
        uint256 startTime;          // Rental start timestamp
        uint256 lastGameTime;       // Last game completion
        uint256 totalPaid;          // Total amount paid for rental
        uint256 pricePerGame;       // For P2P revenue calculation
        uint256 listingId;          // P2P listing reference
        bool isProtocolRental;
    }

    struct P2PRentalListing {
        uint256 shipId;
        address owner;
        uint256 pricePerGame;
        uint256 maxGames;
        bool isActive;
        uint256 totalEarned;
        uint256 listedAt;
    }

    struct ProtocolRentalConfig {
        uint256 price;              // SHIP per game
        bool isActive;              // Whether available
        uint256 promoMultiplier;    // 100 = normal, 50 = 50% off
    }

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    // Contract references
    IBattleshipToken public battleshipToken;
    INFTManager public nftManager;
    ITokenomicsCore public tokenomicsCore;
    
    // Marketplace state
    uint256 public nextListingId = 1;
    mapping(uint256 => Listing) public listings;               // ListingId => Listing
    mapping(uint256 => BidHistory[]) public bidHistory;        // ListingId => Bid history
    mapping(address => uint256[]) public userListings;         // User => Listing IDs
    mapping(uint256 => uint256) public tokenToListing;         // TokenId => ListingId
    
    // Payment tokens
    mapping(address => bool) public acceptedTokens;            // Token => Accepted
    address[] public paymentTokens;                            // Array of accepted tokens
    
    // Statistics
    uint256 public totalListings;
    uint256 public totalSales;
    uint256 public totalVolume;                                // Total volume in SHIP tokens
    mapping(address => uint256) public volumeByToken;          // Volume by payment token
    mapping(address => uint256) public userSales;              // User => Sales count
    mapping(address => uint256) public userPurchases;          // User => Purchase count
    
    // Marketplace fees
    uint256 public totalFeesCollected;
    mapping(address => uint256) public feesByToken;            // Fees by payment token
    
    // Bid tracking for auctions
    mapping(uint256 => mapping(address => uint256)) public userBids; // ListingId => User => Bid amount
    mapping(address => uint256) public userBidCount;           // User => Total bids placed
    
    // =============================================================================
    // RENTAL SYSTEM DATA STRUCTURES
    // =============================================================================
    
    // Rental data structures
    struct ActiveRental {
        uint256 shipId;
        address renter;
        address owner;              // For P2P rentals (address(0) for protocol)
        uint256 gamesRemaining;
        uint256 maxHours;           // Time limit set by renter
        uint256 startTime;          // Rental start timestamp
        uint256 lastGameTime;       // Last game completion
        uint256 totalPaid;          // Total amount paid for rental
        uint256 pricePerGame;       // For P2P revenue calculation
        uint256 listingId;          // P2P listing reference
        bool isProtocolRental;
    }

    struct P2PRentalListing {
        uint256 shipId;
        address owner;
        uint256 pricePerGame;
        uint256 maxGames;
        bool isActive;
        uint256 totalEarned;
        uint256 listedAt;
    }

    struct ProtocolRentalConfig {
        uint256 price;              // SHIP per game
        bool isActive;              // Whether available
        uint256 promoMultiplier;    // 100 = normal, 50 = 50% off
    }

    // Rental state variables
    mapping(uint256 => ActiveRental) public activeRentals;        // shipId => rental
    mapping(address => uint256[]) public userActiveRentals;       // renter => shipIds
    mapping(uint256 => P2PRentalListing) public p2pListings;      // listingId => listing
    mapping(INFTManager.ShipType => ProtocolRentalConfig) public protocolRentals;
    uint256[] public allActiveRentalIds;                          // For cleanup processing
    uint256 public nextP2PListingId = 1;

    // Cleanup system
    mapping(address => bool) public adminCleaners;               // Admin cleaner addresses
    uint256 public totalCleanupRewards;                         // Total rewards paid
    mapping(address => uint256) public cleanerRewards;          // Rewards earned by cleaner

    // Rental limits
    uint256 public constant MIN_RENTAL_HOURS = 1;               // Minimum 1 hour
    uint256 public constant MAX_RENTAL_HOURS = 168;             // Maximum 1 week
    uint256 public constant MAX_RENTAL_GAMES = 50;              // Maximum 50 games
    uint256 public constant GRACE_PERIOD = 1 hours;             // 1 hour grace period

    // Fleet rental settings
    uint256 public fleetDiscount = 10;                          // 10% discount for full fleet
    uint256 public defaultRentalGames = 1;                      // Default rental duration
    
    // Rental state variables
    mapping(uint256 => ActiveRental) public activeRentals;        // shipId => rental
    mapping(address => uint256[]) public userActiveRentals;       // renter => shipIds
    mapping(uint256 => P2PRentalListing) public p2pListings;      // listingId => listing
    mapping(ShipType => ProtocolRentalConfig) public protocolRentals;
    uint256[] public allActiveRentalIds;                          // For cleanup processing
    uint256 public nextP2PListingId = 1;

    // Cleanup system
    mapping(address => bool) public adminCleaners;               // Admin cleaner addresses
    uint256 public totalCleanupRewards;                         // Total rewards paid
    mapping(address => uint256) public cleanerRewards;          // Rewards earned by cleaner

    // Rental limits
    uint256 public constant MIN_RENTAL_HOURS = 1;               // Minimum 1 hour
    uint256 public constant MAX_RENTAL_HOURS = 168;             // Maximum 1 week
    uint256 public constant MAX_RENTAL_GAMES = 50;              // Maximum 50 games
    uint256 public constant GRACE_PERIOD = 1 hours;             // 1 hour grace period

    // Fleet rental settings
    uint256 public fleetDiscount = 10;                          // 10% discount for full fleet
    uint256 public defaultRentalGames = 1;                      // Default rental duration

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        address paymentToken,
        uint256 price,
        ListingType listingType,
        uint256 expiresAt
    );
    
    event ListingUpdated(
        uint256 indexed listingId,
        uint256 newPrice,
        uint256 newExpiresAt
    );
    
    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller
    );
    
    event ItemSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        address paymentToken,
        uint256 price,
        uint256 marketplaceFee
    );
    
    event BidPlaced(
        uint256 indexed listingId,
        address indexed bidder,
        uint256 amount,
        uint256 timestamp
    );
    
    event AuctionExtended(
        uint256 indexed listingId,
        uint256 newExpiresAt
    );
    
    event PaymentTokenUpdated(address indexed token, bool accepted);
    event MarketplaceFeeUpdated(uint256 newFeePercentage);
    event ContractUpdated(string contractName, address newAddress);
    
    // Rental events
    event ShipRented(address indexed renter, uint256 indexed shipId, uint256 totalCost, uint256 maxHours);
    event ShipReturned(uint256 indexed shipId, address indexed renter, string reason);
    event P2PListingCreated(uint256 indexed listingId, uint256 indexed shipId, address indexed owner, uint256 pricePerGame);
    event P2PListingCancelled(uint256 indexed listingId, address indexed owner);
    event RentalCleaned(uint256 indexed shipId, address indexed cleaner, uint256 reward, bool isAdmin);
    event AdminCleanerUpdated(address indexed cleaner, bool isAdmin);
    event ProtocolRentalConfigUpdated(INFTManager.ShipType indexed shipType, uint256 price, bool isActive);
    
    // Rental events
    event ShipRented(address indexed renter, uint256 indexed shipId, uint256 totalCost, uint256 maxHours);
    event ShipReturned(uint256 indexed shipId, address indexed renter, string reason);
    event P2PListingCreated(uint256 indexed listingId, uint256 indexed shipId, address indexed owner, uint256 pricePerGame);
    event P2PListingCancelled(uint256 indexed listingId, address indexed owner);
    event RentalCleaned(uint256 indexed shipId, address indexed cleaner, uint256 reward, bool isAdmin);
    event AdminCleanerUpdated(address indexed cleaner, bool isAdmin);
    event ProtocolRentalConfigUpdated(ShipType indexed shipType, uint256 price, bool isActive);
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _battleshipToken,
        address _nftManager,
        address _tokenomicsCore
    ) Ownable(msg.sender) {
        require(_battleshipToken != address(0), "MarketplaceCore: Invalid token address");
        require(_nftManager != address(0), "MarketplaceCore: Invalid NFT manager address");
        require(_tokenomicsCore != address(0), "MarketplaceCore: Invalid tokenomics address");
        
        battleshipToken = IBattleshipToken(_battleshipToken);
        nftManager = INFTManager(_nftManager);
        tokenomicsCore = ITokenomicsCore(_tokenomicsCore);
        
        // Set default accepted tokens
        acceptedTokens[_battleshipToken] = true;  // SHIP token
        acceptedTokens[address(0)] = true;        // ETH
        paymentTokens.push(_battleshipToken);
        paymentTokens.push(address(0));
    }
    
    // =============================================================================
    // SECTION 8.1: NFT LISTING AND TRADING MECHANICS
    // =============================================================================
    
    /**
     * @dev Function1: Create fixed price listing
     * @param tokenId NFT token ID to list
     * @param paymentToken Token to accept payment in
     * @param price Fixed price for the NFT
     * @param duration Listing duration in seconds
     * @return listingId Generated listing ID
     */
    function createFixedPriceListing(
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 listingId) 
    {
        require(acceptedTokens[paymentToken], "MarketplaceCore: Payment token not accepted");
        require(price > 0, "MarketplaceCore: Price must be greater than 0");
        require(duration > 0 && duration <= MAX_AUCTION_DURATION, "MarketplaceCore: Invalid duration");
        require(nftManager.ownerOf(tokenId) == msg.sender, "MarketplaceCore: Not token owner");
        require(tokenToListing[tokenId] == 0, "MarketplaceCore: Token already listed");
        
        // Check NFT approval
        require(
            nftManager.getApproved(tokenId) == address(this) || 
            nftManager.isApprovedForAll(msg.sender, address(this)),
            "MarketplaceCore: NFT not approved for marketplace"
        );
        
        listingId = nextListingId++;
        uint256 expiresAt = block.timestamp.add(duration);
        
        listings[listingId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            paymentToken: paymentToken,
            price: price,
            listingType: ListingType.FIXED_PRICE,
            status: ListingStatus.ACTIVE,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            highestBid: 0,
            highestBidder: address(0),
            bidCount: 0
        });
        
        userListings[msg.sender].push(listingId);
        tokenToListing[tokenId] = listingId;
        totalListings++;
        
        emit ListingCreated(
            listingId,
            tokenId,
            msg.sender,
            paymentToken,
            price,
            ListingType.FIXED_PRICE,
            expiresAt
        );
        
        return listingId;
    }
    
    /**
     * @dev Function2: Create auction listing
     * @param tokenId NFT token ID to auction
     * @param paymentToken Token to accept payment in
     * @param startingBid Starting bid amount
     * @param duration Auction duration in seconds
     * @return listingId Generated listing ID
     */
    function createAuctionListing(
        uint256 tokenId,
        address paymentToken,
        uint256 startingBid,
        uint256 duration
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 listingId) 
    {
        require(acceptedTokens[paymentToken], "MarketplaceCore: Payment token not accepted");
        require(startingBid > 0, "MarketplaceCore: Starting bid must be greater than 0");
        require(
            duration >= MIN_AUCTION_DURATION && duration <= MAX_AUCTION_DURATION,
            "MarketplaceCore: Invalid auction duration"
        );
        require(nftManager.ownerOf(tokenId) == msg.sender, "MarketplaceCore: Not token owner");
        require(tokenToListing[tokenId] == 0, "MarketplaceCore: Token already listed");
        
        // Check NFT approval
        require(
            nftManager.getApproved(tokenId) == address(this) || 
            nftManager.isApprovedForAll(msg.sender, address(this)),
            "MarketplaceCore: NFT not approved for marketplace"
        );
        
        listingId = nextListingId++;
        uint256 expiresAt = block.timestamp.add(duration);
        
        listings[listingId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            paymentToken: paymentToken,
            price: startingBid,
            listingType: ListingType.AUCTION,
            status: ListingStatus.ACTIVE,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            highestBid: 0,
            highestBidder: address(0),
            bidCount: 0
        });
        
        userListings[msg.sender].push(listingId);
        tokenToListing[tokenId] = listingId;
        totalListings++;
        
        emit ListingCreated(
            listingId,
            tokenId,
            msg.sender,
            paymentToken,
            startingBid,
            ListingType.AUCTION,
            expiresAt
        );
        
        return listingId;
    }
    
    /**
     * @dev Function3: Purchase fixed price listing
     * @param listingId Listing ID to purchase
     */
    function purchaseFixedPrice(uint256 listingId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        Listing storage listing = listings[listingId];
        require(listing.status == ListingStatus.ACTIVE, "MarketplaceCore: Listing not active");
        require(listing.listingType == ListingType.FIXED_PRICE, "MarketplaceCore: Not a fixed price listing");
        require(block.timestamp <= listing.expiresAt, "MarketplaceCore: Listing expired");
        require(msg.sender != listing.seller, "MarketplaceCore: Cannot buy own listing");
        
        uint256 totalPrice = listing.price;
        uint256 marketplaceFee = totalPrice.mul(MARKETPLACE_FEE_PERCENTAGE).div(10000);
        uint256 sellerAmount = totalPrice.sub(marketplaceFee);
        
        // Handle payment
        _processPayment(listing.paymentToken, totalPrice, listing.seller, sellerAmount, marketplaceFee);
        
        // Transfer NFT
        nftManager.safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // Update listing status
        listing.status = ListingStatus.SOLD;
        tokenToListing[listing.tokenId] = 0;
        
        // Update statistics
        totalSales++;
        userSales[listing.seller]++;
        userPurchases[msg.sender]++;
        totalVolume = totalVolume.add(totalPrice);
        volumeByToken[listing.paymentToken] = volumeByToken[listing.paymentToken].add(totalPrice);
        
        emit ItemSold(
            listingId,
            listing.tokenId,
            listing.seller,
            msg.sender,
            listing.paymentToken,
            totalPrice,
            marketplaceFee
        );
    }
    
    /**
     * @dev Function4: Update listing price and duration
     * @param listingId Listing ID to update
     * @param newPrice New price (0 to keep current)
     * @param newDuration New duration in seconds (0 to keep current)
     */
    function updateListing(uint256 listingId, uint256 newPrice, uint256 newDuration) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "MarketplaceCore: Not listing owner");
        require(listing.status == ListingStatus.ACTIVE, "MarketplaceCore: Listing not active");
        
        // For auctions, don't allow updates if there are bids
        if (listing.listingType == ListingType.AUCTION && listing.bidCount > 0) {
            revert("MarketplaceCore: Cannot update auction with bids");
        }
        
        if (newPrice > 0) {
            listing.price = newPrice;
        }
        
        if (newDuration > 0) {
            require(newDuration <= MAX_AUCTION_DURATION, "MarketplaceCore: Duration too long");
            listing.expiresAt = block.timestamp.add(newDuration);
        }
        
        emit ListingUpdated(listingId, listing.price, listing.expiresAt);
    }
    
    /**
     * @dev Function5: Cancel active listing
     * @param listingId Listing ID to cancel
     */
    function cancelListing(uint256 listingId) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "MarketplaceCore: Not listing owner");
        require(listing.status == ListingStatus.ACTIVE, "MarketplaceCore: Listing not active");
        
        // For auctions, refund highest bidder if exists
        if (listing.listingType == ListingType.AUCTION && listing.highestBidder != address(0)) {
            _refundBid(listing.paymentToken, listing.highestBidder, listing.highestBid);
        }
        
        listing.status = ListingStatus.CANCELLED;
        tokenToListing[listing.tokenId] = 0;
        
        emit ListingCancelled(listingId, msg.sender);
    }

    // =============================================================================
    // SECTION 8.2: AUCTION SYSTEM IMPLEMENTATION
    // =============================================================================
    
    /**
     * @dev Function1: Place bid on auction
     * @param listingId Auction listing ID
     * @param bidAmount Bid amount
     */
    function placeBid(uint256 listingId, uint256 bidAmount) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        Listing storage listing = listings[listingId];
        require(listing.status == ListingStatus.ACTIVE, "MarketplaceCore: Listing not active");
        require(listing.listingType == ListingType.AUCTION, "MarketplaceCore: Not an auction");
        require(block.timestamp <= listing.expiresAt, "MarketplaceCore: Auction expired");
        require(msg.sender != listing.seller, "MarketplaceCore: Cannot bid on own auction");
        
        uint256 minimumBid;
        if (listing.highestBid == 0) {
            minimumBid = listing.price; // Starting bid
        } else {
            minimumBid = listing.highestBid.add(
                listing.highestBid.mul(MIN_BID_INCREMENT).div(10000)
            );
        }
        
        require(bidAmount >= minimumBid, "MarketplaceCore: Bid too low");
        
        // Handle payment based on token type
        if (listing.paymentToken == address(0)) {
            // ETH auction
            require(msg.value == bidAmount, "MarketplaceCore: Incorrect ETH amount");
        } else {
            // ERC20 auction
            require(msg.value == 0, "MarketplaceCore: No ETH should be sent");
            IERC20(listing.paymentToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        }
        
        // Refund previous highest bidder
        if (listing.highestBidder != address(0)) {
            _refundBid(listing.paymentToken, listing.highestBidder, listing.highestBid);
        }
        
        // Update auction state
        listing.highestBid = bidAmount;
        listing.highestBidder = msg.sender;
        listing.bidCount++;
        
        userBids[listingId][msg.sender] = bidAmount;
        userBidCount[msg.sender]++;
        
        // Add to bid history
        bidHistory[listingId].push(BidHistory({
            bidder: msg.sender,
            amount: bidAmount,
            timestamp: block.timestamp
        }));
        
        // Extend auction if bid placed in last 10 minutes
        if (listing.expiresAt.sub(block.timestamp) <= AUCTION_EXTENSION_TIME) {
            listing.expiresAt = block.timestamp.add(AUCTION_EXTENSION_TIME);
            emit AuctionExtended(listingId, listing.expiresAt);
        }
        
        emit BidPlaced(listingId, msg.sender, bidAmount, block.timestamp);
    }
    
    /**
     * @dev Function2: Settle completed auction
     * @param listingId Auction listing ID to settle
     */
    function settleAuction(uint256 listingId) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        Listing storage listing = listings[listingId];
        require(listing.status == ListingStatus.ACTIVE, "MarketplaceCore: Listing not active");
        require(listing.listingType == ListingType.AUCTION, "MarketplaceCore: Not an auction");
        require(block.timestamp > listing.expiresAt, "MarketplaceCore: Auction still active");
        
        if (listing.highestBidder == address(0)) {
            // No bids - mark as expired
            listing.status = ListingStatus.EXPIRED;
            tokenToListing[listing.tokenId] = 0;
        } else {
            // Process winning bid
            uint256 totalPrice = listing.highestBid;
            uint256 marketplaceFee = totalPrice.mul(MARKETPLACE_FEE_PERCENTAGE).div(10000);
            uint256 sellerAmount = totalPrice.sub(marketplaceFee);
            
            // Transfer payment to seller and collect fees
            _transferPayment(listing.paymentToken, listing.seller, sellerAmount);
            _collectFees(listing.paymentToken, marketplaceFee);
            
            // Transfer NFT to winner
            nftManager.safeTransferFrom(listing.seller, listing.highestBidder, listing.tokenId);
            
            // Update listing status
            listing.status = ListingStatus.SOLD;
            tokenToListing[listing.tokenId] = 0;
            
            // Update statistics
            totalSales++;
            userSales[listing.seller]++;
            userPurchases[listing.highestBidder]++;
            totalVolume = totalVolume.add(totalPrice);
            volumeByToken[listing.paymentToken] = volumeByToken[listing.paymentToken].add(totalPrice);
            
            emit ItemSold(
                listingId,
                listing.tokenId,
                listing.seller,
                listing.highestBidder,
                listing.paymentToken,
                totalPrice,
                marketplaceFee
            );
        }
    }
    
    /**
     * @dev Function3: Get auction bid history
     * @param listingId Auction listing ID
     * @return bidders Array of bidder addresses
     * @return amounts Array of bid amounts
     * @return timestamps Array of bid timestamps
     */
    function getAuctionBidHistory(uint256 listingId) 
        external 
        view 
        returns (
            address[] memory bidders,
            uint256[] memory amounts,
            uint256[] memory timestamps
        ) 
    {
        BidHistory[] memory history = bidHistory[listingId];
        uint256 length = history.length;
        
        bidders = new address[](length);
        amounts = new uint256[](length);
        timestamps = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            bidders[i] = history[i].bidder;
            amounts[i] = history[i].amount;
            timestamps[i] = history[i].timestamp;
        }
    }
    
    /**
     * @dev Function4: Check if auction can be settled
     * @param listingId Auction listing ID
     * @return canSettle Whether auction can be settled
     * @return timeRemaining Time remaining in seconds (0 if expired)
     */
    function canSettleAuction(uint256 listingId) 
        external 
        view 
        returns (bool canSettle, uint256 timeRemaining) 
    {
        Listing memory listing = listings[listingId];
        
        if (listing.listingType != ListingType.AUCTION || listing.status != ListingStatus.ACTIVE) {
            return (false, 0);
        }
        
        if (block.timestamp > listing.expiresAt) {
            canSettle = true;
            timeRemaining = 0;
        } else {
            canSettle = false;
            timeRemaining = listing.expiresAt.sub(block.timestamp);
        }
    }
    
    /**
     * @dev Internal function to refund bid
     */
    function _refundBid(address paymentToken, address bidder, uint256 amount) internal {
        if (paymentToken == address(0)) {
            // Refund ETH
            payable(bidder).transfer(amount);
        } else {
            // Refund ERC20
            IERC20(paymentToken).safeTransfer(bidder, amount);
        }
    }
    
    // =============================================================================
    // SECTION 8.3: MARKETPLACE FEES AND REVENUE SHARING
    // =============================================================================
    
    /**
     * @dev Function1: Process payment for purchases
     * @param paymentToken Token being used for payment
     * @param totalAmount Total payment amount
     * @param seller Seller address
     * @param sellerAmount Amount going to seller
     * @param feeAmount Marketplace fee amount
     */
    function _processPayment(
        address paymentToken,
        uint256 totalAmount,
        address seller,
        uint256 sellerAmount,
        uint256 feeAmount
    ) internal {
        if (paymentToken == address(0)) {
            // ETH payment
            require(msg.value == totalAmount, "MarketplaceCore: Incorrect ETH amount");
            
            // Transfer to seller
            payable(seller).transfer(sellerAmount);
            
            // Keep fees in contract for later distribution
        } else {
            // ERC20 payment
            require(msg.value == 0, "MarketplaceCore: No ETH should be sent");
            
            // Transfer from buyer
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), totalAmount);
            
            // Transfer to seller
            IERC20(paymentToken).safeTransfer(seller, sellerAmount);
            
            // Keep fees in contract for later distribution
        }
        
        // Record fees
        _collectFees(paymentToken, feeAmount);
    }
    
    /**
     * @dev Function2: Transfer payment (for auction settlements)
     * @param paymentToken Token to transfer
     * @param recipient Recipient address
     * @param amount Amount to transfer
     */
    function _transferPayment(address paymentToken, address recipient, uint256 amount) internal {
        if (paymentToken == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            IERC20(paymentToken).safeTransfer(recipient, amount);
        }
    }
    
    /**
     * @dev Function3: Collect and track marketplace fees
     * @param paymentToken Token fees are collected in
     * @param feeAmount Fee amount collected
     */
    function _collectFees(address paymentToken, uint256 feeAmount) internal {
        totalFeesCollected = totalFeesCollected.add(feeAmount);
        feesByToken[paymentToken] = feesByToken[paymentToken].add(feeAmount);
        
        // Record revenue with TokenomicsCore
        tokenomicsCore.recordMarketplaceRevenue(feeAmount);
    }
    
    /**
     * @dev Function4: Distribute collected fees to TokenomicsCore
     * @param paymentToken Token to distribute fees for
     */
    function distributeFees(address paymentToken) 
        external 
        nonReentrant 
        onlyOwner 
    {
        uint256 feeAmount = feesByToken[paymentToken];
        require(feeAmount > 0, "MarketplaceCore: No fees to distribute");
        
        feesByToken[paymentToken] = 0;
        
        if (paymentToken == address(0)) {
            // Transfer ETH fees
            payable(address(tokenomicsCore)).transfer(feeAmount);
        } else {
            // Transfer ERC20 fees
            IERC20(paymentToken).safeTransfer(address(tokenomicsCore), feeAmount);
        }
    }
    
    /**
     * @dev Function5: Get marketplace revenue statistics
     * @return totalFees Total fees collected across all tokens
     * @return totalVolume_ Total trading volume
     * @return totalSales_ Total number of sales
     * @return avgSalePrice Average sale price
     */
    function getRevenueStats() 
        external 
        view 
        returns (
            uint256 totalFees,
            uint256 totalVolume_,
            uint256 totalSales_,
            uint256 avgSalePrice
        ) 
    {
        totalFees = totalFeesCollected;
        totalVolume_ = totalVolume;
        totalSales_ = totalSales;
        
        if (totalSales > 0) {
            avgSalePrice = totalVolume.div(totalSales);
        }
    }
    
    /**
     * @dev Function6: Get fees collected by payment token
     * @return tokens Array of payment tokens
     * @return fees Array of fees collected per token
     */
    function getFeesByToken() 
        external 
        view 
        returns (address[] memory tokens, uint256[] memory fees) 
    {
        tokens = new address[](paymentTokens.length);
        fees = new uint256[](paymentTokens.length);
        
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            tokens[i] = paymentTokens[i];
            fees[i] = feesByToken[paymentTokens[i]];
        }
    }
    
    // =============================================================================
    // MARKETPLACE MANAGEMENT AND VIEW FUNCTIONS
    // =============================================================================
    
    /**
     * @dev Add accepted payment token
     * @param token Token address to add (address(0) for ETH)
     */
    function addPaymentToken(address token) external onlyOwner {
        require(!acceptedTokens[token], "MarketplaceCore: Token already accepted");
        
        acceptedTokens[token] = true;
        paymentTokens.push(token);
        
        emit PaymentTokenUpdated(token, true);
    }
    
    /**
     * @dev Remove accepted payment token
     * @param token Token address to remove
     */
    function removePaymentToken(address token) external onlyOwner {
        require(acceptedTokens[token], "MarketplaceCore: Token not accepted");
        require(paymentTokens.length > 1, "MarketplaceCore: Cannot remove last payment token");
        
        acceptedTokens[token] = false;
        
        // Remove from array
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == token) {
                paymentTokens[i] = paymentTokens[paymentTokens.length - 1];
                paymentTokens.pop();
                break;
            }
        }
        
        emit PaymentTokenUpdated(token, false);
    }
    
    /**
     * @dev Get user's active listings
     * @param user User address
     * @return listingIds Array of active listing IDs
     */
    function getUserActiveListings(address user) 
        external 
        view 
        returns (uint256[] memory listingIds) 
    {
        uint256[] memory allListings = userListings[user];
        uint256[] memory tempIds = new uint256[](allListings.length);
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allListings.length; i++) {
            if (listings[allListings[i]].status == ListingStatus.ACTIVE) {
                tempIds[activeCount] = allListings[i];
                activeCount++;
            }
        }
        
        listingIds = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            listingIds[i] = tempIds[i];
        }
    }
    
    /**
     * @dev Get active listings by NFT type
     * @param tokenType NFT type to filter by
     * @param maxResults Maximum results to return
     * @return listingIds Array of listing IDs
     * @return tokenIds Array of token IDs
     * @return prices Array of prices
     * @return sellers Array of seller addresses
     */
    function getActiveListingsByType(
        INFTManager.TokenType tokenType,
        uint256 maxResults
    ) 
        external 
        view 
        returns (
            uint256[] memory listingIds,
            uint256[] memory tokenIds,
            uint256[] memory prices,
            address[] memory sellers
        ) 
    {
        uint256[] memory tempListingIds = new uint256[](maxResults);
        uint256[] memory tempTokenIds = new uint256[](maxResults);
        uint256[] memory tempPrices = new uint256[](maxResults);
        address[] memory tempSellers = new address[](maxResults);
        uint256 resultCount = 0;
        
        for (uint256 i = 1; i < nextListingId && resultCount < maxResults; i++) {
            Listing memory listing = listings[i];
            
            if (listing.status == ListingStatus.ACTIVE && 
                block.timestamp <= listing.expiresAt &&
                nftManager.getTokenType(listing.tokenId) == tokenType) {
                
                tempListingIds[resultCount] = i;
                tempTokenIds[resultCount] = listing.tokenId;
                tempPrices[resultCount] = listing.price;
                tempSellers[resultCount] = listing.seller;
                resultCount++;
            }
        }
        
        // Create exact-size arrays
        listingIds = new uint256[](resultCount);
        tokenIds = new uint256[](resultCount);
        prices = new uint256[](resultCount);
        sellers = new address[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            listingIds[i] = tempListingIds[i];
            tokenIds[i] = tempTokenIds[i];
            prices[i] = tempPrices[i];
            sellers[i] = tempSellers[i];
        }
    }
    
    /**
     * @dev Get marketplace statistics
     * @return totalListings_ Total listings created
     * @return activeListing Number of active listings
     * @return totalSales_ Total sales completed
     * @return totalVolume_ Total trading volume
     * @return avgPrice Average sale price
     */
    function getMarketplaceStats() 
        external 
        view 
        returns (
            uint256 totalListings_,
            uint256 activeListing,
            uint256 totalSales_,
            uint256 totalVolume_,
            uint256 avgPrice
        ) 
    {
        totalListings_ = totalListings;
        totalSales_ = totalSales;
        totalVolume_ = totalVolume;
        
        // Count active listings
        for (uint256 i = 1; i < nextListingId; i++) {
            if (listings[i].status == ListingStatus.ACTIVE && 
                block.timestamp <= listings[i].expiresAt) {
                activeListing++;
            }
        }
        
        if (totalSales > 0) {
            avgPrice = totalVolume.div(totalSales);
        }
    }
    
    /**
     * @dev Update contract references
     * @param contractName Name of contract to update
     * @param newAddress New contract address
     */
    function updateContract(string calldata contractName, address newAddress) 
        external 
        onlyOwner 
    {
        require(newAddress != address(0), "MarketplaceCore: Invalid address");
        
        bytes32 nameHash = keccak256(abi.encodePacked(contractName));
        
        if (nameHash == keccak256(abi.encodePacked("BattleshipToken"))) {
            battleshipToken = IBattleshipToken(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("NFTManager"))) {
            nftManager = INFTManager(newAddress);
        } else if (nameHash == keccak256(abi.encodePacked("TokenomicsCore"))) {
            tokenomicsCore = ITokenomicsCore(newAddress);
        } else {
            revert("MarketplaceCore: Unknown contract name");
        }
        
        emit ContractUpdated(contractName, newAddress);
    }
    
    /**
     * @dev Pause marketplace operations
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause marketplace operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecoverToken(address token, uint256 amount) 
        external 
        onlyOwner 
    {
        require(amount > 0, "MarketplaceCore: Invalid amount");
        
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }
    
    /**
     * @dev Get accepted payment tokens
     * @return tokens Array of accepted payment token addresses
     */
    function getAcceptedTokens() external view returns (address[] memory tokens) {
        tokens = new address[](paymentTokens.length);
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            tokens[i] = paymentTokens[i];
        }
    }

    // =============================================================================
    // RENTAL SYSTEM FUNCTIONS
    // =============================================================================

    /**
     * @dev Rent a full fleet of protocol ships (1 of each type)
     * @param maxHours Maximum hours to hold the rental
     * @return shipIds Array of 5 rented ship IDs
     */
    function rentFullFleet(uint256 maxHours) external nonReentrant whenNotPaused returns (uint256[5] memory shipIds) {
        require(maxHours >= MIN_RENTAL_HOURS && maxHours <= MAX_RENTAL_HOURS, "Invalid time limit");
        
        // Calculate total cost with fleet discount
        uint256 totalCost = _calculateFleetRentalCost();
        require(battleshipToken.transferFrom(msg.sender, address(this), totalCost), "Payment failed");
        
        // Mint rental ships (1 of each type)
        INFTManager.ShipType[5] memory fleetTypes = [
            INFTManager.ShipType.DESTROYER, 
            INFTManager.ShipType.SUBMARINE, 
            INFTManager.ShipType.CRUISER, 
            INFTManager.ShipType.BATTLESHIP, 
            INFTManager.ShipType.CARRIER
        ];
        
        for (uint256 i = 0; i < 5; i++) {
            require(protocolRentals[fleetTypes[i]].isActive, "Ship type not available");
            
            // Mint protocol rental ship
            uint256 shipId = nftManager.createRentalShip(msg.sender, fleetTypes[i]);
            shipIds[i] = shipId;
            
            // Create rental record
            activeRentals[shipId] = ActiveRental({
                shipId: shipId,
                renter: msg.sender,
                owner: address(0),
                gamesRemaining: defaultRentalGames,
                maxHours: maxHours,
                startTime: block.timestamp,
                lastGameTime: 0,
                totalPaid: protocolRentals[fleetTypes[i]].price,
                pricePerGame: protocolRentals[fleetTypes[i]].price,
                listingId: 0,
                isProtocolRental: true
            });
            
            // Add to tracking
            userActiveRentals[msg.sender].push(shipId);
            allActiveRentalIds.push(shipId);
            
            emit ShipRented(msg.sender, shipId, protocolRentals[fleetTypes[i]].price, maxHours);
        }
        
        // Record revenue for tokenomics
        tokenomicsCore.recordMarketplaceRevenue(totalCost);
    }

    /**
     * @dev Rent a single protocol ship
     * @param shipType Type of ship to rent
     * @param maxHours Maximum hours to hold the rental
     * @return shipId Rented ship ID
     */
    function rentProtocolShip(INFTManager.ShipType shipType, uint256 maxHours) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 shipId) 
    {
        require(maxHours >= MIN_RENTAL_HOURS && maxHours <= MAX_RENTAL_HOURS, "Invalid time limit");
        require(protocolRentals[shipType].isActive, "Ship type not available");
        
        uint256 cost = _getProtocolRentalPrice(shipType);
        require(battleshipToken.transferFrom(msg.sender, address(this), cost), "Payment failed");
        
        // Mint protocol rental ship
        shipId = nftManager.createRentalShip(msg.sender, shipType);
        
        // Create rental record
        activeRentals[shipId] = ActiveRental({
            shipId: shipId,
            renter: msg.sender,
            owner: address(0),
            gamesRemaining: defaultRentalGames,
            maxHours: maxHours,
            startTime: block.timestamp,
            lastGameTime: 0,
            totalPaid: cost,
            pricePerGame: cost,
            listingId: 0,
            isProtocolRental: true
        });
        
        // Add to tracking
        userActiveRentals[msg.sender].push(shipId);
        allActiveRentalIds.push(shipId);
        
        emit ShipRented(msg.sender, shipId, cost, maxHours);
        
        // Record revenue for tokenomics
        tokenomicsCore.recordMarketplaceRevenue(cost);
    }

    /**
     * @dev List a ship for P2P rental
     * @param shipId Ship to list for rental
     * @param pricePerGame Price in SHIP tokens per game
     * @param maxGames Maximum games per rental period
     * @return listingId Created listing ID
     */
    function listShipForRent(
        uint256 shipId, 
        uint256 pricePerGame, 
        uint256 maxGames
    ) external nonReentrant whenNotPaused returns (uint256 listingId) {
        require(nftManager.ownerOf(shipId) == msg.sender, "Not ship owner");
        require(pricePerGame > 0, "Invalid price");
        require(maxGames > 0 && maxGames <= MAX_RENTAL_GAMES, "Invalid game count");
        require(tokenToListing[shipId] == 0, "Ship already listed");
        
        // Transfer ship to marketplace for escrow
        nftManager.transferFrom(msg.sender, address(this), shipId);
        
        listingId = nextP2PListingId++;
        
        p2pListings[listingId] = P2PRentalListing({
            shipId: shipId,
            owner: msg.sender,
            pricePerGame: pricePerGame,
            maxGames: maxGames,
            isActive: true,
            totalEarned: 0,
            listedAt: block.timestamp
        });
        
        tokenToListing[shipId] = listingId;
        userListings[msg.sender].push(listingId);
        
        emit P2PListingCreated(listingId, shipId, msg.sender, pricePerGame);
    }

    /**
     * @dev Rent a player's ship
     * @param listingId P2P listing ID
     * @param gameCount Number of games to rent for
     * @param maxHours Maximum hours to hold the rental
     * @return shipId Rented ship ID
     */
    function rentPlayerShip(
        uint256 listingId, 
        uint256 gameCount,
        uint256 maxHours
    ) external nonReentrant whenNotPaused returns (uint256 shipId) {
        require(maxHours >= MIN_RENTAL_HOURS && maxHours <= MAX_RENTAL_HOURS, "Invalid time limit");
        
        P2PRentalListing storage listing = p2pListings[listingId];
        require(listing.isActive, "Listing not active");
        require(gameCount > 0 && gameCount <= listing.maxGames, "Invalid game count");
        
        uint256 totalCost = listing.pricePerGame * gameCount;
        require(battleshipToken.transferFrom(msg.sender, address(this), totalCost), "Payment failed");
        
        shipId = listing.shipId;
        
        // Transfer ship to renter
        nftManager.transferFrom(address(this), msg.sender, shipId);
        
        // Create rental record
        activeRentals[shipId] = ActiveRental({
            shipId: shipId,
            renter: msg.sender,
            owner: listing.owner,
            gamesRemaining: gameCount,
            maxHours: maxHours,
            startTime: block.timestamp,
            lastGameTime: 0,
            totalPaid: totalCost,
            pricePerGame: listing.pricePerGame,
            listingId: listingId,
            isProtocolRental: false
        });
        
        // Add to tracking
        userActiveRentals[msg.sender].push(shipId);
        allActiveRentalIds.push(shipId);
        
        // Mark listing as inactive while rented
        listing.isActive = false;
        
        emit ShipRented(msg.sender, shipId, totalCost, maxHours);
    }

    // =============================================================================
    // CLEANUP SYSTEM
    // =============================================================================

    /**
     * @dev Check if a rental is expired
     * @param shipId Ship ID to check
     * @return expired Whether the rental is expired
     * @return reason Reason for expiry
     */
    function isRentalExpired(uint256 shipId) public view returns (bool expired, string memory reason) {
        ActiveRental storage rental = activeRentals[shipId];
        if (rental.renter == address(0)) return (false, "No active rental");
        
        // Check game-based expiry
        if (rental.gamesRemaining == 0) {
            return (true, "Games exhausted");
        }
        
        // Check time-based expiry (with grace period)
        uint256 elapsed = block.timestamp - rental.startTime;
        uint256 maxTime = rental.maxHours * 1 hours + GRACE_PERIOD;
        
        if (elapsed >= maxTime) {
            return (true, "Time expired");
        }
        
        return (false, "Active");
    }

    /**
     * @dev Get all expired rental IDs
     * @return expiredIds Array of expired ship IDs
     */
    function getExpiredRentalIds() external view returns (uint256[] memory expiredIds) {
        uint256[] memory tempIds = new uint256[](allActiveRentalIds.length);
        uint256 expiredCount = 0;
        
        for (uint256 i = 0; i < allActiveRentalIds.length; i++) {
            uint256 shipId = allActiveRentalIds[i];
            (bool expired,) = isRentalExpired(shipId);
            if (expired) {
                tempIds[expiredCount] = shipId;
                expiredCount++;
            }
        }
        
        // Create properly sized array
        expiredIds = new uint256[](expiredCount);
        for (uint256 i = 0; i < expiredCount; i++) {
            expiredIds[i] = tempIds[i];
        }
    }

    /**
     * @dev Clean up expired rentals (public function with rewards)
     * @param expiredShipIds Array of expired ship IDs to clean up
     * @return totalReward Total SHIP tokens rewarded to cleaner
     */
    function cleanupExpiredRentals(uint256[] calldata expiredShipIds) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 totalReward) 
    {
        require(expiredShipIds.length > 0, "No ships provided");
        require(expiredShipIds.length <= 20, "Batch too large");
        
        uint256 successCount = 0;
        uint256 totalStakingFees = 0;
        bool isAdminCleaner = adminCleaners[msg.sender];
        
        for (uint256 i = 0; i < expiredShipIds.length; i++) {
            uint256 shipId = expiredShipIds[i];
            (bool expired, string memory reason) = isRentalExpired(shipId);
            
            if (expired) {
                uint256 stakingFee = _forceReturnRental(shipId, reason);
                totalStakingFees += stakingFee;
                successCount++;
            }
        }
        
        require(successCount > 0, "No expired rentals found");
        
        // Calculate cleanup reward (10% of staking fees for regular cleaners)
        if (!isAdminCleaner && totalStakingFees > 0) {
            totalReward = totalStakingFees * 10 / 100;
            
            // Send reward to cleaner
            battleshipToken.transfer(msg.sender, totalReward);
            
            // Update cleaner stats
            cleanerRewards[msg.sender] += totalReward;
            totalCleanupRewards += totalReward;
            
            // Send remaining 90% to staking
            uint256 stakingAmount = totalStakingFees - totalReward;
            if (stakingAmount > 0) {
                battleshipToken.transfer(address(0), stakingAmount); // Placeholder - will be StakingPool
            }
        } else {
            // Admin cleaner - send 100% to staking
            if (totalStakingFees > 0) {
                battleshipToken.transfer(address(0), totalStakingFees); // Placeholder - will be StakingPool
            }
        }
        
        emit RentalCleaned(0, msg.sender, totalReward, isAdminCleaner); // shipId=0 for batch
    }

    /**
     * @dev Internal function to force return a rental
     * @param shipId Ship ID to return
     * @param reason Reason for return
     * @return stakingFee Amount that should go to staking pool
     */
    function _forceReturnRental(uint256 shipId, string memory reason) internal returns (uint256 stakingFee) {
        ActiveRental storage rental = activeRentals[shipId];
        
        if (rental.isProtocolRental) {
            // Burn protocol rental ship
            nftManager.burn(shipId);
            stakingFee = rental.totalPaid; // Protocol rental fees go to staking
        } else {
            // Return P2P rental ship to owner
            nftManager.transferFrom(rental.renter, rental.owner, shipId);
            
            // Calculate revenue split for P2P rental
            uint256 totalRevenue = rental.totalPaid;
            uint256 marketplaceFee = totalRevenue * MARKETPLACE_FEE_PERCENTAGE / 10000; // 2.5%
            uint256 ownerPayment = totalRevenue - marketplaceFee;
            
            // Pay owner (85% after marketplace fee)
            battleshipToken.transfer(rental.owner, ownerPayment);
            
            // Marketplace fee goes to staking
            stakingFee = marketplaceFee;
            
            // Reactivate P2P listing
            if (rental.listingId > 0) {
                p2pListings[rental.listingId].isActive = true;
            }
        }
        
        // Clean up tracking
        _removeFromActiveRentals(shipId);
        
        emit ShipReturned(shipId, rental.renter, reason);
    }

    // =============================================================================
    // RENTAL ADMIN FUNCTIONS
    // =============================================================================

    /**
     * @dev Set admin cleaner status
     * @param cleaner Address to update
     * @param isAdmin Whether address is an admin cleaner
     */
    function setAdminCleaner(address cleaner, bool isAdmin) external onlyOwner {
        adminCleaners[cleaner] = isAdmin;
        emit AdminCleanerUpdated(cleaner, isAdmin);
    }

    /**
     * @dev Set protocol rental configuration
     * @param shipType Ship type to configure
     * @param price Price per game in SHIP tokens
     * @param isActive Whether ship type is available for rental
     */
    function setProtocolRentalConfig(
        INFTManager.ShipType shipType, 
        uint256 price, 
        bool isActive
    ) external onlyOwner {
        protocolRentals[shipType] = ProtocolRentalConfig({
            price: price,
            isActive: isActive,
            promoMultiplier: 100 // 100 = normal price
        });
        
        emit ProtocolRentalConfigUpdated(shipType, price, isActive);
    }

    /**
     * @dev Set fleet rental discount percentage
     * @param discountPercent Discount percentage (10 = 10% discount)
     */
    function setFleetDiscount(uint256 discountPercent) external onlyOwner {
        require(discountPercent <= 50, "Discount too high");
        fleetDiscount = discountPercent;
    }

    /**
     * @dev Emergency return rental (admin only)
     * @param shipId Ship ID to return
     */
    function emergencyReturnRental(uint256 shipId) external onlyOwner {
        (bool expired,) = isRentalExpired(shipId);
        require(expired || activeRentals[shipId].renter != address(0), "No active rental");
        
        _forceReturnRental(shipId, "Emergency admin return");
    }

    // =============================================================================
    // RENTAL VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get protocol rental price for a ship type
     * @param shipType Ship type
     * @return price Price per game
     */
    function getProtocolRentalPrice(INFTManager.ShipType shipType) external view returns (uint256 price) {
        return _getProtocolRentalPrice(shipType);
    }

    /**
     * @dev Check if a ship is currently rented
     * @param shipId Ship ID to check
     * @return isRented Whether ship is currently rented
     */
    function isActiveRental(uint256 shipId) external view returns (bool isRented) {
        return activeRentals[shipId].renter != address(0);
    }

    /**
     * @dev Get user's active rentals
     * @param user User address
     * @return shipIds Array of ship IDs currently rented by user
     */
    function getUserActiveRentals(address user) external view returns (uint256[] memory shipIds) {
        return userActiveRentals[user];
    }

    /**
     * @dev Decrement rental use (called by BattleshipGame)
     * @param shipId Ship ID to decrement
     */
    function decrementRentalUse(uint256 shipId) external {
        require(msg.sender == address(battleshipGame), "Only BattleshipGame can call");
        ActiveRental storage rental = activeRentals[shipId];
        require(rental.gamesRemaining > 0, "No games remaining");
        
        rental.gamesRemaining--;
        rental.lastGameTime = block.timestamp;
        
        // Check if rental should end
        (bool expired,) = isRentalExpired(shipId);
        if (expired) {
            _forceReturnRental(shipId, "Games completed");
        }
    }

    // =============================================================================
    // RENTAL HELPER FUNCTIONS
    // =============================================================================

    /**
     * @dev Calculate fleet rental cost with discount
     * @return totalCost Total cost for full fleet rental
     */
    function _calculateFleetRentalCost() internal view returns (uint256 totalCost) {
        totalCost = _getProtocolRentalPrice(INFTManager.ShipType.DESTROYER) +
                    _getProtocolRentalPrice(INFTManager.ShipType.SUBMARINE) +
                    _getProtocolRentalPrice(INFTManager.ShipType.CRUISER) +
                    _getProtocolRentalPrice(INFTManager.ShipType.BATTLESHIP) +
                    _getProtocolRentalPrice(INFTManager.ShipType.CARRIER);
        
        // Apply fleet discount
        if (fleetDiscount > 0) {
            totalCost = totalCost * (100 - fleetDiscount) / 100;
        }
    }

    /**
     * @dev Get protocol rental price with promo multiplier
     * @param shipType Ship type
     * @return price Effective price per game
     */
    function _getProtocolRentalPrice(INFTManager.ShipType shipType) internal view returns (uint256 price) {
        ProtocolRentalConfig storage config = protocolRentals[shipType];
        price = config.price * config.promoMultiplier / 100;
    }

    /**
     * @dev Remove ship from active rental tracking
     * @param shipId Ship ID to remove
     */
    function _removeFromActiveRentals(uint256 shipId) internal {
        ActiveRental storage rental = activeRentals[shipId];
        address renter = rental.renter;
        
        // Remove from user's active rentals
        uint256[] storage userRentals = userActiveRentals[renter];
        for (uint256 i = 0; i < userRentals.length; i++) {
            if (userRentals[i] == shipId) {
                userRentals[i] = userRentals[userRentals.length - 1];
                userRentals.pop();
                break;
            }
        }
        
        // Remove from global active rentals
        for (uint256 i = 0; i < allActiveRentalIds.length; i++) {
            if (allActiveRentalIds[i] == shipId) {
                allActiveRentalIds[i] = allActiveRentalIds[allActiveRentalIds.length - 1];
                allActiveRentalIds.pop();
                break;
            }
        }
        
        // Clear rental record
        delete activeRentals[shipId];
    }

    // =============================================================================
    // RENTAL CORE FUNCTIONS
    // =============================================================================

    /**
     * @dev Rent a full fleet of protocol ships (1 of each type)
     * @param maxHours Maximum hours to hold the rental
     * @return shipIds Array of 5 rented ship IDs
     */
    function rentFullFleet(uint256 maxHours) external nonReentrant whenNotPaused returns (uint256[5] memory shipIds) {
        require(maxHours >= MIN_RENTAL_HOURS && maxHours <= MAX_RENTAL_HOURS, "Invalid time limit");
        
        // Calculate total cost with fleet discount
        uint256 totalCost = _calculateFleetRentalCost();
        require(battleshipToken.transferFrom(msg.sender, address(this), totalCost), "Payment failed");
        
        // Mint rental ships (1 of each type)
        ShipType[5] memory fleetTypes = [ShipType.DESTROYER, ShipType.SUBMARINE, ShipType.CRUISER, ShipType.BATTLESHIP, ShipType.CARRIER];
        
        for (uint256 i = 0; i < 5; i++) {
            require(protocolRentals[fleetTypes[i]].isActive, "Ship type not available");
            
            // Mint protocol rental ship
            uint256 shipId = nftManager.createRentalShip(msg.sender, fleetTypes[i]);
            shipIds[i] = shipId;
            
            // Create rental record
            activeRentals[shipId] = ActiveRental({
                shipId: shipId,
                renter: msg.sender,
                owner: address(0),
                gamesRemaining: defaultRentalGames,
                maxHours: maxHours,
                startTime: block.timestamp,
                lastGameTime: 0,
                totalPaid: protocolRentals[fleetTypes[i]].price,
                pricePerGame: protocolRentals[fleetTypes[i]].price,
                listingId: 0,
                isProtocolRental: true
            });
            
            // Add to tracking
            userActiveRentals[msg.sender].push(shipId);
            allActiveRentalIds.push(shipId);
            
            emit ShipRented(msg.sender, shipId, protocolRentals[fleetTypes[i]].price, maxHours);
        }
        
        // Record revenue for tokenomics
        tokenomicsCore.recordMarketplaceRevenue(totalCost);
    }

    /**
     * @dev Rent a single protocol ship
     * @param shipType Type of ship to rent
     * @param maxHours Maximum hours to hold the rental
     * @return shipId Rented ship ID
     */
    function rentProtocolShip(ShipType shipType, uint256 maxHours) external nonReentrant whenNotPaused returns (uint256 shipId) {
        require(maxHours >= MIN_RENTAL_HOURS && maxHours <= MAX_RENTAL_HOURS, "Invalid time limit");
        require(protocolRentals[shipType].isActive, "Ship type not available");
        
        uint256 cost = _getProtocolRentalPrice(shipType);
        require(battleshipToken.transferFrom(msg.sender, address(this), cost), "Payment failed");
        
        // Mint protocol rental ship
        shipId = nftManager.createRentalShip(msg.sender, shipType);
        
        // Create rental record
        activeRentals[shipId] = ActiveRental({
            shipId: shipId,
            renter: msg.sender,
            owner: address(0),
            gamesRemaining: defaultRentalGames,
            maxHours: maxHours,
            startTime: block.timestamp,
            lastGameTime: 0,
            totalPaid: cost,
            pricePerGame: cost,
            listingId: 0,
            isProtocolRental: true
        });
        
        // Add to tracking
        userActiveRentals[msg.sender].push(shipId);
        allActiveRentalIds.push(shipId);
        
        emit ShipRented(msg.sender, shipId, cost, maxHours);
        
        // Record revenue for tokenomics
        tokenomicsCore.recordMarketplaceRevenue(cost);
    }

    /**
     * @dev List a ship for P2P rental
     * @param shipId Ship to list for rental
     * @param pricePerGame Price in SHIP tokens per game
     * @param maxGames Maximum games per rental period
     * @return listingId Created listing ID
     */
    function listShipForRent(
        uint256 shipId, 
        uint256 pricePerGame, 
        uint256 maxGames
    ) external nonReentrant whenNotPaused returns (uint256 listingId) {
        require(nftManager.ownerOf(shipId) == msg.sender, "Not ship owner");
        require(pricePerGame > 0, "Invalid price");
        require(maxGames > 0 && maxGames <= MAX_RENTAL_GAMES, "Invalid game count");
        require(tokenToListing[shipId] == 0, "Ship already listed");
        
        // Transfer ship to marketplace for escrow
        nftManager.transferFrom(msg.sender, address(this), shipId);
        
        listingId = nextP2PListingId++;
        
        p2pListings[listingId] = P2PRentalListing({
            shipId: shipId,
            owner: msg.sender,
            pricePerGame: pricePerGame,
            maxGames: maxGames,
            isActive: true,
            totalEarned: 0,
            listedAt: block.timestamp
        });
        
        tokenToListing[shipId] = listingId;
        userListings[msg.sender].push(listingId);
        
        emit P2PListingCreated(listingId, shipId, msg.sender, pricePerGame);
    }

    /**
     * @dev Rent a player's ship
     * @param listingId P2P listing ID
     * @param gameCount Number of games to rent for
     * @param maxHours Maximum hours to hold the rental
     * @return shipId Rented ship ID
     */
    function rentPlayerShip(
        uint256 listingId, 
        uint256 gameCount,
        uint256 maxHours
    ) external nonReentrant whenNotPaused returns (uint256 shipId) {
        require(maxHours >= MIN_RENTAL_HOURS && maxHours <= MAX_RENTAL_HOURS, "Invalid time limit");
        
        P2PRentalListing storage listing = p2pListings[listingId];
        require(listing.isActive, "Listing not active");
        require(gameCount > 0 && gameCount <= listing.maxGames, "Invalid game count");
        
        uint256 totalCost = listing.pricePerGame * gameCount;
        require(battleshipToken.transferFrom(msg.sender, address(this), totalCost), "Payment failed");
        
        shipId = listing.shipId;
        
        // Transfer ship to renter
        nftManager.transferFrom(address(this), msg.sender, shipId);
        
        // Create rental record
        activeRentals[shipId] = ActiveRental({
            shipId: shipId,
            renter: msg.sender,
            owner: listing.owner,
            gamesRemaining: gameCount,
            maxHours: maxHours,
            startTime: block.timestamp,
            lastGameTime: 0,
            totalPaid: totalCost,
            pricePerGame: listing.pricePerGame,
            listingId: listingId,
            isProtocolRental: false
        });
        
        // Add to tracking
        userActiveRentals[msg.sender].push(shipId);
        allActiveRentalIds.push(shipId);
        
        // Mark listing as inactive while rented
        listing.isActive = false;
        
        emit ShipRented(msg.sender, shipId, totalCost, maxHours);
    }

    // =============================================================================
    // CLEANUP SYSTEM
    // =============================================================================

    /**
     * @dev Check if a rental is expired
     * @param shipId Ship ID to check
     * @return expired Whether the rental is expired
     * @return reason Reason for expiry
     */
    function isRentalExpired(uint256 shipId) public view returns (bool expired, string memory reason) {
        ActiveRental storage rental = activeRentals[shipId];
        if (rental.renter == address(0)) return (false, "No active rental");
        
        // Check game-based expiry
        if (rental.gamesRemaining == 0) {
            return (true, "Games exhausted");
        }
        
        // Check time-based expiry (with grace period)
        uint256 elapsed = block.timestamp - rental.startTime;
        uint256 maxTime = rental.maxHours * 1 hours + GRACE_PERIOD;
        
        if (elapsed >= maxTime) {
            return (true, "Time expired");
        }
        
        return (false, "Active");
    }

    /**
     * @dev Get all expired rental IDs
     * @return expiredIds Array of expired ship IDs
     */
    function getExpiredRentalIds() external view returns (uint256[] memory expiredIds) {
        uint256[] memory tempIds = new uint256[](allActiveRentalIds.length);
        uint256 expiredCount = 0;
        
        for (uint256 i = 0; i < allActiveRentalIds.length; i++) {
            uint256 shipId = allActiveRentalIds[i];
            (bool expired,) = isRentalExpired(shipId);
            if (expired) {
                tempIds[expiredCount] = shipId;
                expiredCount++;
            }
        }
        
        // Create properly sized array
        expiredIds = new uint256[](expiredCount);
        for (uint256 i = 0; i < expiredCount; i++) {
            expiredIds[i] = tempIds[i];
        }
    }

    /**
     * @dev Clean up expired rentals (public function with rewards)
     * @param expiredShipIds Array of expired ship IDs to clean up
     * @return totalReward Total SHIP tokens rewarded to cleaner
     */
    function cleanupExpiredRentals(uint256[] calldata expiredShipIds) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 totalReward) 
    {
        require(expiredShipIds.length > 0, "No ships provided");
        require(expiredShipIds.length <= 20, "Batch too large");
        
        uint256 successCount = 0;
        uint256 totalStakingFees = 0;
        bool isAdminCleaner = adminCleaners[msg.sender];
        
        for (uint256 i = 0; i < expiredShipIds.length; i++) {
            uint256 shipId = expiredShipIds[i];
            (bool expired, string memory reason) = isRentalExpired(shipId);
            
            if (expired) {
                uint256 stakingFee = _forceReturnRental(shipId, reason);
                totalStakingFees += stakingFee;
                successCount++;
            }
        }
        
        require(successCount > 0, "No expired rentals found");
        
        // Calculate cleanup reward (10% of staking fees for regular cleaners)
        if (!isAdminCleaner && totalStakingFees > 0) {
            totalReward = totalStakingFees * 10 / 100;
            
            // Mint reward tokens to cleaner
            battleshipToken.transfer(msg.sender, totalReward);
            
            // Update cleaner stats
            cleanerRewards[msg.sender] += totalReward;
            totalCleanupRewards += totalReward;
            
            // Send remaining 90% to staking
            uint256 stakingAmount = totalStakingFees - totalReward;
            if (stakingAmount > 0) {
                battleshipToken.transfer(address(stakingPool), stakingAmount);
                stakingPool.addRevenueToPool(stakingAmount);
            }
        } else {
            // Admin cleaner - send 100% to staking
            if (totalStakingFees > 0) {
                battleshipToken.transfer(address(stakingPool), totalStakingFees);
                stakingPool.addRevenueToPool(totalStakingFees);
            }
        }
        
        emit RentalCleaned(0, msg.sender, totalReward, isAdminCleaner); // shipId=0 for batch
    }

    /**
     * @dev Internal function to force return a rental
     * @param shipId Ship ID to return
     * @param reason Reason for return
     * @return stakingFee Amount that should go to staking pool
     */
    function _forceReturnRental(uint256 shipId, string memory reason) internal returns (uint256 stakingFee) {
        ActiveRental storage rental = activeRentals[shipId];
        
        if (rental.isProtocolRental) {
            // Burn protocol rental ship
            nftManager.burn(shipId);
            stakingFee = rental.totalPaid; // Protocol rental fees go to staking
        } else {
            // Return P2P rental ship to owner
            nftManager.transferFrom(rental.renter, rental.owner, shipId);
            
            // Calculate revenue split for P2P rental
            uint256 totalRevenue = rental.totalPaid;
            uint256 marketplaceFee = totalRevenue * MARKETPLACE_FEE_PERCENTAGE / 10000; // 2.5%
            uint256 ownerPayment = totalRevenue - marketplaceFee;
            
            // Pay owner (85% after marketplace fee)
            battleshipToken.transfer(rental.owner, ownerPayment);
            
            // Marketplace fee goes to staking
            stakingFee = marketplaceFee;
            
            // Reactivate P2P listing
            if (rental.listingId > 0) {
                p2pListings[rental.listingId].isActive = true;
            }
        }
        
        // Clean up tracking
        _removeFromActiveRentals(shipId);
        
        emit ShipReturned(shipId, rental.renter, reason);
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    /**
     * @dev Set admin cleaner status
     * @param cleaner Address to update
     * @param isAdmin Whether address is an admin cleaner
     */
    function setAdminCleaner(address cleaner, bool isAdmin) external onlyOwner {
        adminCleaners[cleaner] = isAdmin;
        emit AdminCleanerUpdated(cleaner, isAdmin);
    }

    /**
     * @dev Set protocol rental configuration
     * @param shipType Ship type to configure
     * @param price Price per game in SHIP tokens
     * @param isActive Whether ship type is available for rental
     */
    function setProtocolRentalConfig(
        ShipType shipType, 
        uint256 price, 
        bool isActive
    ) external onlyOwner {
        protocolRentals[shipType] = ProtocolRentalConfig({
            price: price,
            isActive: isActive,
            promoMultiplier: 100 // 100 = normal price
        });
        
        emit ProtocolRentalConfigUpdated(shipType, price, isActive);
    }

    /**
     * @dev Set fleet rental discount percentage
     * @param discountPercent Discount percentage (10 = 10% discount)
     */
    function setFleetDiscount(uint256 discountPercent) external onlyOwner {
        require(discountPercent <= 50, "Discount too high");
        fleetDiscount = discountPercent;
    }

    /**
     * @dev Emergency return rental (admin only)
     * @param shipId Ship ID to return
     */
    function emergencyReturnRental(uint256 shipId) external onlyOwner {
        (bool expired,) = isRentalExpired(shipId);
        require(expired || activeRentals[shipId].renter != address(0), "No active rental");
        
        _forceReturnRental(shipId, "Emergency admin return");
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get protocol rental price for a ship type
     * @param shipType Ship type
     * @return price Price per game
     */
    function getProtocolRentalPrice(ShipType shipType) external view returns (uint256 price) {
        return _getProtocolRentalPrice(shipType);
    }

    /**
     * @dev Check if a ship is currently rented
     * @param shipId Ship ID to check
     * @return isRented Whether ship is currently rented
     */
    function isActiveRental(uint256 shipId) external view returns (bool isRented) {
        return activeRentals[shipId].renter != address(0);
    }

    /**
     * @dev Get user's active rentals
     * @param user User address
     * @return shipIds Array of ship IDs currently rented by user
     */
    function getUserActiveRentals(address user) external view returns (uint256[] memory shipIds) {
        return userActiveRentals[user];
    }

    // =============================================================================
    // INTERNAL HELPER FUNCTIONS
    // =============================================================================

    /**
     * @dev Calculate fleet rental cost with discount
     * @return totalCost Total cost for full fleet rental
     */
    function _calculateFleetRentalCost() internal view returns (uint256 totalCost) {
        totalCost = _getProtocolRentalPrice(ShipType.DESTROYER) +
                    _getProtocolRentalPrice(ShipType.SUBMARINE) +
                    _getProtocolRentalPrice(ShipType.CRUISER) +
                    _getProtocolRentalPrice(ShipType.BATTLESHIP) +
                    _getProtocolRentalPrice(ShipType.CARRIER);
        
        // Apply fleet discount
        if (fleetDiscount > 0) {
            totalCost = totalCost * (100 - fleetDiscount) / 100;
        }
    }

    /**
     * @dev Get protocol rental price with promo multiplier
     * @param shipType Ship type
     * @return price Effective price per game
     */
    function _getProtocolRentalPrice(ShipType shipType) internal view returns (uint256 price) {
        ProtocolRentalConfig storage config = protocolRentals[shipType];
        price = config.price * config.promoMultiplier / 100;
    }

    /**
     * @dev Remove ship from active rental tracking
     * @param shipId Ship ID to remove
     */
    function _removeFromActiveRentals(uint256 shipId) internal {
        ActiveRental storage rental = activeRentals[shipId];
        address renter = rental.renter;
        
        // Remove from user's active rentals
        uint256[] storage userRentals = userActiveRentals[renter];
        for (uint256 i = 0; i < userRentals.length; i++) {
            if (userRentals[i] == shipId) {
                userRentals[i] = userRentals[userRentals.length - 1];
                userRentals.pop();
                break;
            }
        }
        
        // Remove from global active rentals
        for (uint256 i = 0; i < allActiveRentalIds.length; i++) {
            if (allActiveRentalIds[i] == shipId) {
                allActiveRentalIds[i] = allActiveRentalIds[allActiveRentalIds.length - 1];
                allActiveRentalIds.pop();
                break;
            }
        }
        
        // Clear rental record
        delete activeRentals[shipId];
    }
} 