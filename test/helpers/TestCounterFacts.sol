// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { CounterFacts } from "../../src/CounterFacts.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";

contract TestCounterFacts is CounterFacts {
    function setMetadata(uint256 tokenId, CounterFacts.Metadata memory data)
        public
    {
        _tokenMetadata[tokenId] = data;
    }

    function setDataContract(uint256 tokenId, address data) public {
        _dataContractAddresses[tokenId] = data;
    }

    function getTokenSVG(uint256 tokenId) public view returns (string memory) {
        (address creator, uint256 timestamp, bytes32 validationHash) =
            tokenMetadata(tokenId);
        address dataContract = dataContractAddress(tokenId);

        string memory rawString = "This CounterFact has not yet been revealed.";
        if (dataContract != address(0)) {
            rawString = string(SSTORE2.read(dataContract));
        }

        return tokenSVG({
            creator: creator,
            mintTime: timestamp,
            validationHash: validationHash,
            dataContract: dataContract,
            content: rawString
        });
    }
}
