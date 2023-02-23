// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ConstructorMinter {
    constructor(address target) {
        (bool succ,) =
            target.call(abi.encodeWithSignature("mint(address)", address(this)));
        require(succ);
    }
}
