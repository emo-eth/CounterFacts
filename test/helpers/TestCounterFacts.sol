// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { CounterFacts } from "../../src/CounterFacts.sol";

contract TestCounterFacts is CounterFacts {
    function setMetadata(uint256 tokenId, CounterFacts.Metadata memory data)
        public
    {
        _tokenMetadata[tokenId] = data;
    }

    function setDataContract(uint256 tokenId, address data) public {
        _dataContractAddresses[tokenId] = data;
    }
}
