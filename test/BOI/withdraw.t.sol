// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/BOI.sol";
import { console } from "forge-std/console.sol";

contract BOITest is Test {
  BOI public boi;
  address public user1;
  address public user2;
  address public user3;
  address public user4;
  address public user5;
  address public withdrawWallet;
  uint public minimumBidValue = 0.1 ether;
  uint public initBalance = 100 ether;
  uint totalRefund = 0;
  address[5] users; 

  uint public constant MAX_SUPPLY = 1000;
  uint public constant INIT_BLOCK_TIME = 2000000000;
  uint public constant START_BID = 2000000010;
  uint public constant START_BUY_MORE = 2000000020;
  uint public constant START_FUND = 2000000030;
  uint public constant END_FUND = 2000000040;
  string public constant METADATA = "ipfs://QmPmigL4qmQTxFxXw5NysNjiuw2qd9VneTVW1KydmAT1pE";

  struct User {
    uint amount;
    uint token;
  }

  mapping(address => User) bids;

  uint avgNFTPrice;
  uint remainderSupply;

  function setUp() public {
    user1 = vm.addr(1);
    user2 = vm.addr(2);
    user3 = vm.addr(3);
    user4 = vm.addr(4);
    user5 = vm.addr(5);
    withdrawWallet = vm.addr(6);

    users = [user1, user2, user3, user4, user5];

    vm.warp(INIT_BLOCK_TIME);
    vm.prank(user1);

    boi = new BOI(
      payable(withdrawWallet),
      MAX_SUPPLY,
      START_BID,
      START_BUY_MORE,
      START_FUND,
      END_FUND,
      METADATA
    );

    vm.deal(user1, initBalance);
    vm.deal(user2, initBalance);
    vm.deal(user3, initBalance);
    vm.deal(user4, initBalance);
    vm.deal(user5, initBalance);

    vm.startPrank(user1);
    boi.setMinimumContribution(minimumBidValue);
    vm.stopPrank();
    
    vm.warp(START_BID + 5);

    vm.recordLogs();

    vm.startPrank(user1);
    boi.bid{value: 50 ether}();
    vm.stopPrank();

    vm.startPrank(user2);
    boi.bid{value: 60 ether}();
    vm.stopPrank();

    vm.startPrank(user3);
    boi.bid{value: 40 ether}();
    vm.stopPrank();

    vm.startPrank(user4);
    boi.bid{value: 25 ether}();
    vm.stopPrank();

    vm.startPrank(user5);
    boi.bid{value: 30 ether}();
    vm.stopPrank();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    uint totalBidAmount = boi.totalBidAmount();
    uint totalNFTCanClaim = 0;
    uint maxSupply = boi.MAX_SUPPLY();
    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].topics[0] == keccak256("Bid(address,uint256)")) {
        uint256 amount = abi.decode(logs[i].data, (uint256));    
        address bidder = address(uint160(uint256(logs[i].topics[1])));
        uint256 nftEachAddressCanClaimed = (amount * 1000) / totalBidAmount;

        User storage user = bids[bidder];
        user.amount = amount;
        user.token = nftEachAddressCanClaimed;

        (uint contribution,,,) = boi.userData(users[i]);

        totalRefund += contribution - (nftEachAddressCanClaimed * (totalBidAmount / maxSupply)); 
        totalNFTCanClaim += nftEachAddressCanClaimed;
      }
    }

    avgNFTPrice = totalBidAmount / maxSupply;
    remainderSupply = maxSupply - totalNFTCanClaim;
  }

  function testOnlyAdmin() public {
    vm.expectRevert("only admin");
    boi.withdraw();
  }

  function testPriceIsZero() public {
    vm.startPrank(user1);
    vm.expectRevert("price is zero");
    boi.withdraw();
    vm.stopPrank();
  }

  function testUser1Withdraw() public {
    vm.warp(START_BUY_MORE + 5);
    vm.startPrank(user1);
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);
    boi.sendTokensAndRefund();
    boi.withdraw();

    uint refundAmount = boi.refundAmount();
    uint refundPool = boi.refundPool();

    vm.stopPrank();

    assertEq(refundAmount, 0);
    assertEq(refundPool, address(boi).balance);    
  }

  function testWithdrawWithoutSendTokenAndRefund() public {
    vm.warp(START_BUY_MORE + 5);
    vm.startPrank(user1);
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);
    boi.withdraw();
    vm.stopPrank();

    uint refundPool = boi.refundPool();
    uint totalBidAmount = boi.totalBidAmount();
    uint totalWithdrawAmount = totalBidAmount - refundPool;

    assertEq(refundPool, totalRefund);
    assertEq(address(boi).balance, totalRefund);
    assertEq(address(withdrawWallet).balance, totalWithdrawAmount);
  }

  function testWithdrawAll() public {
    vm.warp(START_BUY_MORE + 5);
    vm.startPrank(user1);
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);
    vm.stopPrank();

    uint userLength = users.length;
    for (uint i = 0; i < userLength; i++) {
      address user = users[i];
      vm.startPrank(user);
      boi.sendTokensAndRefund();
      vm.stopPrank();
    }

    vm.startPrank(user1);
    boi.withdraw();
    vm.stopPrank();

    uint refundPool = boi.refundPool();
    assertEq(refundPool, 0);
    assertEq(address(boi).balance, 0);
  }

  function testWithdrawAfterBuyToken() public {
    vm.warp(START_BUY_MORE + 5);
    vm.startPrank(user1);
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);
    vm.stopPrank();

    uint userLength = users.length;
    for (uint i = 0; i < userLength; i++) {
      address user = users[i];
      vm.startPrank(user);
      boi.sendTokensAndRefund();
      vm.stopPrank();
    }

    vm.startPrank(user1);
    boi.withdraw();

    uint totalBidAmount = boi.totalBidAmount();
    uint refundPool = boi.refundPool();
    uint expectWithdrawWalletBalance = totalBidAmount - totalRefund;

    assertEq(refundPool, 0);
    assertEq(address(boi).balance, 0);
    assertEq(address(withdrawWallet).balance, expectWithdrawWalletBalance);

    boi.buyToken{value: avgNFTPrice}(1);

    assertEq(address(boi).balance, avgNFTPrice);
    
    boi.withdraw();

    assertEq(address(boi).balance, 0);
    assertEq(address(withdrawWallet).balance, expectWithdrawWalletBalance + avgNFTPrice);

    vm.stopPrank();
  }
}
