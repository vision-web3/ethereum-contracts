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
    bytes32 internal constant PAUSER = keccak256("PAUSER");
    bytes32 internal constant DEPLOYER = keccak256("DEPLOYER");
    bytes32 internal constant MEDIUM_CRITICAL_OPS =
        keccak256("MEDIUM_CRITICAL_OPS");
    bytes32 internal constant SUPER_CRITICAL_OPS =
        keccak256("SUPER_CRITICAL_OPS");
}
