// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IVisionRegistry} from "./IVisionRegistry.sol";
import {IVisionTransfer} from "./IVisionTransfer.sol";

/**
 * @title Vision Hub interface
 *
 * @notice The Vision hub connects all on-chain (forwarder, tokens) and
 * off-chain (clients, service nodes, validator nodes) components of the
 * Vision multi-blockchain system.
 *
 * @dev The interface declares all Vision hub events and functions for token
 * owners, clients, service nodes, validator nodes, Vision roles, and
 * other interested external users.
 */
interface IVisionHub is IVisionTransfer, IVisionRegistry {}
