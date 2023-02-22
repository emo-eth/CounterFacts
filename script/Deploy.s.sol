// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script, console2 } from "forge-std/Script.sol";
import { CounterFacts } from "../src/CounterFacts.sol";
import { BaseCreate2Script } from "create2-scripts/BaseCreate2Script.s.sol";

contract Deploy is BaseCreate2Script {
    function run() public {
        uint256 key = vm.envUint("DEPLOYER_KEY");

        deployer = vm.rememberKey(key);

        string[] memory networks = vm.envString("NETWORKS", ",");
        for (uint256 i; i < networks.length; i++) {
            string memory network = networks[i];
            vm.createSelectFork(getChain(network).rpcUrl);
            address facts = _immutableCreate2IfNotDeployed(
                deployer, bytes32(0), type(CounterFacts).creationCode
            );
            CounterFacts counterFacts = CounterFacts(facts);
            address prediction =
                counterFacts.predict('hello "world"', bytes32(0));
            vm.broadcast(deployer);
            counterFacts.mint(prediction);
            console2.log("Deployed CounterFacts to", facts);
        }
    }
}
