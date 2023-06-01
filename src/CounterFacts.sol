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
    error IncorrectStorageAddress();
    error InsufficientTimePassed();
    error TokenDoesNotExist(uint256 tokenId);

    event MetadataUpdate(uint256 _tokenId);

    uint256 public constant MINT_DELAY = 1 minutes;
    uint256 internal constant UINT96_MASK = 0xffffffffffffffffffffffff;

    struct Metadata {
        address creator;
        uint96 mintTime;
        bytes32 validationHash;
    }

    uint256 public nextTokenId;
    mapping(uint256 tokenId => Metadata metadata) internal _tokenMetadata;
    mapping(uint256 tokenId => address dataContractAddress) internal
        _dataContractAddresses;

    /**
     * @notice Mint a new CounterFact™ by providing a validation hash that
     * will be checked at time of reveal. The validation hash is a function of
     * both the counterfactual data contract address and the token creator.
     * By providing a hash that is dependent on both the data contract address
     * and the minter address, the minter is protected from having their mint
     * transaction front-run by a malicious actor, while still ensuring that the
     * creator has pre-written their CounterFact™, since it requires knowing the
     * data contract address in advance.
     * @param validationHash The resultant hash of the counterfactual data
     *        contract's address and the creator's address, calculated as
     *        keccak256(abi.encode(dataContractAddress, creatorAddress)). Upon
     *        revealing, the deployed data contract address will be hashed with
     *        the creator's address and compared to this value. If they do not
     *        match, the reveal will revert.
     */
    function mint(bytes32 validationHash) public returns (uint256 tokenId) {
        // Increment tokenId before minting to avoid tokenId 0
        tokenId = ++nextTokenId;

        ///@solidity memory-safe-assembly
        assembly {
            // compute storage slot for data contract address
            mstore(0, tokenId)
            mstore(0x20, _tokenMetadata.slot)
            let slot := keccak256(0, 0x40)
            // pack caller and mintTime
            let packedCreatorTimestamp :=
                or(
                    // msg.sender in top 160 bits
                    shl(96, caller()),
                    // will overflow uint96 in 2.5 quadrillion million years
                    timestamp()
                )
            sstore(slot, packedCreatorTimestamp)
            // store validationHash in the next slot
            sstore(add(slot, 1), validationHash)
        }
        _mint(msg.sender, tokenId);
    }

    function tokenMetadata(uint256 tokenId)
        public
        view
        returns (address creator, uint256 mintTime, bytes32 validationHash)
    {
        bytes32 slot;
        ///@solidity memory-safe-assembly
        assembly {
            // compute storage slot for data contract address
            mstore(0, tokenId)
            mstore(0x20, _tokenMetadata.slot)
            slot := keccak256(0, 0x40)
        }
        (creator, mintTime, validationHash) = _loadTokenMetadataFromSlot(slot);
    }

    function dataContractAddress(uint256 tokenId)
        public
        view
        returns (address _addr)
    {
        ///@solidity memory-safe-assembly
        assembly {
            // compute storage slot for data contract address
            mstore(0, tokenId)
            mstore(0x20, _dataContractAddresses.slot)
            let slot := keccak256(0, 0x40)
            _addr := sload(slot)
        }
    }

    /**
     * @notice Reveal the contents of a CounterFact™ by providing the data and
     *         salt that were used to generate the deterministic address used to
     *         mint it. Note that a one-minute delay is enforced between minting
     *         and revealing to prevent malicious actors from front-running
     *         reveals by minting and immediately revealing.
     */
    function reveal(uint256 tokenId, string calldata data, uint96 userSalt)
        public
    {
        _assertExists(tokenId);

        (address creator, uint256 mintTime, bytes32 validationHash) =
            tokenMetadata(tokenId);
        // enforce a delay to prevent front-running reveals by minting and then
        // immediately revealing
        if (block.timestamp < mintTime + MINT_DELAY) {
            revert InsufficientTimePassed();
        }
        bytes32 salt;
        ///@solidity memory-safe-assembly
        assembly {
            salt := or(shl(96, creator), userSalt)
        }
        // deploy counterfactual data contract
        address deployed = SSTORE2.writeDeterministic(bytes(data), salt);
        // compute a validation hash from the data and the creator
        bytes32 computedValidationHash;
        ///@solidity memory-safe-assembly
        assembly {
            mstore(0, deployed)
            mstore(0x20, creator)
            computedValidationHash := keccak256(0, 0x40)
        }
        // compare it to the one provided at mint time
        bytes32 validationhash = validationHash;
        // if they don't match, the wrong data has been provided
        if (validationhash != computedValidationHash) {
            revert IncorrectStorageAddress();
        }
        // store the address of the deployed data contract:
        // _dataContractAddresses[tokenId] = deployed;
        ///@solidity memory-safe-assembly
        assembly {
            // compute storage slot for data contract address
            mstore(0, tokenId)
            mstore(0x20, _dataContractAddresses.slot)
            let slot := keccak256(0, 0x40)
            sstore(slot, deployed)
        }
        // signal that the metadata has been updated
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice Convenience method to determine the deterministic address of a
     *         CounterFact™'s contents. Note that you will be exposing the
     *         contents of the CounterFact™ to the RPC provider.
     */
    function predict(string calldata data, address creator, uint96 userSalt)
        public
        view
        returns (address)
    {
        bytes32 salt;
        ///@solidity memory-safe-assembly
        assembly {
            salt := or(shl(96, creator), userSalt)
        }
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

    event log(address);
    /**
     * @notice Get the string URI for a CounterFact™'s metadata, for
     * convenience.
     */

    function stringURI(uint256 tokenId) public view returns (string memory) {
        _assertExists(tokenId);

        string memory escapedString;
        (address creator,, bytes32 validationHash) = tokenMetadata(tokenId);
        address dataContract = dataContractAddress(tokenId);
        string memory lagniappe = "";
        if (dataContract != address(0)) {
            // escape JSON to avoid breaking the JSON
            escapedString = LibString.escapeJSON(
                // escape HTML to avoid embedding of non-text content
                LibString.escapeHTML(string(SSTORE2.read(dataContract)))
            );
            escapedString = string.concat("data:text/plain,", escapedString);
            // revealed tokens should specify "Yes" for revealed and the data
            // contract address
            lagniappe = string.concat(
                '"Yes"},{"trait_type":"Data Contract","value":"',
                LibString.toHexString(dataContract)
            );
        } else {
            escapedString = "This CounterFact has not yet been revealed.";
            // unrevealed tokens should specify "No" for revealed and no data
            // contract address
            lagniappe = '"No"';
        }
        // specify plaintext encoding
        escapedString = string.concat("data:text/plain,", escapedString);
        return string.concat(
            '{"animation_url":"',
            escapedString,
            '","attributes":[{"trait_type":"Creator","value":"',
            LibString.toHexString(creator),
            '"},{"trait_type":"Validation Hash","value":"',
            LibString.toHexString(uint256(validationHash)),
            '"},{"trait_type":"Revealed?","value":',
            lagniappe,
            "}]}"
        );
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

    function _loadTokenMetadataFromSlot(bytes32 slot)
        internal
        view
        returns (address creator, uint256 mintTime, bytes32 validationHash)
    {
        ///@solidity memory-safe-assembly
        assembly {
            slot := keccak256(0, 0x40)
            let packedCreatorTimestamp := sload(slot)
            // unpack creator and mintTime
            creator := shr(96, packedCreatorTimestamp)
            mintTime := and(UINT96_MASK, packedCreatorTimestamp)
            // load validationHash from next slot
            validationHash := sload(add(slot, 1))
        }
    }

    function _assertExists(uint256 tokenId) internal view {
        address owner;
        ///@solidity memory-safe-assembly
        assembly {
            // compute storage slot for owner
            mstore(0, tokenId)
            mstore(0x20, _ownerOf.slot)
            let slot := keccak256(0, 0x40)
            owner := sload(slot)
        }
        if (owner == address(0)) {
            revert TokenDoesNotExist(tokenId);
        }
    }
}
