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
  address public withdrawWallet;
  uint public minimumBidValue = 0.1 ether;

  uint public constant MAX_SUPPLY = 1000;
  uint public constant INIT_BLOCK_TIME = 2000000000;
  uint public constant START_BID = 2000000010;
  uint public constant START_BUY_MORE = 2000000020;
  uint public constant START_FUND = 2000000030;
  uint public constant END_FUND = 2000000040;
  string public constant METADATA = "ipfs://QmPmigL4qmQTxFxXw5NysNjiuw2qd9VneTVW1KydmAT1pE";

  function setUp() public {
    user1 = vm.addr(1);
    user2 = vm.addr(2);
    user3 = vm.addr(3);
    withdrawWallet = vm.addr(4);

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

    vm.deal(user1, minimumBidValue);
    vm.deal(user2, minimumBidValue);
  }

  function testBid() public {
    vm.startPrank(user1);
    boi.setMinimumContribution(minimumBidValue);
    vm.stopPrank();

    vm.warp(START_BID + 5);
    vm.startPrank(user1);
    boi.bid{value: minimumBidValue}();
    vm.stopPrank();

    (    
      uint contribution,
      uint32 tokensClaimed,
      bool refundClaimed,
      bool bidder
    ) = boi.userData(user1);

    uint totalBidAmount = boi.totalBidAmount();

    assertEq(contribution, minimumBidValue);
    assertEq(tokensClaimed, 0);
    assertFalse(refundClaimed);
    assertTrue(bidder);
    assertEq(totalBidAmount, minimumBidValue);
  }

  function testOnlyAdmin() public {
    vm.expectRevert("only admin");
    boi.setMinimumContribution(minimumBidValue);
  }

  function testBidNotAllowed() public {
    vm.warp(START_BUY_MORE);
    vm.prank(user2);
    vm.expectRevert("bid not allowed");
    boi.bid{value: minimumBidValue}();
  }
}
