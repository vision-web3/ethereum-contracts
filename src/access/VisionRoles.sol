// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

/**
 * @title Vision roles
 *
 * @notice Vision roles defined as bytes32 constants.
 */
library VisionRoles {
    // Access Control Roles
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 internal constant MEDIUM_CRITICAL_OPS_ROLE =
        keccak256("MEDIUM_CRITICAL_OPS_ROLE");
    bytes32 internal constant SUPER_CRITICAL_OPS_ROLE =
        keccak256("SUPER_CRITICAL_OPS_ROLE");
}
