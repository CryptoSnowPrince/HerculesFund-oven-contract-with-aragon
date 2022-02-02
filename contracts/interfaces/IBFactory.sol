// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBFactory {
  function newBPool() external returns (address);
}
