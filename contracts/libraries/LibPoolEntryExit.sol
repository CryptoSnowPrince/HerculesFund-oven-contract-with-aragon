// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";
import "./LibFees.sol";

import "./LibPoolToken.sol";
import "./LibUnderlying.sol";
import "./Math.sol";

library LibPoolEntryExit {
  using Math for uint256;

  event LOG_EXIT(address indexed caller, address indexed tokenOut, uint256 tokenAmountOut);
  event PoolExited(address indexed from, uint256 amount);
  event PoolExitedWithLoss(address indexed from, uint256 amount, address[] lossTokens);
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

  function exitPool(uint256 _amount) internal {
    IBPool bPool = PBStorage.load().bPool;
    uint256[] memory minAmountsOut = new uint256[](bPool.getCurrentTokens().length);
    _exitPool(_amount, minAmountsOut);
  }

  function exitPool(uint256 _amount, uint256[] calldata _minAmountsOut) external {
    _exitPool(_amount, _minAmountsOut);
  }

  function _exitPool(uint256 _amount, uint256[] memory _minAmountsOut) internal lockBPoolSwap {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    uint256 poolTotal = PCStorage.load().totalSupply;
    uint256 ratio = _amount.bdiv(poolTotal);
    require(ratio != 0);

    LibPoolToken._burn(msg.sender, _amount);

    address[] memory tokens = bPool.getCurrentTokens();

    for (uint256 i = 0; i < tokens.length; i++) {
      address token = tokens[i];
      uint256 balance = bPool.getBalance(token);
      uint256 tokenAmountOut = ratio.bmul(balance);

      require(
        tokenAmountOut >= _minAmountsOut[i],
        "LibPoolEntryExit.exitPool: Token amount out too small"
      );

      emit LOG_EXIT(msg.sender, token, tokenAmountOut);
      LibUnderlying._pushUnderlying(token, msg.sender, tokenAmountOut, balance);
    }
    emit PoolExited(msg.sender, _amount);
  }

  function exitswapPoolAmountIn(
    address _token,
    uint256 _poolAmountIn,
    uint256 _minAmountOut
  ) external lockBPoolSwap returns (uint256 tokenAmountOut) {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    require(bPool.isBound(_token), "LibPoolEntryExit.exitswapPoolAmountIn: Token Not Bound");

    tokenAmountOut = bPool.calcSingleOutGivenPoolIn(
      bPool.getBalance(_token),
      bPool.getDenormalizedWeight(_token),
      PCStorage.load().totalSupply,
      bPool.getTotalDenormalizedWeight(),
      _poolAmountIn,
      bPool.getSwapFee()
    );

    require(
      tokenAmountOut >= _minAmountOut,
      "LibPoolEntryExit.exitswapPoolAmountIn: Token Not Bound"
    );

    emit LOG_EXIT(msg.sender, _token, tokenAmountOut);

    LibPoolToken._burn(msg.sender, _poolAmountIn);

    emit PoolExited(msg.sender, tokenAmountOut);

    uint256 bal = bPool.getBalance(_token);
    LibUnderlying._pushUnderlying(_token, msg.sender, tokenAmountOut, bal);

    return tokenAmountOut;
  }

  function exitswapExternAmountOut(
    address _token,
    uint256 _tokenAmountOut,
    uint256 _maxPoolAmountIn
  ) internal lockBPoolSwap returns (uint256 poolAmountIn) {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    require(bPool.isBound(_token), "LibPoolEntryExit.exitswapExternAmountOut: Token Not Bound");

    poolAmountIn = bPool.calcPoolInGivenSingleOut(
      bPool.getBalance(_token),
      bPool.getDenormalizedWeight(_token),
      PCStorage.load().totalSupply,
      bPool.getTotalDenormalizedWeight(),
      _tokenAmountOut,
      bPool.getSwapFee()
    );

    require(
      poolAmountIn <= _maxPoolAmountIn,
      "LibPoolEntryExit.exitswapExternAmountOut: pool amount in too large"
    );

    emit LOG_EXIT(msg.sender, _token, _tokenAmountOut);

    LibPoolToken._burn(msg.sender, poolAmountIn);

    emit PoolExited(msg.sender, _tokenAmountOut);

    uint256 bal = bPool.getBalance(_token);
    LibUnderlying._pushUnderlying(_token, msg.sender, _tokenAmountOut, bal);

    return poolAmountIn;
  }

  function exitPoolTakingloss(uint256 _amount, address[] calldata _lossTokens)
    external
    lockBPoolSwap
  {
    IBPool bPool = PBStorage.load().bPool;
    LibFees.chargeOutstandingAnnualFee();
    uint256 poolTotal = PCStorage.load().totalSupply;
    uint256 ratio = _amount.bdiv(poolTotal);
    require(ratio != 0);

    LibPoolToken._burn(msg.sender, _amount);

    address[] memory tokens = bPool.getCurrentTokens();

    for (uint256 i = 0; i < tokens.length; i++) {
      // If taking loss on token skip one iteration of the loop
      if (_contains(tokens[i], _lossTokens)) {
        continue;
      }
      address t = tokens[i];
      uint256 bal = bPool.getBalance(t);
      uint256 tAo = ratio.bmul(bal);
      emit LOG_EXIT(msg.sender, t, tAo);
      LibUnderlying._pushUnderlying(t, msg.sender, tAo, bal);
    }
    emit PoolExitedWithLoss(msg.sender, _amount, _lossTokens);
  }

  /**
        @notice Searches for an address in an array of addresses and returns if found
        @param _needle Address to look for
        @param _haystack Array to search
        @return If value is found
    */
  function _contains(address _needle, address[] memory _haystack) internal pure returns (bool) {
    for (uint256 i = 0; i < _haystack.length; i++) {
      if (_haystack[i] == _needle) {
        return true;
      }
    }
    return false;
  }

}
