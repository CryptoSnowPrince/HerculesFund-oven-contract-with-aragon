// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library PV2SmartPoolStorage {
  bytes32 public constant pasSlot = keccak256("PV2SmartPoolStorage.storage.location");

  struct StorageStruct {
    uint256 startBlock;
    uint256 endBlock;
    uint256[] startWeights;
    uint256[] newWeights;
    NewToken newToken;
    bool joinExitEnabled;
    uint256 annualFee;
    uint256 lastAnnualFeeClaimed;
    address feeRecipient;
    address circuitBreaker;
  }

  struct NewToken {
    address addr;
    bool isCommitted;
    uint256 balance;
    uint256 denorm;
    uint256 commitBlock;
  }

  function load() internal pure returns (StorageStruct storage s) {
    bytes32 loc = pasSlot;
    assembly {
      s.slot := loc
    }
  }
}
