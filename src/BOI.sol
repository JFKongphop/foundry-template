// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BOI is ERC1155, ReentrancyGuard {  
  uint public MAX_SUPPLY;
  uint public SELL_SUPPLY;
  uint public remainderSupply;
  uint public minimumContribution = 0.005 ether;
  uint public startBid;
  uint public startBuyMore;
  uint public startFund;
  uint public endFund;
  uint public price;
  uint public totalBidAmount;
  uint public totalMinted;
  uint public balanceEndFunding; 
  uint public refundPool;
  address payable public immutable withdrawAddress;

  address private admin;
  string private baseTokenURI;
  uint private tokenId;

  struct User {
    uint contribution;
    uint32 tokensClaimed;
    bool refundClaimed;
    bool bidder;
  }

  mapping(address => User) public userData;

  event Bid(address indexed user, uint amount);
  event Claim(address indexed user, uint amount, uint refund);
  event Buy(address indexed user, uint tokenId, uint amount);
  event Burn(address indexed user, uint tokenId, uint amount, uint refund);

  constructor(
    address payable _withdrawAddress,
    uint _maxSupply,
    uint _startBid,
    uint _startBuyMore,
    uint _startFund,
    uint _endFund,
    string memory _baseTokenURI
  ) ERC1155(_baseTokenURI) {
    require(_withdrawAddress != address(0));
    withdrawAddress = _withdrawAddress;
    admin = msg.sender;

    MAX_SUPPLY = _maxSupply;
    
    startBid = _startBid;
    startBuyMore = _startBuyMore;
    startFund = _startFund;
    endFund = _endFund;
    baseTokenURI = _baseTokenURI;
  }

  modifier initialBoi() {
    require(block.timestamp < startBid, "setup not allowed");
    _;
  }

  modifier isAdmin() {
    require(msg.sender == admin, "only admin");
    _;
  }

  modifier isBidder() {
    User storage user = userData[msg.sender];
    require(user.bidder == true, "only bidder");
    _;
  }

  modifier onBidTime() {
    uint currentTime = block.timestamp;
    require(currentTime > startBid && currentTime < startBuyMore, "bid not allowed");
    _;
  }

  modifier onBuyMoreTime() {
    uint currentTime = block.timestamp;
    require(currentTime > startBuyMore && currentTime < startFund, "buy more not allowed");
    _;
  }

  modifier endFundTime() {
    uint currentTime = block.timestamp;
    require(currentTime > endFund, "burn not allowed");
    _;
  }

  /***** DEVELOPMENT FUNCTION ONLY DELETE BEFORE DEPLOY *****/
  function timeSetUpForDevOnly(
    uint _startBid,
    uint _startBuyMore,
    uint _startFund,
    uint _endFund
  ) public isAdmin {
    if (_startBid != 0) {
      startBid = _startBid;
    }

    if (_startBuyMore != 0) {
      startBuyMore = _startBuyMore;
    }

    if (_startFund != 0) {
      startFund = _startFund;
    }

    if (_startFund != 0) {
      startFund = _startFund;
    }

    if (_endFund != 0) {
      endFund = _endFund;
    }
  }

  /***** PUBLIC FUNCTION *****/
  /**
   * @notice receive eth and join funding.
  */
  function bid() external payable onBidTime {
    User storage user = userData[msg.sender];
    uint contribution = user.contribution;
    contribution += msg.value;

    require(contribution >= minimumContribution, "Lower bid");
    totalBidAmount += msg.value;

    user.contribution = contribution;

    if (!user.bidder) {
      user.bidder = true;
    }

    emit Bid(msg.sender, msg.value);
  }

  /**
   * @notice set minimum contribution for bid.
   * @param contribution minimum contribution.
  */
  function setMinimumContribution(uint contribution) external isAdmin initialBoi {
    minimumContribution = contribution;
  }

  /**
   * @notice set nft price and remain supply after nid end.
   * @param nftPrice nft price.
   * @param remainSupply remainder supply after bid.
  */
  function setPriceAndSupply(
    uint nftPrice, 
    uint remainSupply
  ) external isAdmin {
    uint currentTime = block.timestamp;
    require(currentTime > startBuyMore && currentTime < startFund, "set price and supply not allowed");
    require(nftPrice > 0, "price is not zero");

    price = nftPrice;

    if (remainSupply != 0) {
      SELL_SUPPLY = remainSupply;
      remainderSupply = remainSupply;
    }

    refundPool = price * remainSupply;
  }

  /**
   * @notice get amount purchased of your own.
   * @return amount amount token
  */
  function amountPurchased() public view returns (uint amount) {
    require(price != 0, "Price failed");
    amount = userData[msg.sender].contribution / price;
  }

  /**
   * @notice get refund amount of your own.
   * @return refund refund amount
  */
  function refundAmount() public view returns (uint refund) {
    require(price != 0, "Price failed");
    refund = userData[msg.sender].contribution % price;
  }

  /**
   * @notice get remainder claim token of your own.
   * @return remainedToken remainder claim token
  */
  function remainedAmount() public view returns (uint remainedToken) {
    address userAddress = msg.sender;
    User storage user = userData[userAddress];
    uint tokensClaimed = user.tokensClaimed;
    uint totalToken = amountPurchased();

    remainedToken = totalToken - tokensClaimed;
  }

  /** 
   * @notice claim token from bid amount and refund of bid remained.
  */
  function sendTokensAndRefund() external isBidder nonReentrant {
    require(price != 0, "Price failed");

    address userAddress = msg.sender;
    User storage user = userData[userAddress];

    uint refundValue = refundAmount();
    if (refundValue > 0) {
      user.contribution -= refundValue;
      user.refundClaimed = true;
      refundPool -= refundValue;
      (bool success, ) = userAddress.call{value: refundValue}("");
      require(success, "Refund failed.");
    }

    uint amount = remainedAmount();
    user.tokensClaimed = uint32(amount);
    _internalMint(userAddress, amount);

    emit Claim(userAddress, amount, refundValue);  
  }

  /**
   * @notice buy more token after bid only who bid before.
   * @param amount amount of token to buy more.
  */
  function buyToken(uint amount) external payable isBidder onBuyMoreTime nonReentrant {
    require(price > 0, "cannot buy");
    require(remainderSupply >= amount, "Insufficient tokens available for purchase");
    uint userValue = msg.value;
    require(userValue == price * amount, "buy failed");
    
    uint remainedToken = remainedAmount();
    require(remainedToken == 0, 'Must claim all your tokens');

    remainderSupply -= amount;

    address userAddress = msg.sender;
    User storage user = userData[userAddress];
    user.tokensClaimed += uint32(amount);
    user.contribution += userValue;
    _internalMint(userAddress, amount);

    emit Buy(msg.sender, tokenId, amount);
  }

  /**
   * @notice get tokenId ownership.
   * @return ownershipTokenId array of own token id.
  */
  function checkOwnership() public view returns (uint[] memory) {
    uint ownedCount = 0;

    for (uint i = 1; i <= tokenId; i++) {
      if (balanceOf(msg.sender, i) > 0) {
        ownedCount++;
      }
    }

    uint[] memory ownership = new uint[](ownedCount);
    uint index = 0;

    for (uint i = 1; i <= tokenId; i++) {
      if (balanceOf(msg.sender, i) > 0) {
        ownership[index] = i;
        index++;
      }
    }

    return ownership;
  }

  /**
   * @notice total refund own.
   * @param amount amount of token to burn.
   * @return totalRefund refund own after funding.
  */
  function burnRefundAmount(uint amount) external view endFundTime returns (uint totalRefund) {
    uint refundRatio = (amount * 1e18) / MAX_SUPPLY;
    totalRefund = (balanceEndFunding * refundRatio) / 1e18;
  }

  /**
   * @notice burn a token you own.
   * @param id token ID to burn.
   * @param amount amount of token to burn.
  */
  function burnTokenAndRefund(
    uint id,
    uint amount
  )
    external
    isBidder
    endFundTime
    nonReentrant
  {
    address userAddress = msg.sender;
    require(balanceOf(userAddress, id) >= amount, "burn token exceeds balance");

    _burn(userAddress, id, amount);

    uint refundRatio = (amount * 1e18) / MAX_SUPPLY;
    uint totalRefund = (balanceEndFunding * refundRatio) / 1e18;

    (bool success, ) = userAddress.call{value: totalRefund}("");
    require(success, "Transfer failed.");

    emit Burn(userAddress, id, amount, totalRefund);
  }

  /**
   * @notice deposit after fund end.
  */
  function depositETH() public payable isAdmin {
    uint depositValue = msg.value;
    require(depositValue > 0, "Must send ETH to deposit");
    balanceEndFunding += depositValue;
  }

  /**
   * @notice withdraw all eth balance.
  */
  function withdraw() external isAdmin  {
    require(price > 0, 'price is zero');

    uint withdrawEth = address(this).balance - refundPool;
    (bool success, ) = withdrawAddress.call{value: withdrawEth}("");
    require(success, "Transfer failed.");
  }

  /**
   * @notice withdraw eth balance.
   * @param amountWithdraw eth balance for withdraw.
  */
  function withdrawAmount(uint amountWithdraw) external isAdmin {
    require(price > 0, 'price is zero');
    uint withdrawEth = address(this).balance - refundPool;
    require(withdrawEth >= amountWithdraw, "withdraw exceed refund pool");

    (bool success, ) = withdrawAddress.call{value: amountWithdraw}("");
    require(success, "Transfer failed.");
  }

  ////////////////
  //   tokens   //
  ////////////////
  /**
   * @notice get token uri.
  */
  function uri(uint) public view override returns (string memory) {
    return baseTokenURI;
  }

  /**
   * @notice set new base uri of nft.
   * @param baseURI ipfs uri.
  */
  function setBaseURI(string calldata baseURI) external isAdmin {
    baseTokenURI = baseURI;
  }

  /***** PRIVATE FUNCTION *****/ 
  /**
   * @dev handles all minting.
   * @param to address to mint tokens to.
   * @param amount number of tokens to mint.
  */
  function _internalMint(
    address to, 
    uint amount
  ) internal {
    tokenId++;
    _mint(to, tokenId, amount, "");
    totalMinted += amount;
  }
}