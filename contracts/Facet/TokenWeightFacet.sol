// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

import {ReentryProtection} from "../ReentryProtection.sol";

import {LibAddRemoveToken} from "../libraries/LibAddRemoveToken.sol";
import {LibWeights} from "../libraries/LibWeights.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

contract TokenWeightFacet is ReentryProtection {

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

// TOKEN AND WEIGHT FUNCTIONS -------------------------------

  /**
    @notice Update the weight of a token. Can only be called by the controller
    @param _token Token to adjust the weight of
    @param _newWeight New denormalized weight
  */
  function updateWeight(address _token, uint256 _newWeight)
    external
    noReentry
    onlyController
  {
    LibWeights.updateWeight(_token, _newWeight);
  }

  /**
    @notice Gradually adjust the weights of a token. Can only be called by the controller
    @param _newWeights Target weights
    @param _startBlock Block to start weight adjustment
    @param _endBlock Block to finish weight adjustment
  */
  function updateWeightsGradually(
    uint256[] calldata _newWeights,
    uint256 _startBlock,
    uint256 _endBlock
  ) external noReentry onlyController {
    LibWeights.updateWeightsGradually(_newWeights, _startBlock, _endBlock);
  }

  /**
    @notice Poke the weight adjustment
  */
  function pokeWeights() external noReentry {
    LibWeights.pokeWeights();
  }

  /**
    @notice Apply the adding of a token. Can only be called by the controller
  */
  function applyAddToken() external noReentry onlyController {
    LibAddRemoveToken.applyAddToken();
  }

  /**
    @notice Commit a token to be added. Can only be called by the controller
    @param _token Address of the token to add
    @param _balance Amount of token to add
    @param _denormalizedWeight Denormalized weight
  */
  function commitAddToken(
    address _token,
    uint256 _balance,
    uint256 _denormalizedWeight
  ) external noReentry onlyController {
    LibAddRemoveToken.commitAddToken(_token, _balance, _denormalizedWeight);
  }

  /**
    @notice Remove a token from the smart pool. Can only be called by the controller
    @param _token Address of the token to remove
  */
  function removeToken(address _token) external noReentry onlyController {
    LibAddRemoveToken.removeToken(_token);
  }
}