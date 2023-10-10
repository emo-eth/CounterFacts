// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

/**
 * @title Counterfacts™
 * @author emo.eth
 * @notice A contract for minting and revealing Counterfacts™: the fun,
 *         collectible way to prove you're right!
 *
 *         Counterfacts™ are ERC721 tokens that are pointers to data
 *         contracts containing the text of a prediction. Did we mention that
 *         the contract might not actually exist?
 *         Upon minting a Counterfact™, the creator supplies the deterministic
 *         counterfactual address of this data contract. Anyone can then
 *         reveal the text by providing the original data + salt to the reveal
 *         function. The data contract will be deployed to the same address,
 *         and the token will be updated to display the text the data contract
 *         contains.
 */
contract Counterfacts is ERC721 {
    error IncorrectStorageAddress();
    error InsufficientTimePassed();

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

    function name() public pure override returns (string memory) {
        return unicode"Counterfacts™";
    }

    function symbol() public pure override returns (string memory) {
        return "COUNTER";
    }

    function tokenMetadata(uint256 tokenId)
        public
        view
        returns (address creator, uint256 mintTime, bytes32 validationHash)
    {
        _assertExists(tokenId);
        Metadata storage metadata = _tokenMetadata[tokenId];
        creator = metadata.creator;
        mintTime = metadata.mintTime;
        validationHash = metadata.validationHash;
    }

    function dataContractAddress(uint256 tokenId)
        public
        view
        returns (address)
    {
        _assertExists(tokenId);
        return _dataContractAddresses[tokenId];
    }

    /**
     * @notice Mint a new Counterfact™ by providing a validation hash that
     * will be checked at time of reveal. The validation hash is a function of
     * both the counterfactual data contract address and the token creator.
     * By providing a hash that is dependent on both the data contract address
     * and the minter address, the minter is protected from having their mint
     * transaction front-run by a malicious actor, while still ensuring that the
     * creator has pre-written their Counterfact™, since it requires knowing the
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
        unchecked {
            tokenId = ++nextTokenId;
        }
        Metadata storage metadata = _tokenMetadata[tokenId];
        metadata.creator = msg.sender;
        metadata.mintTime = uint96(block.timestamp);
        metadata.validationHash = validationHash;
        _mint(msg.sender, tokenId);
    }

    /**
     * @notice Reveal the contents of a Counterfact™ by providing the data and
     *         salt that were used to generate the deterministic address used to
     *         mint it. Note that a one-minute delay is enforced between minting
     *         and revealing to prevent malicious actors from front-running
     *         reveals by minting and immediately revealing.
     */
    function reveal(uint256 tokenId, string calldata data, uint96 userSalt)
        public
    {
        _assertExists(tokenId);

        Metadata storage metadata = _tokenMetadata[tokenId];
        address creator = metadata.creator;
        uint256 mintTime = metadata.mintTime;

        // enforce a delay to prevent front-running reveals by minting and then
        // immediately revealing
        if (block.timestamp < mintTime + MINT_DELAY) {
            revert InsufficientTimePassed();
        }
        bytes32 salt;
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
        bytes32 validationHash = metadata.validationHash;
        // if they don't match, the wrong data has been provided
        if (validationHash != computedValidationHash) {
            revert IncorrectStorageAddress();
        }
        // store the address of the deployed data contract:
        _dataContractAddresses[tokenId] = deployed;
        // signal that the metadata has been updated
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice Convenience method to determine the deterministic address of a
     *         Counterfact™'s contents. Note that you will be exposing the
     *         contents of the Counterfact™ to the RPC provider.
     */
    function predict(string calldata data, address creator, uint96 userSalt)
        public
        view
        returns (address)
    {
        bytes32 salt;
        assembly {
            salt := or(shl(96, creator), userSalt)
        }
        return SSTORE2.predictDeterministicAddress(
            bytes(data), salt, address(this)
        );
    }

    /**
     * @notice Get the URI for a Counterfact™'s metadata.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _assertExists(tokenId);

        Metadata storage metadata = _tokenMetadata[tokenId];
        address creator = metadata.creator;
        uint256 mintTime = metadata.mintTime;
        bytes32 validationHash = metadata.validationHash;

        address dataContract = _dataContractAddresses[tokenId];
        string memory rawString;
        string memory revealedTraits = "";
        if (dataContract != address(0)) {
            // escape HTML to avoid embedding of non-text content

            rawString = string(SSTORE2.read(dataContract));

            // revealed tokens should specify "Yes" for revealed and the data
            // contract address
            revealedTraits = string.concat(
                '"Yes"},{"trait_type":"Data Contract","value":"',
                LibString.toHexString(dataContract)
            );
        } else {
            rawString = "This Counterfact has not yet been revealed.";
            // unrevealed tokens should specify "No" for revealed and no data
            // contract address
            revealedTraits = '"No"';
        }
        string memory svg = string.concat(
            "data:image/svg+xml;base64,",
            Base64.encode(
                bytes(
                    tokenSVG(
                        creator,
                        mintTime,
                        validationHash,
                        dataContract,
                        LibString.escapeHTML(rawString)
                    )
                )
            )
        );
        return string.concat(
            '{"image":"',
            svg,
            '"text":"',
            LibString.escapeJSON(rawString),
            '","attributes":[{"trait_type":"Creator","value":"',
            LibString.toHexString(uint256(uint160(creator)), 20),
            '"},{"trait_type":"Validation Hash","value":"',
            LibString.toHexString(uint256(validationHash), 32),
            '"},{"trait_type":"Revealed?","value":',
            revealedTraits,
            "}]}"
        );
    }

    function tokenSVG(
        address creator,
        uint256 mintTime,
        bytes32 validationHash,
        address dataContract,
        string memory content
    ) internal pure returns (string memory) {
        content = LibString.escapeHTML(content);
        string[7] memory colors =
            ["#e44", "#f71", "#eb0", "#2c5", "#0ae", "#85f", "#777"];
        uint256 colorIndex = uint256(validationHash) % colors.length;
        string memory color = colors[colorIndex];

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" style="background:#151520" viewBox="0 0 700 300"><path id="a" fill="#151520" d="M20 10h655a10 10 0 0 1 10 10v260a20 10 0 0 1-10 10H20a20 10 0 0 1-10-10V10z"/><text fill="',
            color,
            unicode'" dominant-baseline="middle" font-family="Menlo,monospace" font-size="12"><textPath href="#a"><![CDATA[ ',
            marquee(creator, mintTime, validationHash, dataContract),
            ']]></textPath></text><path fill="rgba(0,0,0,0)" stroke="',
            color,
            '" d="M20 20h645a10 10 0 0 1 10 10v240a10 10 0 0 1-10 10H30a10 10 0 0 1-10-10V20z"/><foreignObject x="40" y="15" width="85%" height="85%"><div style="font-family:Menlo,monospace;color:#fff;display:flex;align-items:center;justify-content:left;font-size:0.8em;"  xmlns="http://www.w3.org/1999/xhtml"><p>',
            content,
            "</p></div></foreignObject></svg>"
        );
    }

    function marquee(
        address creator,
        uint256 mintTime,
        bytes32 validationHash,
        address dataContract
    ) internal pure returns (string memory result) {
        result = string.concat(
            "Creator: ",
            LibString.toHexString(uint256(uint160(creator)), 20),
            " Mint Timestamp: ",
            LibString.toString(mintTime),
            " Validation Hash: ",
            LibString.toHexString(uint256(validationHash), 32)
        );
        if (dataContract != address(0)) {
            result = string.concat(
                result,
                " Data Contract: ",
                LibString.toHexString(uint256(uint160(dataContract)), 20)
            );
        }
    }

    function contractURI() public pure returns (string memory) {
        return string.concat(
            "data:application/json;",
            string.concat(
                unicode'{"name":"Counterfacts™","description":"Counterfacts™: the fun, collectible way to prove ',
                unicode"you're right!",
                '"}'
            )
        );
    }

    function _assertExists(uint256 tokenId) internal view {
        if (!(_exists(tokenId))) {
            revert TokenDoesNotExist();
        }
    }
}
