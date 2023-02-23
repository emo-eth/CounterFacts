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
 *         function. The data contract will be deployed to the same address,
 *         and the token will be updated to display the text the data contract
 *         contains.
 */
contract CounterFacts is ERC721(unicode"CounterFacts™", "COUNTER") {
    error ContractExists();
    error IncorrectStorageAddress();
    error DuplicateCounterFact();
    error TokenDoesNotExist(uint256 tokenId);

    event MetadataUpdate(uint256 _tokenId);

    struct DataContract {
        address dataContract;
        bool deployed;
    }

    uint256 public nextTokenId;
    mapping(uint256 tokenId => address creator) public creators;
    mapping(uint256 tokenId => DataContract dataContract) internal
        _dataContracts;
    mapping(address dataContract => uint256 tokenId) public
        dataContractToTokenId;

    /**
     * @notice Mint a new CounterFact™ by providing the deterministic address
     * of its contents (must currently be empty).
     */
    function mint(address dataContract) public returns (uint256 tokenId) {
        // this can be inaccurate if called during the constructor of
        // dataContract, so also store a boolean flag when actually deployed
        // by reveal()
        if (dataContract.code.length > 0) {
            revert ContractExists();
        }
        if (dataContractToTokenId[dataContract] != 0) {
            revert DuplicateCounterFact();
        }
        // Increment tokenId before minting to avoid tokenId 0
        tokenId = ++nextTokenId;
        // store the creator
        creators[tokenId] = msg.sender;
        // store the counterfactual contract address
        _dataContracts[tokenId] =
            DataContract({ dataContract: dataContract, deployed: false });
        // store the tokenId in the reverse mapping
        dataContractToTokenId[dataContract] = tokenId;
        _mint(msg.sender, tokenId);
    }

    /**
     * @notice Reveal the contents of a CounterFact™ by providing the data and
     *         salt that were used to generate the deterministic address used to
     *         mint it.
     */
    function reveal(uint256 tokenId, string calldata data, bytes32 salt)
        public
    {
        if (_ownerOf[tokenId] == address(0)) {
            revert TokenDoesNotExist(tokenId);
        }
        address deployed = SSTORE2.writeDeterministic(bytes(data), salt);
        DataContract memory dataContract = _dataContracts[tokenId];
        // check that the deployed address matches the counterfactual address
        if (deployed != dataContract.dataContract) {
            revert IncorrectStorageAddress();
        }
        _dataContracts[tokenId].deployed = true;
        // signal that the metadata has been updated
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice Convenience method to determine the deterministic address of a
     *         CounterFact™'s contents. Note that you will be exposing the
     *         contents of the CounterFact™ to the RPC provider.
     */
    function predict(string calldata data, bytes32 salt)
        public
        view
        returns (address)
    {
        return SSTORE2.predictDeterministicAddress(
            bytes(data), salt, address(this)
        );
    }

    /**
     * @notice Get the URI for a CounterFact™'s metadata.
     */
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

    /**
     * @notice Get the string URI for a CounterFact™'s metadata, for
     * convenience.
     */
    function stringURI(uint256 tokenId) public view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) {
            revert TokenDoesNotExist(tokenId);
        }
        string memory escapedString;

        DataContract memory dataContractStruct = _dataContracts[tokenId];
        address dataContract = dataContractStruct.dataContract;
        if (dataContract.code.length > 0) {
            if (dataContractStruct.deployed) {
                // escape HTML to avoid embedding of non-text content
                // escape JSON to avoid breaking the JSON
                escapedString = LibString.escapeJSON(
                    LibString.escapeHTML(string(SSTORE2.read(dataContract)))
                );
            } else {
                escapedString = "data:text/plain,Very sneaky!";
                return string.concat(
                    '{"animation_url":"',
                    escapedString,
                    '","attributes":[{"trait_type":"Creator","value":"',
                    "The Sneakooooor",
                    '"},{"trait_type":"Data Contract","value":"',
                    LibString.toHexString(dataContract),
                    '"}, {"trait_type":"Sneaky","value":"Yes',
                    '"}]}'
                );
            }
        } else {
            escapedString = "This CounterFact has not yet been revealed.";
        }
        escapedString = string.concat("data:text/plain,", escapedString);
        return string.concat(
            '{"animation_url":"',
            escapedString,
            '","attributes":[{"trait_type":"Creator","value":"',
            LibString.toHexString(creators[tokenId]),
            '"},{"trait_type":"Data Contract","value":"',
            LibString.toHexString(dataContract),
            '"}]}'
        );
    }

    function getDataContract(uint256 tokenId)
        public
        view
        returns (DataContract memory dataContract)
    {
        return _dataContracts[tokenId];
    }

    function contractURI() public pure returns (string memory) {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        unicode'{"name":"CounterFacts™","description":"Counterfacts™: the fun, collectible way to prove ',
                        unicode"you're right!",
                        '"}'
                    )
                )
            )
        );
    }
}
