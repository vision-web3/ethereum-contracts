// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {VisionRoles} from "./VisionRoles.sol";

/**
 * @title Access controller
 *
 * @notice Access control contract to manage Vision roles and permissions.
 */
contract AccessController is AccessControl {
    address public immutable pauser;
    address public immutable deployer;
    address public immutable mediumCriticalOps;
    address public immutable superCriticalOps;

    /**
     * @notice Initialize access controller with roles.
     *
     * @param pauser_ Address of the pauser role.
     * @param deployer_ Address of the deployer role.
     * @param mediumCriticalOps_ Address of the medium critical operations role.
     * @param superCriticalOps_ Address of the super critical operations role.
     */
    constructor(
        address pauser_,
        address deployer_,
        address mediumCriticalOps_,
        address superCriticalOps_
    ) {
        require(
            pauser_ != address(0),
            "AccessController: pauser must not be the zero account"
        );
        require(
            deployer_ != address(0),
            "AccessController: deployer must not be the zero account"
        );
        require(
            mediumCriticalOps_ != address(0),
            "AccessController: mediumCriticalOps must not be the zero account"
        );
        require(
            superCriticalOps_ != address(0),
            "AccessController: superCriticalOps must not be the zero account"
        );
        pauser = pauser_;
        deployer = deployer_;
        mediumCriticalOps = mediumCriticalOps_;
        superCriticalOps = superCriticalOps_;

        _grantRole(VisionRoles.PAUSER_ROLE, pauser);
        _grantRole(VisionRoles.DEPLOYER_ROLE, deployer);
        _grantRole(VisionRoles.MEDIUM_CRITICAL_OPS_ROLE, mediumCriticalOps);
        _grantRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE, superCriticalOps);
    }
}
