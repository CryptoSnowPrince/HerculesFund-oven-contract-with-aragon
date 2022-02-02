// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library PCappedSmartPoolStorage {
  bytes32 public constant pcsSlot = keccak256("PCappedSmartPool.storage.location");

  struct StorageStruct {
    uint256 cap;
  }

  /**
        @notice Load PBasicPool storage
        @return s Pointer to the storage struct
    */
  function load() internal pure returns (StorageStruct storage s) {
    bytes32 loc = pcsSlot;
    assembly {
      s.slot := loc
    }
  }
}
