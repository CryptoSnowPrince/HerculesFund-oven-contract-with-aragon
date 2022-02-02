// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

// import "../libraries/LibWeights.sol";
// import "../ReentryProtection.sol";
// import "../libraries/LibAddRemoveToken.sol";
import "../libraries/LibPoolMath.sol";
import "../ReentryProtection.sol";
import "../interfaces/IBPool.sol";
import "../libraries/LibSafeApprove.sol";

import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

contract AdminFacet is ReentryProtection{
  using LibSafeApprove for IERC20;
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
  modifier onlyPublicSwapSetter() {
    require(
      msg.sender == PBStorage.load().publicSwapSetter,
      "PV2SmartPool.onlyPublicSwapSetter: not public swap setter"
    );
    _;
  }
  modifier onlyCircuitBreaker() {
    require(
      msg.sender == P2Storage.load().circuitBreaker,
      "PV2SmartPool.onlyCircuitBreaker: not circuit breaker"
    );
    _;
  }

  event TokensApproved();
  event ControllerChanged(address indexed previousController, address indexed newController);
  event PublicSwapSetterChanged(address indexed previousSetter, address indexed newSetter);
  event TokenBinderChanged(address indexed previousTokenBinder, address indexed newTokenBinder);
  event PublicSwapSet(address indexed setter, bool indexed value);
  event SwapFeeSet(address indexed setter, uint256 newFee);
  event CapChanged(address indexed setter, uint256 oldCap, uint256 newCap);
  event CircuitBreakerTripped();
  event JoinExitEnabledChanged(address indexed setter, bool oldValue, bool newValue);
  event CircuitBreakerChanged(
    address indexed _oldCircuitBreaker,
    address indexed _newCircuitBreaker
  );
  
  // ADMIN FUNCTIONS ------------------------------------------

  /**
      @notice Bind a token to the underlying balancer pool. Can only be called by the token binder
      @param _token Token to bind
      @param _balance Amount to bind
      @param _denorm Denormalised weight
  */
  function bind(
    address _token,
    uint256 _balance,
    uint256 _denorm
  ) external onlyTokenBinder noReentry {
    P2Storage.StorageStruct storage ws = P2Storage.load();
    IBPool bPool = PBStorage.load().bPool;
    IERC20 token = IERC20(_token);
    require(
      token.transferFrom(msg.sender, address(this), _balance),
      "PV2SmartPool.bind: transferFrom failed"
    );
    // Cancel potential weight adjustment process.
    ws.startBlock = 0;
    token.safeApprove(address(bPool), type(uint).max);
    bPool.bind(_token, _balance, _denorm);
  }

  /**
      @notice Rebind a token to the pool
      @param _token Token to bind
      @param _balance Amount to bind
      @param _denorm Denormalised weight
  */
  function rebind(
    address _token,
    uint256 _balance,
    uint256 _denorm
  ) external onlyTokenBinder noReentry {
    P2Storage.StorageStruct storage ws = P2Storage.load();
    IBPool bPool = PBStorage.load().bPool;
    IERC20 token = IERC20(_token);

    // gulp old non acounted for token balance in the contract
    bPool.gulp(_token);

    uint256 oldBalance = token.balanceOf(address(bPool));
    // If tokens need to be pulled from msg.sender
    if (_balance > oldBalance) {
      require(
        token.transferFrom(msg.sender, address(this), _balance - oldBalance),
        "PV2SmartPool.rebind: transferFrom failed"
      );
      token.safeApprove(address(bPool), type(uint).max);
    }

    bPool.rebind(_token, _balance, _denorm);
    // Cancel potential weight adjustment process.
    ws.startBlock = 0;
    // If any tokens are in this contract send them to msg.sender
    uint256 tokenBalance = token.balanceOf(address(this));
    if (tokenBalance > 0) {
      require(token.transfer(msg.sender, tokenBalance), "PV2SmartPool.rebind: transfer failed");
    }
  }

  /**
      @notice Unbind a token
      @param _token Token to unbind
  */
  function unbind(address _token) external onlyTokenBinder noReentry {
    P2Storage.StorageStruct storage ws = P2Storage.load();
    IBPool bPool = PBStorage.load().bPool;
    IERC20 token = IERC20(_token);
    // unbind the token in the bPool
    bPool.unbind(_token);

    // Cancel potential weight adjustment process.
    ws.startBlock = 0;

    // If any tokens are in this contract send them to msg.sender
    uint256 tokenBalance = token.balanceOf(address(this));
    if (tokenBalance > 0) {
      require(token.transfer(msg.sender, tokenBalance), "PV2SmartPool.unbind: transfer failed");
    }
  }

  /**
      @notice Sets the controller address. Can only be set by the current controller
      @param _controller Address of the new controller
  */
  function setController(address _controller) external onlyController noReentry {
    emit ControllerChanged(PBStorage.load().controller, _controller);
    PBStorage.load().controller = _controller;
  }

  /**
      @notice Sets public swap setter address. Can only be set by the controller
      @param _newPublicSwapSetter Address of the new public swap setter
  */
  function setPublicSwapSetter(address _newPublicSwapSetter)
    external
    onlyController
    noReentry
  {
    emit PublicSwapSetterChanged(PBStorage.load().publicSwapSetter, _newPublicSwapSetter);
    PBStorage.load().publicSwapSetter = _newPublicSwapSetter;
  }

  /**
      @notice Sets the token binder address. Can only be set by the controller
      @param _newTokenBinder Address of the new token binder
  */
  function setTokenBinder(address _newTokenBinder) external onlyController noReentry {
    emit TokenBinderChanged(PBStorage.load().tokenBinder, _newTokenBinder);
    PBStorage.load().tokenBinder = _newTokenBinder;
  }

  /**
      @notice Enables or disables public swapping on the underlying balancer pool.
              Can only be set by the controller.
      @param _public Public or not
  */
  function setPublicSwap(bool _public) external onlyPublicSwapSetter noReentry {
    emit PublicSwapSet(msg.sender, _public);
    PBStorage.load().bPool.setPublicSwap(_public);
  }

  /**
      @notice Set the swap fee on the underlying balancer pool.
              Can only be called by the controller.
      @param _swapFee The new swap fee
  */
  function setSwapFee(uint256 _swapFee) external onlyController noReentry {
    emit SwapFeeSet(msg.sender, _swapFee);
    PBStorage.load().bPool.setSwapFee(_swapFee);
  }

  /**
      @notice Set the maximum cap of the contract
      @param _cap New cap in wei
  */
  function setCap(uint256 _cap) external onlyController noReentry {
    emit CapChanged(msg.sender, PCSStorage.load().cap, _cap);
    PCSStorage.load().cap = _cap;
  }

  /**
    @notice Enable or disable joining and exiting
    @param _newValue enabled or not
  */
  function setJoinExitEnabled(bool _newValue) external onlyController noReentry {
    emit JoinExitEnabledChanged(msg.sender, P2Storage.load().joinExitEnabled, _newValue);
    P2Storage.load().joinExitEnabled = _newValue;
  }

  /**
    @notice Set the circuit breaker address. Can only be called by the controller
    @param _newCircuitBreaker Address of the new circuit breaker
  */
  function setCircuitBreaker(
    address _newCircuitBreaker
  ) external onlyController noReentry {
    emit CircuitBreakerChanged(P2Storage.load().circuitBreaker, _newCircuitBreaker);
    P2Storage.load().circuitBreaker = _newCircuitBreaker;
  }

  /**
    @notice Set the annual fee. Can only be called by the controller
    @param _newFee new fee 10**18 == 100% per 365 days. Max 10%
  */
  function setAnnualFee(uint256 _newFee) external onlyController noReentry {
    LibFees.setAnnualFee(_newFee);
  }

  /**
    @notice Charge the outstanding annual fee
  */
  function chargeOutstandingAnnualFee() external noReentry {
    LibFees.chargeOutstandingAnnualFee();
  }

  /**
    @notice Set the address that receives the annual fee. Can only be called by the controller
  */
  function setFeeRecipient(address _newRecipient) external onlyController noReentry {
    LibFees.setFeeRecipient(_newRecipient);
  }

  /**
    @notice Trip the circuit breaker which disabled exit, join and swaps
  */
  function tripCircuitBreaker() external onlyCircuitBreaker {
    P2Storage.load().joinExitEnabled = false;
    PBStorage.load().bPool.setPublicSwap(false);
    emit CircuitBreakerTripped();
  }
}