// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {VisionBaseToken} from "../VisionBaseToken.sol";

contract MigrationTokenBurnablePausable is
    VisionBaseToken,
    ERC20Burnable,
    ERC20Pausable
{
    /**
     * @dev msg.sender receives all existing tokens.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 supply_
    ) VisionBaseToken(name_, symbol_, decimals_, msg.sender) {
        ERC20._mint(msg.sender, supply_);
        _pause();
    }

    function setVisionForwarder(address visionForwarder) external onlyOwner {
        _setVisionForwarder(visionForwarder);
    }

    /**
     * @dev See {VisionBaseToken-decimals} and {ERC20-decimals}.
     */
    function decimals()
        public
        view
        override(VisionBaseToken, ERC20)
        returns (uint8)
    {
        return VisionBaseToken.decimals();
    }

    /**
     * @dev See {VisionBaseToken-symbol} and {ERC20-symbol}.
     */
    function symbol()
        public
        view
        override(VisionBaseToken, ERC20)
        returns (string memory)
    {
        return VisionBaseToken.symbol();
    }

    /**
     * @dev See {VisionBaseToken-name} and {ERC20-name}.
     */
    function name()
        public
        view
        override(VisionBaseToken, ERC20)
        returns (string memory)
    {
        return VisionBaseToken.name();
    }

    /**
     * @dev See {ERC20-_update}.
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._update(sender, recipient, amount);
    }

    /**
     * @dev See {Pausable-_pause)
     */
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause)
     */
    function unpause() external whenPaused onlyOwner {
        require(
            getVisionForwarder() != address(0),
            "VisionToken: VisionForwarder has not been set"
        );
        _unpause();
    }
}
