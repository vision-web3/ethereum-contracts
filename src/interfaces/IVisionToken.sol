// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IBEP20} from "./IBEP20.sol";
import {IXERC20} from "./IXERC20.sol";
import {IERC7802} from "./IERC7802.sol";

/**
 * @title Vision token interface
 *
 * @notice The IVisionToken contract is an interface for all Vision token
 * contracts, containing functions which are expected by the Vision
 * multi-blockchain system.
 */
interface IVisionToken is IBEP20, IERC20Permit, IERC7802, IXERC20 {} // remove IXERC20
