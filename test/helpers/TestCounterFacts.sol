// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Counterfacts } from "../../src/Counterfacts.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";

contract TestCounterfacts is Counterfacts {
    function setMetadata(uint256 tokenId, Counterfacts.Metadata memory data)
        public
    {
        _tokenMetadata[tokenId] = data;
    }

    function setDataContract(uint256 tokenId, address data) public {
        _dataContractAddresses[tokenId] = data;
    }

    function getTokenSVG(uint256 tokenId) public view returns (string memory) {
        Metadata storage metadata = _tokenMetadata[tokenId];

        address dataContract = _dataContractAddresses[tokenId];

        string memory rawString = "This Counterfact has not yet been revealed.";
        if (dataContract != address(0)) {
            rawString = string(SSTORE2.read(dataContract));
        }

        return tokenSVG({
            creator: metadata.creator,
            mintTime: metadata.mintTime,
            validationHash: metadata.validationHash,
            dataContract: dataContract,
            content: rawString
        });
    }
}
