// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

import {ReentryProtection} from "../ReentryProtection.sol";

import {LibPoolEntryJoin} from "../libraries/LibPoolEntryJoin.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

contract PoolEntryFacet is ReentryProtection {

  modifier ready() {
    require(address(PBStorage.load().bPool) != address(0), "PV2SmartPool.ready: not ready");
    _;
  }

  modifier onlyController() {
    require(
      msg.sender == PBStorage.load().controller,
      "PV2SmartPool.onlyController: not controller"
    );
    _;
  }

  modifier onlyPublicSwap() {
    require(
      PBStorage.load().bPool.isPublicSwap(),
      "PV2SmartPool.onlyPublicSwap: swapping not enabled"
    );
    _;
  }

  modifier onlyJoinExitEnabled() {
    require(
      P2Storage.load().joinExitEnabled,
      "PV2SmartPool.onlyJoinExitEnabled: join and exit not enabled"
    );
    _;
  }

  modifier withinCap() {
    _;
    require(PCSStorage.load().cap < PCSStorage.load().cap, "PV2SmartPool.withinCap: Cap limit");
  }

  // POOL ENTRY -----------------------------------------------
  /**
        @notice Takes underlying assets and mints smart pool tokens. Enforces the cap
        @param _amount Amount of pool tokens to mint
    */
  function joinPool(uint256 _amount)
    external
    withinCap
    ready
    noReentry
    onlyJoinExitEnabled
  {
    LibPoolEntryJoin.joinPool(_amount);
  }

  /**
      @notice Takes underlying assets and mints smart pool tokens.
      Enforces the cap. Allows you to specify the maximum amounts of underlying assets
      @param _amount Amount of pool tokens to mint
  */
  function joinPool(uint256 _amount, uint256[] calldata _maxAmountsIn)
    external
    withinCap
    ready
    noReentry
    onlyJoinExitEnabled
  {
    LibPoolEntryJoin.joinPool(_amount, _maxAmountsIn);
  }

  /**
        @notice Joinswap single asset pool entry given token amount in
        @param _token Address of entry token
        @param _amountIn Amount of entry tokens
        @return poolAmountOut
    */
  function joinswapExternAmountIn(
    address _token,
    uint256 _amountIn,
    uint256 _minPoolAmountOut
  )
    external
    ready
    withinCap
    onlyPublicSwap
    noReentry
    onlyJoinExitEnabled
    returns (uint256 poolAmountOut)
  {
    return LibPoolEntryJoin.joinswapExternAmountIn(_token, _amountIn, _minPoolAmountOut);
  }

  /**
        @notice Joinswap single asset pool entry given pool amount out
        @param _token Address of entry token
        @param _amountOut Amount of entry tokens to deposit into the pool
        @return tokenAmountIn
    */
  function joinswapPoolAmountOut(
    address _token,
    uint256 _amountOut,
    uint256 _maxAmountIn
  )
    external
    ready
    withinCap
    onlyPublicSwap
    noReentry
    onlyJoinExitEnabled
    returns (uint256 tokenAmountIn)
  {
    return LibPoolEntryJoin.joinswapPoolAmountOut(_token, _amountOut, _maxAmountIn);
  }
}