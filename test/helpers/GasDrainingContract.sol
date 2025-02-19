// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {VisionRBAC} from "../../src/access/VisionRBAC.sol";
import {VisionRoles} from "../../src/access/VisionRoles.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {VisionBaseToken} from "../../src/VisionBaseToken.sol";

/**
 * @title Vision token where the transfer function call the assembly invalid
 * opcode causing it to drain all the gas.
 */
contract GasDrainingContract is
    VisionBaseToken,
    ERC20Capped,
    ERC20Pausable,
    VisionRBAC
{
    string private constant _NAME = "Vision";

    string private constant _SYMBOL = "VSN";

    uint8 private constant _DECIMALS = 8;

    uint256 private constant _MAX_SUPPLY =
        (10 ** 9) * (10 ** uint256(_DECIMALS));

    /**
     * @dev superCriticalOps receives all existing tokens
     */
    constructor(
        uint256 initialSupply,
        address accessControllerAddress
    )
        VisionBaseToken(
            _NAME,
            _SYMBOL,
            _DECIMALS,
            AccessController(accessControllerAddress).superCriticalOps()
        )
        ERC20Capped(_MAX_SUPPLY)
        VisionRBAC(accessControllerAddress)
    {
        require(
            initialSupply <= _MAX_SUPPLY,
            "VisionToken: maximum supply exceeded"
        );
        ERC20._mint(super.getOwner(), initialSupply);
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @dev See {VisionBaseToken-onlyVisionForwarder}
     */
    modifier onlyVisionForwarder() override {
        require(
            msg.sender == getVisionForwarder(),
            "VisionToken: caller is not the VisionForwarder"
        );
        _;
    }

    /**
     * @dev See {Pausable-_pause)
     */
    function pause() external whenNotPaused onlyRole(VisionRoles.PAUSER) {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause)
     */
    function unpause()
        external
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS)
    {
        require(
            getVisionForwarder() != address(0),
            "VisionToken: VisionForwarder has not been set"
        );
        _unpause();
    }

    /**
     *  @dev See {VisionBaseToken-_setVisionForwarder}
     */
    function setVisionForwarder(
        address VisionForwarder
    ) external whenPaused onlyOwner {
        _setVisionForwarder(VisionForwarder);
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
     * @dev Disable the transfer of ownership.
     */
    function transferOwnership(address) public view override onlyOwner {
        require(false, "VisionToken: ownership cannot be transferred");
    }

    function visionTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override onlyVisionForwarder {
        assembly {
            invalid()
        }
    }

    function visionTransferFrom(
        address sender,
        uint256 amount
    ) public override onlyVisionForwarder {
        assembly {
            invalid()
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(VisionBaseToken) returns (bool) {
        return
            interfaceId == type(ERC20Capped).interfaceId ||
            interfaceId == type(ERC20Pausable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC20-_update}.
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20, ERC20Capped, ERC20Pausable) {
        super._update(sender, recipient, amount);
    }
}
