// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

// import "../libraries/LibWeights.sol";
// import "../ReentryProtection.sol";
// import "../libraries/LibAddRemoveToken.sol";
import "../ReentryProtection.sol";
import "../interfaces/IBPool.sol";
import "../libraries/LibPoolMath.sol";
import "../libraries/LibSafeApprove.sol";

// import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

contract InitFacet is ReentryProtection{
  using LibSafeApprove for IERC20;
  
  event TokensApproved();
  event PublicSwapSet(address indexed setter, bool indexed value);
   
  /**
    @notice Initialises the contract
    @param _bPool Address of the underlying balancer pool
    @param _name Name for the smart pool token
    @param _symbol Symbol for the smart pool token
    @param _initialSupply Initial token supply to mint
  */
  function init(
    address _bPool,
    string memory _name,
    string memory _symbol,
    uint256 _initialSupply
  ) external {
    PBStorage.StorageStruct storage s = PBStorage.load();
    require(address(s.bPool) == address(0), "PV2SmartPool.init: already initialised");
    require(_bPool != address(0), "PV2SmartPool.init: _bPool cannot be 0x00....000");
    require(_initialSupply != 0, "PV2SmartPool.init: _initialSupply can not zero");

    s.bPool = IBPool(_bPool);
    s.controller = msg.sender;
    s.publicSwapSetter = msg.sender;
    s.tokenBinder = msg.sender;
    PCStorage.load().name = _name;
    PCStorage.load().symbol = _symbol;

    LibPoolToken._mint(msg.sender, _initialSupply);
  }

  /**
    @notice Sets approval to all tokens to the underlying balancer pool
    @dev It uses this function to save on gas in joinPool
  */
  function approveTokens() public noReentry {
    IBPool bPool = PBStorage.load().bPool;
    address[] memory tokens = bPool.getCurrentTokens();
    for (uint256 i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).safeApprove(address(bPool), type(uint).max);
    }
    emit TokensApproved();
  }

  // function setCut(
  //   address _diamondCutFacet,
  //   address _contractOwner
  // ) external noReentry {
  //   require(
  //     LibDiamond.diamondStorage().contractOwner == address(0),
  //     "PV2SmartPool.bind: setCut failed"
  //   );
  //   LibDiamond.setContractOwner(_contractOwner);
  //   // Add the diamondCut external function from the diamondCutFacet
  //   IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
  //   bytes4[] memory functionSelectors = new bytes4[](1);
  //   functionSelectors[0] = IDiamondCut.diamondCut.selector;
  //   cut[0] = IDiamondCut.FacetCut({
  //       facetAddress: _diamondCutFacet,
  //       action: IDiamondCut.FacetCutAction.Add,
  //       functionSelectors: functionSelectors
  //   });
  //   LibDiamond.diamondCut(cut, address(0), "");
  // }
}