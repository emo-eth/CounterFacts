// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script, console2 } from "forge-std/Script.sol";
import { CounterFacts } from "../src/CounterFacts.sol";

contract Mint is Script {
    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.rememberKey(key);
        CounterFacts counterFacts = CounterFacts(vm.envAddress("COUNTERFACTS"));

        string[] memory networks = vm.envString("NETWORKS", ",");
        for (uint256 i; i < networks.length; i++) {
            string memory network = networks[i];
            vm.createSelectFork(getChain(network).rpcUrl);
            string memory data =
                '<svg width="100" height="50"><text x="10" y="30" font-size="20">Hello World</text></svg>';
            address prediction = counterFacts.predict(data, bytes32(0));
            vm.broadcast(deployer);
            uint256 tokenId = counterFacts.mint(prediction);
            vm.broadcast(deployer);
            counterFacts.reveal(tokenId, data, bytes32(0));

            address facts = address(counterFacts);
            console2.log("Deployed CounterFacts to", facts);
        }
    }
}
