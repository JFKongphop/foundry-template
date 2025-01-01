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

  uint public constant MAX_SUPPLY = 1000;
  uint public constant INIT_BLOCK_TIME = 2000000000;
  uint public constant START_BID = 2000000010;
  uint public constant START_BUY_MORE = 2000000020;
  uint public constant START_FUND = 2000000030;
  uint public constant END_FUND = 2000000040;
  string public constant METADATA = "ipfs://QmPmigL4qmQTxFxXw5NysNjiuw2qd9VneTVW1KydmAT1pE";

  mapping(address => uint) bids;

  function setUp() public {
    user1 = vm.addr(1);
    user2 = vm.addr(2);
    user3 = vm.addr(3);
    user4 = vm.addr(4);
    user5 = vm.addr(5);
    withdrawWallet = vm.addr(6);

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
  }

  function testBidEventLog() public {
    Vm.Log[] memory logs = vm.getRecordedLogs();
    uint expectTotalAmount = 0;

    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].topics[0] == keccak256("Bid(address,uint256)")) {
        address bidder = address(uint160(uint256(logs[i].topics[1])));
        uint256 amount = abi.decode(logs[i].data, (uint256));
        expectTotalAmount += amount;
        bids[bidder] = amount;
      }
    }

    uint totalBidAmount = boi.totalBidAmount();

    assertEq(totalBidAmount, expectTotalAmount);
  }

  function testRemainderAndPriceNFT() public {
    Vm.Log[] memory logs = vm.getRecordedLogs();
    uint totalBidAmount = boi.totalBidAmount();
    uint totalNFTCanClaim = 0;
    uint maxSupply = boi.MAX_SUPPLY();
    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].topics[0] == keccak256("Bid(address,uint256)")) {
        uint256 amount = abi.decode(logs[i].data, (uint256));    
        uint256 nftEachAddressCanClaimed = (amount * 1000) / totalBidAmount;

        totalNFTCanClaim += nftEachAddressCanClaimed;
      }
    }

    uint avgNFTPrice = totalBidAmount / maxSupply;
    uint remainderSupply = maxSupply - totalNFTCanClaim;
    
    vm.warp(START_BUY_MORE + 5);

    vm.startPrank(user1);
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);
    vm.stopPrank();

    uint price = boi.price();
    uint sellSupply = boi.SELL_SUPPLY();

    assertEq(price, avgNFTPrice);
    assertEq(sellSupply, remainderSupply);
  }

  function testOnlyAdmin() public {
    vm.expectRevert("only admin");
    boi.setPriceAndSupply(0, 0);
  }

  function testSetPriceAndSupplyNotAllowed() public {
    vm.startPrank(user1);
    vm.expectRevert("set price and supply not allowed");
    boi.setPriceAndSupply(0, 0);
  }
}
