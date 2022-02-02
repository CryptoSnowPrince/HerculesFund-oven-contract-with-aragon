// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IBPool.sol";

library PBasicSmartPoolStorage {
  bytes32 public constant pbsSlot = keccak256("PBasicSmartPool.storage.location");

  struct StorageStruct {
    IBPool bPool;
    address controller;
    address publicSwapSetter;
    address tokenBinder;
  }

  /**
        @notice Load PBasicPool storage
        @return s Pointer to the storage struct
    */
  function load() internal pure returns (StorageStruct storage s) {
    bytes32 loc = pbsSlot;
    assembly {
      s.slot := loc
    }
  }
}
