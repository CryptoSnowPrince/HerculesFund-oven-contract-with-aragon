// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

pragma solidity ^0.8.9;

import "../interfaces/IPV2SmartPool.sol";
import "../interfaces/IBPool.sol";
import "../PCToken.sol";
import "../ReentryProtection.sol";

import "../libraries/LibSafeApprove.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";
import {PCappedSmartPoolStorage as PCSStorage} from "../storage/PCappedSmartPoolStorage.sol";
import {PV2SmartPoolStorage as P2Storage} from "../storage/PV2SmartPoolStorage.sol";

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

contract PV2SmartPool is PCToken, ReentryProtection {
  using LibSafeApprove for IERC20;

  bool setCutable = true;

  modifier onlyOnce() {
    require(LibDiamond.contractOwner() == address(0) || LibDiamond.contractOwner() == msg.sender, "Diamond not setCutable.");
    _;
  }

  // constructor (address _diamondCutFacet, address _contractOwner) {
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

  function setCut (address _diamondCutFacet, address _contractOwner) public onlyOnce {
    LibDiamond.setContractOwner(_contractOwner);
    // Add the diamondCut external function from the diamondCutFacet
    IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
    bytes4[] memory functionSelectors = new bytes4[](1);
    functionSelectors[0] = IDiamondCut.diamondCut.selector;
    cut[0] = IDiamondCut.FacetCut({
        facetAddress: _diamondCutFacet,
        action: IDiamondCut.FacetCutAction.Add,
        functionSelectors: functionSelectors
    });
    LibDiamond.diamondCut(cut, address(0), "");
    setCutable = false;
  }

  function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
    uint8 i = 0;
    bytes memory bytesArray = new bytes(64);
    for (i = 0; i < bytesArray.length; i++) {

        uint8 _f = uint8(_bytes32[i/2] & 0x0f);
        uint8 _l = uint8(_bytes32[i/2] >> 4);

        bytesArray[i] = toByte(_f);
        i = i + 1;
        bytesArray[i] = toByte(_l);
    }
    return string(bytesArray);
  }

  function toByte(uint8 _uint8) public pure returns (bytes1) {
    if(_uint8 < 10) {
        return bytes1(_uint8 + 48);
    } else {
        return bytes1(_uint8 + 87);
    }
  }

  function append(string memory a, string memory b) internal pure returns (string memory) {

    return string(abi.encodePacked(a, b));

  }

  // Find facet for function that is called and execute the
  // function if a facet is found and return any value.
  fallback() external payable {
    LibDiamond.DiamondStorage storage ds;
    bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
    // get diamond storage
    assembly {
      ds.slot := position
    }
    // get facet from function selector
    address facet = ds.facetAddressAndSelectorPosition[msg.sig].facetAddress;
    string memory converted = bytes32ToString(msg.sig);
    require(facet != address(0), append("Diamond: Function does not exist, sig:", converted));
    // Execute external function from facet using delegatecall and return any value.
    assembly {
      // copy function selector and any arguments
      calldatacopy(0, 0, calldatasize())
        // execute function call using the facet
      let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
      // get any return value
      returndatacopy(0, 0, returndatasize())
      // return any return value or error back to the caller
      switch result
        case 0 {
            revert(0, returndatasize())
        }
        default {
            return(0, returndatasize())
        }
    }
  }

  receive() external payable {}
}
