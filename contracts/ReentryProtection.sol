// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {ReentryProtectionStorage as RPStorage} from "./storage/ReentryProtectionStorage.sol";

contract ReentryProtection {

  modifier noReentry {
    // Use counter to only write to storage once
    RPStorage.StorageStruct storage s = RPStorage.load();
    s.lockCounter++;
    uint256 lockValue = s.lockCounter;
    _;
    require(lockValue == s.lockCounter, "ReentryProtection.noReentry: reentry detected");
  }

}
