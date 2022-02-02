// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../PCToken.sol";

contract TestPCToken is PCToken {
  constructor(string memory _name, string memory _symbol) {
    PCStorage.load().name = _name;
    PCStorage.load().symbol = _symbol;
  }

  function mint(address _to, uint256 _amount) external {
    _mint(_amount);
    _push(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external {
    _pull(_from, _amount);
    _burn(_amount);
  }
}
