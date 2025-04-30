// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IBEP20} from "./IBEP20.sol";

/**
 * @title Vision token interface
 *
 * @notice The IVisionToken contract is an interfance for all Vision token
 * contracts, containing functions which are expected by the Vision
 * multi-blockchain system.
 */
interface IVisionToken is IERC20, IBEP20, IERC165 {
    event VisionForwarderSet(address visionForwarder);

    event VisionForwarderUnset();

    /**
     * @notice Called by the Vision Forwarder to transfer tokens on a
     * blockchain.
     *
     * @param sender The address of the sender of the tokens.
     * @param recipient The address of the recipient of the tokens.
     * @param amount The amount of tokens to mint.
     *
     * @dev The function is only callable by a trusted Vision Forwarder
     * contract and thefore can't be invoked by a user. The function is used
     * to transfer tokens on a blockchain between the sender and recipient.
     *
     * Revert if anything prevents the transfer from happening.
     */
    function visionTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    /**
     * @notice Called by the Vision Forwarder to debit tokens on the source
     * blockchain during a cross-chain transfer.
     *
     * @param sender The address of the sender of the tokens.
     * @param amount The amount of tokens to send/burn.
     *
     * @dev The function is only callable by a trusted Vision Forwarder
     * contract and thefore can't be invoked by a user. The function is used
     * to burn tokens on the source blockchain to initiate a cross-chain
     * transfer.
     *
     * Revert if anything prevents the transfer from happening.
     */
    function visionTransferFrom(address sender, uint256 amount) external;

    /**
     * @notice Called by the Vision Forwarder to mint tokens on the destination
     * blockchain during a cross-chain transfer.
     *
     * @param recipient The address of the recipient of the tokens.
     * @param amount The amount of tokens to mint.
     *
     * @dev The function is only callable by a trusted Vision Forwarder
     * contract and thefore can't be invoked by a user. The function is used
     * to mint tokens on the destination blockchain to finish a cross-chain
     * transfer.
     *
     * Revert if anything prevents the transfer from happening.
     */
    function visionTransferTo(address recipient, uint256 amount) external;

    /**
     * @notice Returns the address of the Vision Forwarder contract.
     *
     * @return Address of the Vision Forwarder.
     *
     */
    function getVisionForwarder() external view returns (address);
}
