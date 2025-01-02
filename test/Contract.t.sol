// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Contract.sol";
import { console } from "forge-std/console.sol";

contract ContractTest is Test {
  Contract public ct;

  function setUp() public {
    address admin = vm.addr(1);

    ct = new Contract(admin);
  }

  function testAdmin() public view {
    console.log(ct.admin());
  }
}
