// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IVisionToken} from "./IVisionToken.old.sol";

/**
 * @title Common interface for Vision-compatible token contracts that
 * wrap either a blockchain network's native coin or another token
 */
interface IVisionWrapper is IVisionToken {
    /**
     * @notice Wrap the coins or tokens sent to or approved for the
     * wrapper contract.
     *
     * @dev A coin wrapper contract mints exactly the sent amount of
     * coins. A token wrapper contract mints exactly the approved (and
     * then transferred) amount of tokens. In both cases, the newly
     * minted wrapper tokens are credited to the sender's balance.
     */
    function wrap() external payable;

    /**
     * @notice Unwrap the specified amount of coins or tokens.
     *
     * @param amount The amount to unwrap.
     *
     * @dev The specified amount of wrapper tokens is burned and debited
     * to the sender's balance. The exact same amount of original coins
     * or tokens are transferred to the sender.
     */
    function unwrap(uint256 amount) external;

    /**
     * @return True if the wrapped coin or token is native on the
     * blockchain.
     *
     * @dev Only a native coin or token can be wrapped and unwrapped on
     * a blockchain. All other functions of Vision-compatible tokens are
     * available for both native and non-native coins and tokens.
     */
    function isNative() external view returns (bool);
}
