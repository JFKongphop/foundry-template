// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Contract is ReentrancyGuard {  
  address admin;

  constructor(address _admin) {
    admin = _admin;
  }
}