// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Contract.sol";

contract DeployMyContract is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployerAddress = vm.addr(deployerPrivateKey);

    vm.startBroadcast(deployerPrivateKey);
  
    Contract myContract = new Contract(deployerAddress);

    console.log("Deployed MyContract at:", address(myContract));
    
    vm.stopBroadcast();
  }
}
