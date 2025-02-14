// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {VisionBaseToken} from "../VisionBaseToken.sol";

/**
 * @title Vision token
 */
contract MigrationToken is VisionBaseToken {
    /**
     * @dev msg.sender receives all existing tokens
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 supply
    ) VisionBaseToken(name, symbol, decimals, msg.sender) {
        ERC20._mint(msg.sender, supply);
    }

    function setVisionForwarder(address visionForwarder) external onlyOwner {
        _setVisionForwarder(visionForwarder);
    }
}
