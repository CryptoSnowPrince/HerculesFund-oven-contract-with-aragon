// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IPProxyOverrides {
    function doesOverride(bytes4 _selector) external view returns (bool);
}