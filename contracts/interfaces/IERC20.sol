// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IERC20 {

  function totalSupply() external view returns (uint256);

  function balanceOf(address _whom) external view returns (uint256);

  function allowance(address _src, address _dst) external view returns (uint256);

  function approve(address _dst, uint256 _amount) external returns (bool);

  function transfer(address _dst, uint256 _amount) external returns (bool);

  function transferFrom(
    address _src,
    address _dst,
    uint256 _amount
  ) external returns (bool);
}
