// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../ReentryProtection.sol";

contract TestReentryProtection is ReentryProtection {
  // This should fail
  function test() external noReentry {
    reenter();
  }

  function reenter() public noReentry {
    // Do nothing
  }
}
