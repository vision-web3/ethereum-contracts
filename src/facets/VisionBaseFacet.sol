// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";

import {VisionHubStorage} from "../VisionHubStorage.sol";
import {VisionRoles} from "../access/VisionRoles.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";

/**
 * @notice Base class for all Vision-Hub-related facets which shares 
 * VisionHubStorage (App Storage pattern for Diamond Proxy implementation).
 * It also has common modifiers and internal functions used by the facets.

 * @dev Should not have any public methods or else inheriting facets will
 * duplicate methods accidentally. App storage VisionHubStorage declaration 
 * should be the first thing.
 */
abstract contract VisionBaseFacet {
    // Application of the App Storage pattern
    // slither-disable-next-line uninitialized-state
    VisionHubStorage internal s;
    /**
     * @notice Modifier which makes sure that only a transaction from the
     * Vision Hub deployer role is allowed or the contract is not paused.
     */
    modifier superCriticalOpsOrNotPaused() {
        if (s.paused) {
            LibAccessControl.AccessControlStorage
                storage acs = LibAccessControl.accessControlStorage();
            require(
                acs.accessController.hasRole(
                    VisionRoles.SUPER_CRITICAL_OPS,
                    msg.sender
                ),
                "VisionHub: caller doesn't have role"
            );
        }
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from
     * the primary validator node is allowed.
     */
    modifier onlyPrimaryValidatorNode() {
        require(
            msg.sender == s.primaryValidatorNodeAddress,
            "VisionHub: caller is not the primary validator node"
        );
        _;
    }

    /**
     * @notice Modifier which makes sure that a transaction is allowed
     * only if the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!s.paused, "VisionHub: paused");
        _;
    }

    /**
     * @notice Modifier which makes sure that a transaction is allowed only
     * if the contract is paused.
     */
    modifier whenPaused() {
        require(s.paused, "VisionHub: not paused");
        _;
    }

    modifier onlyRole(bytes32 _role) {
        LibAccessControl.AccessControlStorage storage acs = LibAccessControl
            .accessControlStorage();
        require(
            acs.accessController.hasRole(_role, msg.sender),
            "VisionHub: caller doesn't have role"
        );
        _;
    }
}
