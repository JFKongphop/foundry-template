// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/BOI.sol";

contract DeployMyContract is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
  
    BOI myContract = new BOI(
      payable(address(0xd73F821fcA522Cbb672F8354d25470DBf4948c9C)),
      0,
      0,
      0,
      0,
      0,
      "ipfs://QmPmigL4qmQTxFxXw5NysNjiuw2qd9VneTVW1KydmAT1pE"
    );

    console.log("Deployed MyContract at:", address(myContract));
    
    vm.stopBroadcast();
  }
}
