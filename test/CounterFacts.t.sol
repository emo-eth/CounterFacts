// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "./BaseTest.sol";
import { TestCounterFacts } from "./helpers/TestCounterFacts.sol";
import { CounterFacts } from "../src/CounterFacts.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { ConstructorMinter } from "./helpers/ConstructorMinter.sol";
import { Base64 } from "solady/utils/Base64.sol";

contract CounterFactsTest is BaseTest {
    TestCounterFacts counter;

    event MetadataUpdate(uint256 _tokenId);

    function setUp() public virtual override {
        super.setUp();
        counter = new TestCounterFacts();
    }

    function testMint() public {
        uint256 tokenId = counter.mint(address(1234));
        assertEq(counter.ownerOf(tokenId), address(this));
        assertEq(counter.getDataContract(tokenId).dataContract, address(1234));
        assertFalse(counter.getDataContract(tokenId).deployed); //,
            // address(1234));
        assertEq(counter.dataContractToTokenId(address(1234)), tokenId);

        uint256 nextTokenId = counter.mint(address(5678));
        assertEq(counter.ownerOf(nextTokenId), address(this));
        assertEq(
            counter.getDataContract(nextTokenId).dataContract, address(5678)
        );
        assertFalse(counter.getDataContract(nextTokenId).deployed); //,
            // address(5678));
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
            data = LibString.concat(
                "data:text/plain,",
                LibString.escapeJSON(LibString.escapeHTML(data))
            );
        } else {
            data = LibString.concat(
                "data:text/plain,",
                "This CounterFact has not yet been revealed."
            );
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

    function testSneaky() public {
        uint256 tokenId = counter.mint(address(1234));
        counter.setDataContract(
            tokenId,
            CounterFacts.DataContract({
                dataContract: address(this),
                deployed: false
            })
        );

        string memory uri = counter.stringURI(tokenId);
        assertEq(
            bytes(uri),
            '{"animation_url":"data:text/plain,Very sneaky!","attributes":[{"trait_type":"Creator","value":"The Sneakooooor"},{"trait_type":"Data Contract","value":"0x7fa9385be102ac3eac297483dd6233d62b3e1496"}, {"trait_type":"Sneaky","value":"Yes"}]}'
        );
    }

    function testConstructorMint() public {
        ConstructorMinter minter = new ConstructorMinter(address(counter));
        assertEq(counter.ownerOf(1), address(minter));
        assertEq(
            bytes(counter.tokenURI(1)),
            "data:application/json;base64,eyJhbmltYXRpb25fdXJsIjoiZGF0YTp0ZXh0L3BsYWluLFZlcnkgc25lYWt5ISIsImF0dHJpYnV0ZXMiOlt7InRyYWl0X3R5cGUiOiJDcmVhdG9yIiwidmFsdWUiOiJUaGUgU25lYWtvb29vb3IifSx7InRyYWl0X3R5cGUiOiJEYXRhIENvbnRyYWN0IiwidmFsdWUiOiIweDJlMjM0ZGFlNzVjNzkzZjY3YTM1MDg5YzlkOTkyNDVlMWM1ODQ3MGIifSwgeyJ0cmFpdF90eXBlIjoiU25lYWt5IiwidmFsdWUiOiJZZXMifV19"
        );
    }
}
