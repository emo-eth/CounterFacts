// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.17;

// import { Script, console2 } from "forge-std/Script.sol";
// import { Counterfacts } from "../src/Counterfacts.sol";
// import { ConstructorMinter } from "../test/helpers/ConstructorMinter.sol";
// import { IERC721 } from "forge-std/interfaces/IERC721.sol";
// import { SSTORE2 } from "solady/utils/SSTORE2.sol";

// contract Mint is Script {
//     function run() public {
//         vm.createSelectFork("mainnet");

//         address minter;
//         bool ledger = vm.envOr("LEDGER", false);
//         if (ledger) {
//             minter = vm.envAddress("MINTER_ADDRESS");
//         } else {
//             uint256 key = vm.envUint("MINTER_PRIVATE_KEY");
//             minter = vm.rememberKey(key);
//         }

//         // uncomment for dry runs with no ether
//         // vm.deal(minter, 1 ether);

//         bytes32 salt = vm.envBytes32("SALT");
//         string memory text = vm.envString("PREDICTION_TEXT");

//         Counterfacts counterFacts =
// Counterfacts(vm.envAddress("COUNTERFACTS"));

//         address prediction = SSTORE2.predictDeterministicAddress(
//             bytes(text), salt, address(counterFacts)
//         );

//         vm.broadcast(minter);
//         uint256 tokenId = counterFacts.mint(prediction);
//         console2.log("Minted token", tokenId);
//     }
// }
