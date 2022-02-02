// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

import {ReentryProtection} from "../ReentryProtection.sol";

import {LibPoolEntryExit} from "../libraries/LibPoolEntryExit.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

contract PoolExitFacet is ReentryProtection {

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
    require(PCSStorage.load().cap < PCSStorage.load().cap, "PV2SmartPool.withinCap: Cap limit reached");
  }

  // POOL EXIT ------------------------------------------------

  /**
        @notice Burns pool shares and sends back the underlying assets leaving some in the pool
        @param _amount Amount of pool tokens to burn
        @param _lossTokens Tokens skipped on redemption
    */
  function exitPoolTakingloss(uint256 _amount, address[] calldata _lossTokens)
    external
    ready
    noReentry
    onlyJoinExitEnabled
  {
    LibPoolEntryExit.exitPoolTakingloss(_amount, _lossTokens);
  }

  /**
        @notice Burns pool shares and sends back the underlying assets
        @param _amount Amount of pool tokens to burn
    */
  function exitPool(uint256 _amount) external ready noReentry onlyJoinExitEnabled {
    LibPoolEntryExit.exitPool(_amount);
  }

  /**
    @notice Burn pool tokens and redeem underlying assets. With front running protection
    @param _amount Amount of pool tokens to burn
    @param _minAmountsOut Minimum amounts of underlying assets
  */
  function exitPool(uint256 _amount, uint256[] calldata _minAmountsOut)
    external
    ready
    noReentry
    onlyJoinExitEnabled
  {
    LibPoolEntryExit.exitPool(_amount, _minAmountsOut);
  }

  /**
        @notice Exitswap single asset pool exit given pool amount in
        @param _token Address of exit token
        @param _poolAmountIn Amount of pool tokens sending to the pool
        @return tokenAmountOut amount of exit tokens being withdrawn
    */
  function exitswapPoolAmountIn(
    address _token,
    uint256 _poolAmountIn,
    uint256 _minAmountOut
  )
    external
    ready
    noReentry
    onlyPublicSwap
    onlyJoinExitEnabled
    returns (uint256 tokenAmountOut)
  {
    return LibPoolEntryExit.exitswapPoolAmountIn(_token, _poolAmountIn, _minAmountOut);
  }

  /**
        @notice Exitswap single asset pool entry given token amount out
        @param _token Address of exit token
        @param _tokenAmountOut Amount of exit tokens
        @return poolAmountIn amount of pool tokens being deposited
    */
  function exitswapExternAmountOut(
    address _token,
    uint256 _tokenAmountOut,
    uint256 _maxPoolAmountIn
  )
    external
    ready
    noReentry
    onlyPublicSwap
    onlyJoinExitEnabled
    returns (uint256 poolAmountIn)
  {
    return LibPoolEntryExit.exitswapExternAmountOut(_token, _tokenAmountOut, _maxPoolAmountIn);
  }
}