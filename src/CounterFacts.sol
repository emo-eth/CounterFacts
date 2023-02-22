// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

/**
 * @title CounterFacts™
 * @author emo.eth
 * @notice A contract for minting and revealing CounterFacts™: the fun,
 *         collectible way to prove you're right!
 *
 *         CounterFacts™ are ERC721 tokens that are pointers to data
 *         contracts containing the text of a prediction. Did we mention that
 *         the contract might not actually exist?
 *         Upon minting a CounterFact™, the creator supplies the deterministic
 *         counterfactual address of this data contract. Anyone can then
 *         reveal the text by providing the original data + salt to the reveal
 *         function. The data contract will be deployed to the same  address,
 *         and the token will be updated to display the text the data contract
 *         contains.
 */
contract CounterFacts is ERC721(unicode"CounterFacts™", "COUNTER") {
    error ContractExists();
    error IncorrectStorageAddress();
    error DuplicateCounterFact();
    error TokenDoesNotExist(uint256 tokenId);

    event MetadataUpdate(uint256 _tokenId);

    uint256 public nextTokenId;
    mapping(uint256 tokenId => address creator) public creators;
    mapping(uint256 tokenId => address dataContract) public dataContracts;
    mapping(address dataContract => uint256 tokenId) public
        dataContractToTokenId;

    function mint(address dataContract) public returns (uint256 tokenId) {
        if (dataContract.code.length > 0) {
            revert ContractExists();
        }
        if (dataContractToTokenId[dataContract] != 0) {
            revert DuplicateCounterFact();
        }
        tokenId = ++nextTokenId;
        creators[tokenId] = msg.sender;
        dataContracts[tokenId] = dataContract;
        dataContractToTokenId[dataContract] = tokenId;
        _mint(msg.sender, tokenId);
    }

    function reveal(uint256 tokenId, string calldata data, bytes32 salt)
        public
    {
        if (_ownerOf[tokenId] == address(0)) {
            revert TokenDoesNotExist(tokenId);
        }
        address deployed = SSTORE2.writeDeterministic(bytes(data), salt);
        if (deployed != dataContracts[tokenId]) {
            revert IncorrectStorageAddress();
        }

        emit MetadataUpdate(tokenId);
    }

    function predict(string calldata data, bytes32 salt)
        public
        view
        returns (address)
    {
        return SSTORE2.predictDeterministicAddress(
            bytes(data), salt, address(this)
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(stringURI(tokenId)))
        );
    }

    function stringURI(uint256 tokenId) public view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) {
            revert TokenDoesNotExist(tokenId);
        }
        string memory jsonEscapedString;

        address dataContract = dataContracts[tokenId];
        if (dataContract.code.length > 0) {
            jsonEscapedString =
                LibString.escapeJSON(string(SSTORE2.read(dataContract)));
        } else {
            jsonEscapedString = "This CounterFact has not yet been revealed.";
        }
        jsonEscapedString = string.concat("data:text/plain,", jsonEscapedString);
        return string.concat(
            '{"animation_url":"',
            jsonEscapedString,
            '","attributes":[{"trait_type":"Creator","value":"',
            LibString.toHexString(creators[tokenId]),
            '"},{"trait_type":"Data Contract","value":"',
            LibString.toHexString(dataContract),
            '"}]}'
        );
    }
}
