// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

import {ReentryProtection} from "../ReentryProtection.sol";

import {LibPoolMath} from "../libraries/LibPoolMath.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

contract ViewFacet is ReentryProtection {

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

  modifier onlyTokenBinder() {
    require(
      msg.sender == PBStorage.load().tokenBinder,
      "PV2SmartPool.onlyTokenBinder: not token binder"
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

  // VIEW FUNCTIONS -------------------------------------------

  /**
        @notice Gets the underlying assets and amounts to mint specific pool shares.
        @param _amount Amount of pool shares to calculate the values for
        @return tokens The addresses of the tokens
        @return amounts The amounts of tokens needed to mint that amount of pool shares
    */
  function calcTokensForAmount(uint256 _amount)
    external
    view
    returns (address[] memory tokens, uint256[] memory amounts)
  {
    return LibPoolMath.calcTokensForAmount(_amount);
  }

  /**
    @notice Calculate the amount of pool tokens out for a given amount in
    @param _token Address of the input token
    @param _amount Amount of input token
    @return Amount of pool token
  */
  function calcPoolOutGivenSingleIn(address _token, uint256 _amount)
    external
    view
    returns (uint256)
  {
    return LibPoolMath.calcPoolOutGivenSingleIn(_token, _amount);
  }

  /**
    @notice Calculate single in given pool out
    @param _token Address of the input token
    @param _amount Amount of pool out token
    @return Amount of token in
  */
  function calcSingleInGivenPoolOut(address _token, uint256 _amount)
    external
    view
    returns (uint256)
  {
    return LibPoolMath.calcSingleInGivenPoolOut(_token, _amount);
  }

  /**
    @notice Calculate single out given pool in
    @param _token Address of output token
    @param _amount Amount of pool in
    @return Amount of token in
  */
  function calcSingleOutGivenPoolIn(address _token, uint256 _amount)
    external
    view
    returns (uint256)
  {
    return LibPoolMath.calcSingleOutGivenPoolIn(_token, _amount);
  }

  /**
    @notice Calculate pool in given single token out
    @param _token Address of output token
    @param _amount Amount of output token
    @return Amount of pool in
  */
  function calcPoolInGivenSingleOut(address _token, uint256 _amount)
    external
    view
    returns (uint256)
  {
    return LibPoolMath.calcPoolInGivenSingleOut(_token, _amount);
  }

  /**
    @notice Get the current tokens in the smart pool
    @return Addresses of the tokens in the smart pool
  */
  function getTokens() external view returns (address[] memory) {
    return PBStorage.load().bPool.getCurrentTokens();
  }

  /**
    @notice Get the address of the controller
    @return The address of the pool
  */
  function getController() external view returns (address) {
    return PBStorage.load().controller;
  }

  /**
    @notice Get the address of the public swap setter
    @return The public swap setter address
  */
  function getPublicSwapSetter() external view returns (address) {
    return PBStorage.load().publicSwapSetter;
  }

  /**
    @notice Get the address of the token binder
    @return The token binder address
  */
  function getTokenBinder() external view returns (address) {
    return PBStorage.load().tokenBinder;
  }

  /**
    @notice Get the address of the circuitBreaker
    @return The address of the circuitBreaker
  */
  function getCircuitBreaker() external view returns (address) {
    return P2Storage.load().circuitBreaker;
  }

  /**
    @notice Get if public swapping is enabled
    @return If public swapping is enabled
  */
  function isPublicSwap() external view returns (bool) {
    return PBStorage.load().bPool.isPublicSwap();
  }

  /**
    @notice Get the current cap
    @return The current cap in wei
  */
  function getCap() external view returns (uint256) {
    return PCSStorage.load().cap;
  }

  function getAnnualFee() external view returns (uint256) {
    return P2Storage.load().annualFee;
  }

  function getFeeRecipient() external view returns (address) {
    return P2Storage.load().feeRecipient;
  }

  /**
    @notice Get the denormalized weight of a specific token in the underlying balancer pool
    @return the normalized weight of the token in uint
  */
  function getDenormalizedWeight(address _token) external view returns (uint256) {
    return PBStorage.load().bPool.getDenormalizedWeight(_token);
  }

  /**
    @notice Get all denormalized weights
    @return weights Denormalized weights
  */
  function getDenormalizedWeights() external view returns (uint256[] memory weights) {
    PBStorage.StorageStruct storage s = PBStorage.load();
    address[] memory tokens = s.bPool.getCurrentTokens();
    weights = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      weights[i] = s.bPool.getDenormalizedWeight(tokens[i]);
    }
  }

  /**
    @notice Get the address of the underlying Balancer pool
    @return The address of the underlying balancer pool
  */
  function getBPool() external view returns (address) {
    return address(PBStorage.load().bPool);
  }

  /**
    @notice Get the current swap fee
    @return The current swap fee
  */
  function getSwapFee() external view returns (uint256) {
    return PBStorage.load().bPool.getSwapFee();
  }

  /**
    @notice Get the target weights
    @return weights Target weights
  */
  function getNewWeights() external view returns (uint256[] memory weights) {
    return P2Storage.load().newWeights;
  }

  /**
    @notice Get weights at start of weight adjustment
    @return weights Start weights
  */
  function getStartWeights() external view returns (uint256[] memory weights) {
    return P2Storage.load().startWeights;
  }

  /**
    @notice Get start block of weight adjustment
    @return Start block
  */
  function getStartBlock() external view returns (uint256) {
    return P2Storage.load().startBlock;
  }

  /**
    @notice Get end block of weight adjustment
    @return End block
  */
  function getEndBlock() external view returns (uint256) {
    return P2Storage.load().endBlock;
  }

  /**
    @notice Get new token being added
    @return New token
  */
  function getNewToken() external view returns (P2Storage.NewToken memory) {
    return P2Storage.load().newToken;
  }

  /**
    @notice Get if joining and exiting is enabled
    @return Enabled or not
  */
  function getJoinExitEnabled() external view returns (bool) {
    return P2Storage.load().joinExitEnabled;
  }
}