// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "./BaseTest.sol";
import { ERC721 } from "solady/tokens/ERC721.sol";
import { console2 } from "forge-std/Test.sol";
import { TestCounterfacts } from "./helpers/TestCounterfacts.sol";
import { Counterfacts } from "../src/Counterfacts.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { ConstructorMinter } from "./helpers/ConstructorMinter.sol";
import { Base64 } from "solady/utils/Base64.sol";

contract CounterfactsTest is BaseTest {
    TestCounterfacts counter;

    event MetadataUpdate(uint256 _tokenId);

    struct Attribute {
        string trait_type;
        string value;
    }

    struct RevealedMetadata {
        string animation_url;
        Attribute[] attributes;
    }

    function setUp() public virtual override {
        super.setUp();
        vm.warp(1_696_961_599);
        counter = new TestCounterfacts();
    }

    function testMintPackUnpack(
        address creator,
        uint96 timestamp,
        bytes32 validationHash
    ) public {
        creator = coerce(creator);
        vm.warp(timestamp);
        vm.prank(creator);
        uint256 tokenId = counter.mint(validationHash);
        (address _creator, uint256 _timestamp, bytes32 _validation) =
            counter.tokenMetadata(tokenId);
        assertEq(_creator, creator, "creator != creator");
        assertEq(_timestamp, timestamp, "timestamp != timestamp");
        assertEq(_validation, validationHash, "validation != validationHash");
        assertEq(counter.ownerOf(tokenId), creator);
    }

    function testGetTokenSVG() public {
        uint256 tokenId = counter.mint(bytes32(uint256(1234)));
        assertEq(counter.ownerOf(tokenId), address(this));
        string memory svg = counter.getTokenSVG(tokenId);
        vm.writeFile("x.svg", svg);

        string memory data =
            "this is a really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really really long string";
        address predicted = counter.predict(data, address(this), 0);
        tokenId = counter.mint(keccak256(abi.encode(predicted, address(this))));
        vm.warp(block.timestamp + 120);

        counter.reveal(tokenId, data, 0);
        svg = counter.getTokenSVG(tokenId);
        vm.writeFile("y.svg", svg);
    }

    // function testMint() public {
    //     uint256 tokenId = counter.mint(bytes32(uint256(1234)));
    //     assertEq(counter.ownerOf(tokenId), address(this));

    //     assertEq(counter.getDataContract(tokenId).dataContract,
    // address(1234));
    //     assertFalse(counter.getDataContract(tokenId).deployed); //,
    //         // address(1234));
    //     assertEq(counter.dataContractToTokenId(address(1234)), tokenId);

    //     uint256 nextTokenId = counter.mint(address(5678));
    //     assertEq(counter.ownerOf(nextTokenId), address(this));
    //     assertEq(
    //         counter.getDataContract(nextTokenId).dataContract, address(5678)
    //     );
    //     assertFalse(counter.getDataContract(nextTokenId).deployed); //,
    //         // address(5678));
    //     assertEq(counter.dataContractToTokenId(address(5678)), nextTokenId);
    //     assertTrue(tokenId != nextTokenId);
    // }

    // function testMint_ContractExists() public {
    //     vm.expectRevert(Counterfacts.ContractExists.selector);
    //     counter.mint(address(this));
    // }

    // function testMint_DuplicateCounterfact() public {
    //     counter.mint(address(1234));
    //     vm.expectRevert(Counterfacts.DuplicateCounterfact.selector);
    //     counter.mint(address(1234));
    // }

    function testReveal() public {
        address predicted = counter.predict("data", address(this), 0);
        uint256 tokenId =
            counter.mint(keccak256(abi.encode(predicted, address(this))));
        vm.warp(block.timestamp + 60);
        vm.expectEmit(true, false, false, false, address(counter));
        emit MetadataUpdate(tokenId);
        counter.reveal(tokenId, "data", 0);
    }

    function testReveal_TokenDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC721.TokenDoesNotExist.selector)
        );
        counter.reveal(1, "data", 0);
    }

    function testReveal_IncorrectStorageAddress() public {
        uint256 tokenId = counter.mint(bytes32(0));
        vm.warp(block.timestamp + 60);
        vm.expectRevert(Counterfacts.IncorrectStorageAddress.selector);
        counter.reveal(tokenId, "data", 0);
    }

    function testReveal_InsufficientTimePassed() public {
        address predicted = counter.predict("data", address(this), 0);
        uint256 tokenId =
            counter.mint(keccak256(abi.encode(predicted, address(this))));
        vm.expectRevert(Counterfacts.InsufficientTimePassed.selector);
        counter.reveal(tokenId, "data", 0);
    }

    function testPredictDifferentCreator() public {
        address predicted = counter.predict("data", address(this), 0);
        address predicted2 = counter.predict("data", address(1234), 0);
        assertTrue(predicted != predicted2);
    }

    function testDataContractAddress() public {
        address predicted = counter.predict("data", address(this), 0);
        // mint
        counter.mint(keccak256(abi.encode(predicted, address(this))));
        // warp
        vm.warp(block.timestamp + 60);
        // reveal
        counter.reveal(1, "data", 0);
        assertEq(
            counter.dataContractAddress(1),
            predicted,
            "dataContractAddress != predicted"
        );
    }

    function coerce(address addr) internal view returns (address) {
        return address(uint160(bound(uint160(addr), 1, type(uint160).max)));
    }

    function testDataContractAddress(address creator, uint96 salt) public {
        creator = coerce(creator);
        address predicted = counter.predict("data", creator, salt);
        // mint
        vm.prank(creator);
        counter.mint(keccak256(abi.encode(predicted, creator)));
        // warp
        vm.warp(block.timestamp + 60);
        // reveal
        counter.reveal(1, "data", salt);
        assertEq(
            counter.dataContractAddress(1),
            predicted,
            "dataContractAddress != predicted"
        );
    }

    function testStringURI_TokenDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC721.TokenDoesNotExist.selector)
        );
        counter.tokenURI(1);
    }

    function scanFor(Attribute memory attr, Attribute[] memory attrs)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < attrs.length; i++) {
            Attribute memory compare = attrs[i];
            if (
                stringEq(attr.trait_type, compare.trait_type)
                    && stringEq(attr.value, attrs[i].value)
            ) {
                return true;
            }
        }
        return false;
    }

    function stringEq(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    // function testStringURI2() public {
    //     string memory data = "";
    //     (address predicted, bytes32 validationHash) =
    //         getPredictedAndValidationHash(address(this), data, 0);

    //     // mint token
    //     uint256 tokenId = counter.mint(validationHash);
    //     // get json string
    //     vm.breakpoint("a");
    //     string memory stringUri = counter.stringURI(tokenId);
    //     // parse json into struct
    //     bytes memory jsonParsed = vm.parseJson(stringUri);
    //     vm.breakpoint("b");
    //     RevealedMetadata memory metadata =
    //         abi.decode(jsonParsed, (RevealedMetadata));
    //     // // check struct
    //     // assertEq(
    //     //     metadata.animation_url,
    //     //     string.concat(
    //     //         "data:text/plain,",
    //     //         "This Counterfact has not yet been revealed."
    //     //     )
    //     // );
    //     // assertTrue(
    //     //     scanFor(
    //     //         Attribute("Creator",
    // LibString.toHexString(address(this))),
    //     //         metadata.attributes
    //     //     )
    //     // );
    //     // assertTrue(
    //     //     scanFor(
    //     //         Attribute(
    //     //             "Validation Hash",
    //     //             LibString.toHexString(uint256(validationHash))
    //     //         ),
    //     //         metadata.attributes
    //     //     )
    //     // );
    //     // assertTrue(scanFor(Attribute("Revealed?", "No"),
    //     // metadata.attributes));

    //     // data = 'data "with quotes"';
    //     // (predicted, validationHash) =
    //     //     getPredictedAndValidationHash(address(this), data, 0);
    //     // tokenId = counter.mint(validationHash);
    //     // counter.reveal(tokenId, data, 0);
    //     // assertEq(
    //     //     counter.stringURI(tokenId),
    //     //     _generateString(data, address(this), predicted,
    // validationHash)
    //     // );
    //     // vm.parseJson
    // }

    function getPredictedAndValidationHash(
        address creator,
        string memory data,
        uint96 salt
    ) internal view returns (address, bytes32) {
        address predicted = counter.predict(data, creator, salt);
        bytes32 validationHash = keccak256(abi.encode(predicted, creator));
        return (predicted, validationHash);
    }

    // function testTokenURI() public {
    //     uint256 tokenId = counter.mint(address(1234));
    //     assertEq(
    //         counter.tokenURI(tokenId),
    //         _generateBase64("", address(this), address(1234))
    //     );

    //     string memory data = 'data "with quotes"';
    //     address predicted = counter.predict(data, bytes32(0));
    //     tokenId = counter.mint(predicted);
    //     counter.reveal(tokenId, data, bytes32(0));
    //     assertEq(
    //         counter.tokenURI(tokenId),
    //         _generateBase64(data, address(this), predicted)
    //     );
    // }

    // function _generateBase64(
    //     string memory data,
    //     address creator,
    //     address dataContract
    // ) internal pure returns (string memory) {
    //     return string.concat(
    //         "data:application/json;base64,",
    //         Base64.encode(bytes(_generateString(data, creator,
    // dataContract)))
    //     );
    // }

    function _generateString(
        string memory data,
        address creator,
        address dataContract,
        bytes32 validationHash
    ) internal pure returns (string memory) {
        if (bytes(data).length > 0) {
            data = LibString.concat(
                "data:text/plain,",
                LibString.escapeJSON(LibString.escapeHTML(data))
            );
        } else {
            data = LibString.concat(
                "data:text/plain,",
                "This Counterfact has not yet been revealed."
            );
        }
        string memory thing = string.concat(
            '{"animation_url":"',
            data,
            '","attributes":[{"trait_type":"Creator","value":"',
            LibString.toHexString(creator),
            '"},{"trait_type":"Data Contract","value":"',
            LibString.toHexString(dataContract),
            '"}]}'
        );
        if (dataContract != address(0)) {
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

    function testSimple() public {
        string memory jsonString =
            '{"trait_type":"Creator","value":"b0x4a5439f888367f1c42c1659f25004838e80472d70cf0947a26f4f3e31337d8b5"}';
        bytes memory jsonBytes = vm.parseJson(jsonString);
        emit log_string(string(jsonBytes));
        Attribute memory attr = abi.decode(jsonBytes, (Attribute));
        logAttr(attr);

        jsonString =
            '[{"trait_type":"Creator","value":"hello"},{"trait_type":"Creator","value":"hello2"}]';
        jsonBytes = vm.parseJson(jsonString);
        Attribute[] memory attrs = abi.decode(jsonBytes, (Attribute[]));

        // jsonString = string.concat(
        //     '{"animation_url":"hello","attributes":', jsonString, "}"
        // );
        // jsonBytes = vm.parseJson(jsonString);
        // RevealedMetadata memory metadata =
        //     abi.decode(jsonBytes, (RevealedMetadata));
    }

    function logAttr(Attribute memory attr) public {
        emit log_named_string("trait_type", attr.trait_type);
        emit log_named_string("value", attr.value);
    }
    // function testSneaky() public {
    //     uint256 tokenId = counter.mint(address(1234));
    //     counter.setDataContract(
    //         tokenId,
    //         Counterfacts.DataContract({
    //             dataContract: address(this),
    //             deployed: false
    //         })
    //     );

    //     string memory uri = counter.stringURI(tokenId);
    //     assertEq(
    //         bytes(uri),
    //         '{"animation_url":"data:text/plain,Very
    // sneaky!","attributes":[{"trait_type":"Creator","value":"The
    // Sneakooooor"},{"trait_type":"Data
    // Contract","value":"0x7fa9385be102ac3eac297483dd6233d62b3e1496"},
    // {"trait_type":"Sneaky","value":"Yes"}]}'
    //     );
    // }

    // function testConstructorMint() public {
    //     ConstructorMinter minter = new ConstructorMinter(address(counter));
    //     assertEq(counter.ownerOf(1), address(minter));
    //     assertEq(
    //         bytes(counter.tokenURI(1)),
    //         "data:application/json;base64,eyJhbmltYXRpb25fdXJsIjoiZGF0YTp0ZXh0L3BsYWluLFZlcnkgc25lYWt5ISIsImF0dHJpYnV0ZXMiOlt7InRyYWl0X3R5cGUiOiJDcmVhdG9yIiwidmFsdWUiOiJUaGUgU25lYWtvb29vb3IifSx7InRyYWl0X3R5cGUiOiJEYXRhIENvbnRyYWN0IiwidmFsdWUiOiIweDJlMjM0ZGFlNzVjNzkzZjY3YTM1MDg5YzlkOTkyNDVlMWM1ODQ3MGIifSwgeyJ0cmFpdF90eXBlIjoiU25lYWt5IiwidmFsdWUiOiJZZXMifV19"
    //     );
    // }
}
