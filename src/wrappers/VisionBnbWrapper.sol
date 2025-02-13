// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import "../VisionCoinWrapper.sol";

/**
 * @title Vision-compatible token contract that wraps the BNB Chain
 * blockchain network's BNB coin
 */
contract VisionBnbWrapper is VisionCoinWrapper {
    string private constant _NAME = "BNB (Vision)";

    string private constant _SYMBOL = "panBNB";

    uint8 private constant _DECIMALS = 18;

    constructor(
        bool native,
        address accessControllerAddress
    )
        VisionCoinWrapper(
            _NAME,
            _SYMBOL,
            _DECIMALS,
            native,
            accessControllerAddress
        )
    {}
}
