// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { CounterFacts } from "../../src/CounterFacts.sol";

contract TestCounterFacts is CounterFacts {
    function setDataContract(
        uint256 tokenId,
        CounterFacts.DataContract memory data
    ) public {
        _dataContracts[tokenId] = data;
    }
}
