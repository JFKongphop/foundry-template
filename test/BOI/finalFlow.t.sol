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
  uint[5] bidAmounts = [50 ether, 60 ether, 40 ether, 25 ether, 30 ether];

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

    for (uint i = 0; i < 5; i++) {
      vm.deal(users[i], initBalance);
    }
  }

  function testFinalFlow() public {
    vm.expectRevert("only admin");
    boi.setMinimumContribution(minimumBidValue);

    vm.startPrank(user1);
    boi.setMinimumContribution(minimumBidValue);
    vm.stopPrank();
    
    vm.warp(START_BID + 5);

    vm.startPrank(user1);
    vm.expectRevert("setup not allowed");
    boi.setMinimumContribution(minimumBidValue);
    vm.stopPrank();

    vm.startPrank(user1);
    vm.expectRevert("Lower bid");
    boi.bid{value: 0}();
    vm.stopPrank();

    vm.recordLogs();

    for (uint i = 0; i < 5; i++) {
      address user = users[i];
      uint bidAmount = bidAmounts[i];

      vm.startPrank(user);
      boi.bid{value: bidAmount}();
      vm.stopPrank();

      (
        uint contribution,
        uint32 tokensClaimed,
        bool refundClaimed,
        bool bidder
      ) = boi.userData(user);

      assertEq(contribution, bidAmount);
      assertEq(tokensClaimed, 0);
      assertFalse(refundClaimed);
      assertTrue(bidder);
    }

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

    uint avgNFTPrice = totalBidAmount / maxSupply;
    uint remainderSupply = maxSupply - totalNFTCanClaim;

    vm.startPrank(user1);

    vm.expectRevert("Price failed");
    boi.sendTokensAndRefund();

    vm.expectRevert("set price and supply not allowed");
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);
    
    vm.expectRevert("buy more not allowed");
    boi.buyToken(1);

    vm.stopPrank();
  
    vm.expectRevert("only admin");
    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);

    vm.warp(START_BUY_MORE + 5);

    vm.startPrank(user1);
    vm.expectRevert("price is not zero");
    boi.setPriceAndSupply(0, remainderSupply);

    vm.expectRevert("cannot buy");
    boi.buyToken(1);

    vm.expectRevert("price is zero");
    boi.withdraw();

    vm.expectRevert("price is zero");
    boi.withdrawAmount(1);

    boi.setPriceAndSupply(avgNFTPrice, remainderSupply);

    vm.stopPrank();

    uint price = boi.price();
    uint initSellSupply = boi.SELL_SUPPLY();

    assertEq(price, avgNFTPrice);
    assertEq(initSellSupply, remainderSupply);

    for (uint i = 0; i < 5; i++) {
      address user = users[i];
      uint bidAmount = bidAmounts[i];

      vm.startPrank(user);
      uint refundAmount = boi.refundAmount();
      vm.stopPrank();
      
      User memory userBid = bids[user];
      uint tokenCanClaim = userBid.token;
      uint roundedBidAmount =  tokenCanClaim * avgNFTPrice;
      uint expectRefundAmount = bidAmount - roundedBidAmount;
      
      assertEq(refundAmount, expectRefundAmount);
    }

    vm.expectRevert("only bidder");
    boi.sendTokensAndRefund();

    vm.startPrank(user1);
    vm.expectRevert("Must claim all your tokens");
    boi.buyToken{value: avgNFTPrice}(1);

    boi.withdraw();

    uint refundPool = boi.refundPool();
    uint expectWithdrawAmount = totalBidAmount - totalRefund;

    assertEq(address(boi).balance, refundPool);
    assertEq(address(withdrawWallet).balance, expectWithdrawAmount);

    vm.stopPrank();

    uint expectTotalMinted = 0;
    for (uint i = 0; i < 5; i++) {
      address user = users[i];

      vm.startPrank(user);

      uint amountPurchased = boi.amountPurchased();
      expectTotalMinted += amountPurchased;

      boi.sendTokensAndRefund();

      uint refundAmount = boi.refundAmount();
      uint refundPoolAfter = boi.refundPool();
      uint totalMinted = boi.totalMinted();
      uint[] memory tokenIdsOwnership = boi.checkOwnership();
      uint tokenId = tokenIdsOwnership[0];
      uint userTokenIdBalance = boi.balanceOf(user, tokenId);

      (
        uint contribution,
        uint32 tokensClaimed,
        bool refundClaimed,
        bool bidder
      ) = boi.userData(user);

      vm.stopPrank();

      assertEq(address(boi).balance, refundPoolAfter);
      assertEq(contribution, amountPurchased * avgNFTPrice);
      assertEq(tokensClaimed, amountPurchased);
      assertTrue(refundClaimed);
      assertTrue(bidder);
      assertEq(refundAmount, 0);
      assertEq(totalMinted, expectTotalMinted);
      assertEq(tokenId, i + 1);
      assertEq(userTokenIdBalance, tokensClaimed);
    }

    vm.expectRevert("only bidder");
    boi.buyToken{value: avgNFTPrice}(1);

    vm.startPrank(user1);
    
    vm.expectRevert("Insufficient tokens available for purchase");
    uint buyTokenOverSupplyAmount = 4;
    boi.buyToken{value: buyTokenOverSupplyAmount * avgNFTPrice}(buyTokenOverSupplyAmount);

    vm.expectRevert("buy failed");
    boi.buyToken{value: 3 * avgNFTPrice}(2);

    uint supplyBeforeUser1Buy = boi.remainderSupply();
    uint buyTokenUser1Amount = 1;
    uint ethBuyTokenUser1Amount = buyTokenUser1Amount * avgNFTPrice;

    (
      uint contributionUser1BeforeBuyToken,
      uint32 tokensClaimedUser1BeforeBuyToken
      ,,
    ) = boi.userData(user1); 

    boi.buyToken{value: ethBuyTokenUser1Amount}(buyTokenUser1Amount);

    uint supplyAftereUser1Buy = boi.remainderSupply();
    (
      uint contributionUser1AfterBuyToken,
      uint32 tokensClaimedUser1AfterBuyToken
      ,,
    ) = boi.userData(user1);       
    uint[] memory user1TokenIdsOwnership = boi.checkOwnership();
    uint user1TokenIdAfterBuyToken = user1TokenIdsOwnership[1];
    uint user1TokenIdBalanceAfterBuyToken = boi.balanceOf(user1, user1TokenIdAfterBuyToken);

    assertEq(
      supplyAftereUser1Buy, 
      supplyBeforeUser1Buy - buyTokenUser1Amount
    );
    assertEq(
      contributionUser1AfterBuyToken, 
      contributionUser1BeforeBuyToken + ethBuyTokenUser1Amount
    );
    assertEq(
      tokensClaimedUser1AfterBuyToken,
      tokensClaimedUser1BeforeBuyToken + buyTokenUser1Amount
    );
    assertEq(user1TokenIdAfterBuyToken, 6);
    assertEq(user1TokenIdBalanceAfterBuyToken, buyTokenUser1Amount);
    assertEq(address(boi).balance, ethBuyTokenUser1Amount);

    vm.stopPrank();

    vm.expectRevert("only admin");
    boi.withdraw();

    vm.startPrank(user1);
    boi.withdraw();
    vm.stopPrank();

    uint totalTokenClaimed = boi.MAX_SUPPLY() - supplyAftereUser1Buy;
    uint expectWithdrawWalletBalanceAfterBuyToken = totalTokenClaimed * avgNFTPrice;

    assertEq(address(withdrawWallet).balance, expectWithdrawWalletBalanceAfterBuyToken);
    assertEq(address(boi).balance, 0);

    vm.expectRevert("only admin");
    boi.depositETH{value: 0}();

    vm.startPrank(user1);
    vm.deal(user1, initBalance);
    boi.depositETH{value: initBalance}();
    vm.stopPrank();

    assertEq(address(boi).balance, initBalance);

    vm.expectRevert("only bidder");
    boi.burnTokenAndRefund(6, 1);

    vm.startPrank(user1);
    vm.expectRevert("burn not allowed");
    boi.burnTokenAndRefund(6, 1);

    vm.warp(END_FUND + 5);
    vm.expectRevert("burn token exceeds balance");
    boi.burnTokenAndRefund(6, 2);

    for (uint i = 0; i < 5; i++) {
      address user = users[i];

      vm.deal(user, 0);
      assertEq(address(user).balance, 0);

      vm.startPrank(user);

      (,uint32 tokensClaimed,,) = boi.userData(user); 
      uint burnRefundAmount = boi.burnRefundAmount(tokensClaimed);

      assertEq(burnRefundAmount / 1e17, tokensClaimed);

      uint[] memory ownTokenIdsBeforeBurn = boi.checkOwnership();
      uint ownTokenIdsBeforeBurnLenght = ownTokenIdsBeforeBurn.length;

      uint expectTokensClaimed = 0;
      for (uint j = 0; j < ownTokenIdsBeforeBurnLenght; j++) {
        uint tokenId = ownTokenIdsBeforeBurn[j];
        uint tokenIdBalanceBefore = boi.balanceOf(user, tokenId);
        expectTokensClaimed += tokenIdBalanceBefore;

        boi.burnTokenAndRefund(tokenId, tokenIdBalanceBefore);

        uint tokenIdBalanceafter = boi.balanceOf(user, tokenId);

        assertEq(tokenIdBalanceafter, 0);
      }

      assertEq(tokensClaimed, expectTokensClaimed);
      assertEq(address(user).balance, burnRefundAmount);

      vm.stopPrank();
    }

    uint expectTokenBalanceAfterBurnAll = initBalance - totalTokenClaimed * 1e17;
    assertEq(address(boi).balance, expectTokenBalanceAfterBurnAll);
  }
}
