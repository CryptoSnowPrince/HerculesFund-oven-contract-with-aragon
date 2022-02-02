// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";
import "./LibFees.sol";

import "./LibPoolToken.sol";
import "./LibUnderlying.sol";
import "./Math.sol";

library LibPoolEntryJoin {

  using Math for uint256;
  event LOG_JOIN(address indexed caller, address indexed tokenIn, uint256 tokenAmountIn);
  event PoolJoined(address indexed from, uint256 amount);

  modifier lockBPoolSwap() {
    IBPool bPool = PBStorage.load().bPool;
    if(bPool.isPublicSwap()) {
      // If public swap is enabled turn it of, execute function and turn it off again
      bPool.setPublicSwap(false);
      _;
      bPool.setPublicSwap(true);
    } else {
      // If public swap is not enabled just execute
      _;
    }
  }

function joinPool(uint256 _amount) external {
  IBPool bPool = PBStorage.load().bPool;
  uint256[] memory maxAmountsIn = new uint256[](bPool.getCurrentTokens().length);
  for (uint256 i = 0; i < maxAmountsIn.length; i++) {
    maxAmountsIn[i] = type(uint).max;
  }
  _joinPool(_amount, maxAmountsIn);
  }

  function joinPool(uint256 _amount, uint256[] calldata _maxAmountsIn) external {
    _joinPool(_amount, _maxAmountsIn);
  }

  function _joinPool(uint256 _amount, uint256[] memory _maxAmountsIn) internal lockBPoolSwap {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    uint256 poolTotal = PCStorage.load().totalSupply;
    uint256 ratio = _amount.bdiv(poolTotal);
    require(ratio != 0);

    address[] memory tokens = bPool.getCurrentTokens();

    for (uint256 i = 0; i < tokens.length; i++) {
      address t = tokens[i];
      uint256 bal = bPool.getBalance(t);
      uint256 tokenAmountIn = ratio.bmul(bal);
      require(
        tokenAmountIn <= _maxAmountsIn[i],
        "LibPoolEntryExit.joinPool: Token in amount too big"
      );
      emit LOG_JOIN(msg.sender, t, tokenAmountIn);
      LibUnderlying._pullUnderlying(t, msg.sender, tokenAmountIn, bal);
    }
    LibPoolToken._mint(msg.sender, _amount);
    emit PoolJoined(msg.sender, _amount);
  }

  function joinswapExternAmountIn(
    address _token,
    uint256 _amountIn,
    uint256 _minPoolAmountOut
  ) external lockBPoolSwap returns (uint256 poolAmountOut)  {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    require(bPool.isBound(_token), "LibPoolEntryExit.joinswapExternAmountIn: Token Not Bound");

    poolAmountOut = bPool.calcPoolOutGivenSingleIn(
      bPool.getBalance(_token),
      bPool.getDenormalizedWeight(_token),
      PCStorage.load().totalSupply,
      bPool.getTotalDenormalizedWeight(),
      _amountIn,
      bPool.getSwapFee()
    );

    require(
      poolAmountOut >= _minPoolAmountOut,
      "LibPoolEntryExit.joinswapExternAmountIn: Insufficient pool amount out"
    );

    emit LOG_JOIN(msg.sender, _token, _amountIn);

    LibPoolToken._mint(msg.sender, poolAmountOut);

    emit PoolJoined(msg.sender, poolAmountOut);

    uint256 bal = bPool.getBalance(_token);
    LibUnderlying._pullUnderlying(_token, msg.sender, _amountIn, bal);

    return poolAmountOut;
  }

  function joinswapPoolAmountOut(
    address _token,
    uint256 _amountOut,
    uint256 _maxAmountIn
  ) external lockBPoolSwap returns (uint256 tokenAmountIn) {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    require(bPool.isBound(_token), "LibPoolEntryExit.joinswapPoolAmountOut: Token Not Bound");

    tokenAmountIn = bPool.calcSingleInGivenPoolOut(
      bPool.getBalance(_token),
      bPool.getDenormalizedWeight(_token),
      PCStorage.load().totalSupply,
      bPool.getTotalDenormalizedWeight(),
      _amountOut,
      bPool.getSwapFee()
    );

    require(
      tokenAmountIn <= _maxAmountIn,
      "LibPoolEntryExit.joinswapPoolAmountOut: Token amount in too big"
    );

    emit LOG_JOIN(msg.sender, _token, tokenAmountIn);

    LibPoolToken._mint(msg.sender, _amountOut);

    emit PoolJoined(msg.sender, _amountOut);

    uint256 bal = bPool.getBalance(_token);
    LibUnderlying._pullUnderlying(_token, msg.sender, tokenAmountIn, bal);

    return tokenAmountIn;
  }
}