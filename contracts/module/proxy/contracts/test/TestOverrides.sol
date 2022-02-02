// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract TestOverrides {

    string public value;
    string public value1;

    function doesOverride(bytes4 _selector) public pure returns (bool) {
        if(
            _selector == this.name.selector ||
            _selector == this.symbol.selector ||
            _selector == this.setValue1.selector
        ) {
            return true;
        }

        return false;
    }

    function name() public pure returns (string memory) {
        return "TOKEN_NAME";
    }

    function symbol() public pure returns (string memory) {
        return "SYMBOL";
    }

    function setValue1() public {
        value1 = "OVERWRITTEN";
    }

}