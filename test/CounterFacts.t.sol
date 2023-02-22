// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "./BaseTest.sol";
import { CounterFacts } from "../src/CounterFacts.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";

contract CounterFactsTest is BaseTest {
    CounterFacts counter;

    event MetadataUpdate(uint256 _tokenId);

    function setUp() public virtual override {
        super.setUp();
        counter = new CounterFacts();
    }

    function testMint() public {
        uint256 tokenId = counter.mint(address(1234));
        assertEq(counter.ownerOf(tokenId), address(this));
        assertEq(counter.dataContracts(tokenId), address(1234));
        assertEq(counter.dataContractToTokenId(address(1234)), tokenId);

        uint256 nextTokenId = counter.mint(address(5678));
        assertEq(counter.ownerOf(nextTokenId), address(this));
        assertEq(counter.dataContracts(nextTokenId), address(5678));
        assertEq(counter.dataContractToTokenId(address(5678)), nextTokenId);
        assertTrue(tokenId != nextTokenId);
    }

    function testMint_ContractExists() public {
        vm.expectRevert(CounterFacts.ContractExists.selector);
        counter.mint(address(this));
    }

    function testMint_DuplicateCounterFact() public {
        counter.mint(address(1234));
        vm.expectRevert(CounterFacts.DuplicateCounterFact.selector);
        counter.mint(address(1234));
    }

    function testReveal() public {
        address predicted = counter.predict("data", bytes32(0));
        uint256 tokenId = counter.mint(predicted);
        vm.expectEmit(true, false, false, false, address(counter));
        emit MetadataUpdate(tokenId);
        counter.reveal(tokenId, "data", bytes32(0));
    }

    function testReveal_NoToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(CounterFacts.TokenDoesNotExist.selector, 1)
        );
        counter.reveal(1, "data", bytes32(0));
    }

    function testReveal_IncorrectStorageAddress() public {
        uint256 tokenId = counter.mint(address(1234));
        vm.expectRevert(CounterFacts.IncorrectStorageAddress.selector);
        counter.reveal(tokenId, "data", bytes32(0));
    }

    function testStringURI_TokenDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(CounterFacts.TokenDoesNotExist.selector, 1)
        );
        counter.stringURI(1);
    }

    function testStringURI() public {
        uint256 tokenId = counter.mint(address(1234));
        assertEq(
            counter.stringURI(tokenId),
            _generateString("", address(this), address(1234))
        );

        string memory data = 'data "with quotes"';
        address predicted = counter.predict(data, bytes32(0));
        tokenId = counter.mint(predicted);
        counter.reveal(tokenId, data, bytes32(0));
        assertEq(
            counter.stringURI(tokenId),
            _generateString(data, address(this), predicted)
        );
    }

    function testTokenURI() public {
        uint256 tokenId = counter.mint(address(1234));
        assertEq(
            counter.tokenURI(tokenId),
            _generateBase64("", address(this), address(1234))
        );

        string memory data = 'data "with quotes"';
        address predicted = counter.predict(data, bytes32(0));
        tokenId = counter.mint(predicted);
        counter.reveal(tokenId, data, bytes32(0));
        assertEq(
            counter.tokenURI(tokenId),
            _generateBase64(data, address(this), predicted)
        );
    }

    function _generateBase64(
        string memory data,
        address creator,
        address dataContract
    ) internal pure returns (string memory) {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(_generateString(data, creator, dataContract)))
        );
    }

    function _generateString(
        string memory data,
        address creator,
        address dataContract
    ) internal pure returns (string memory) {
        if (bytes(data).length > 0) {
            data =
                LibString.concat("data:text/plain,", LibString.escapeJSON(data));
        }
        return string.concat(
            '{"animation_url":"',
            data,
            '","attributes":[{"trait_type":"Creator","value":"',
            LibString.toHexString(creator),
            '"},{"trait_type":"Data Contract","value":"',
            LibString.toHexString(dataContract),
            '"}]}'
        );
    }
}
