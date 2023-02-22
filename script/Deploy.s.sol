// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script, console2 } from "forge-std/Script.sol";
import { CounterFacts } from "../src/CounterFacts.sol";

contract Deploy is Script {
    function run() public {
        uint256 key = vm.envUint("DEPLOYER_KEY");

        address deployer = vm.rememberKey(key);

        string[] memory networks = vm.envString("NETWORKS", ",");
        for (uint256 i; i < networks.length; i++) {
            string memory network = networks[i];
            vm.createSelectFork(getChain(network).rpcUrl);
            vm.broadcast(deployer);
            address facts = address(new CounterFacts());
            console2.log("Deployed CounterFacts to", facts);
        }
    }
}
