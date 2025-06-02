// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";

import {VisionRoles} from "../access/VisionRoles.sol";
import {VisionBaseFacet} from "./VisionBaseFacet.sol";

/**
 * @title DiamondCutFacet
 *
 * @notice Add/replace/remove any number of functions and optionally execute
 * a function with delegatecall.
 */
contract DiamondCutFacet is IDiamondCut, VisionBaseFacet {
    /**
     * @param diamondCut_ Contains the facet addresses and function selectors
     * @param init_ The address of the contract or facet to execute _calldata
     * @param calldata_ A function call, including function selector and arguments
     */
    function diamondCut(
        FacetCut[] calldata diamondCut_,
        address init_,
        bytes calldata calldata_
    ) external override onlyRole(VisionRoles.DEPLOYER_ROLE) {
        LibDiamond.diamondCut(diamondCut_, init_, calldata_);
    }
}
