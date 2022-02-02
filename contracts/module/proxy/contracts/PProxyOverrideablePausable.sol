// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./PProxyOverrideable.sol";
import "./PProxyPausable.sol";

contract PProxyOverrideablePausable is PProxyOverrideable, PProxyPausable {
    function internalFallback() internal override(PProxyOverrideable, PProxyPausable) notPaused {
        PProxyOverrideable.internalFallback();
    }
}