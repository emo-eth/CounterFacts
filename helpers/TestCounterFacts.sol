// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { CounterFacts } from "../src/CounterFacts.sol";

contract TestCounterFacts is CounterFacts {
    function stringURI(uint256 id) public view returns (string memory) {
        return stringURI(id);
    }
}
