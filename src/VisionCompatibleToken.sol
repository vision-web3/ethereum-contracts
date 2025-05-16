// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {VisionBaseToken} from "./VisionBaseToken.sol";

/**
 * @title VisionCompatibleToken
 * @notice ERC20 token with role-based access control, pausing, and permit support.
 * @dev
 * - Inherits core ERC20 logic and `Ownable` from VisionBaseToken.
 * - Uses AccessControl for role-based permissions (e.g., pausing, upgrading, minting).
 * - The `CRITICAL_OPS_ROLE` role is managed using AccessControl, which allows multiple accounts to hold this role.
 * - However, the implementation assumes only one account will hold the `CRITICAL_OPS_ROLE` role at a time,
 *   in alignment with the `Ownable` nature of the base contract.
 * - The account with the `CRITICAL_OPS_ROLE` role must also be the contract owner, as enforced by the `Ownable`
 *   contract.
 * - Changing the `CRITICAL_OPS_ROLE` address requires both `grantRole`/`revokeRole` and `transferOwnership`.
 */
contract VisionCompatibleToken is
    VisionBaseToken,
    ERC20Pausable,
    AccessControl
{
    string private constant _NAME = "Vision";
    string private constant _SYMBOL = "VSN";
    uint8 private constant _DECIMALS = 18;

    /// @notice Role for critical ops on contract.
    bytes32 public constant CRITICAL_OPS_ROLE = keccak256("CRITICAL_OPS_ROLE");
    /// @notice Role for minting tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Role for pausing the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev Emitted when `amount` tokens are minted by `MINTER_ROLE` and assigned to `to`.
     */
    event Mint(address indexed minter, address indexed to, uint256 amount);

    /**
     * @dev criticalOps receives all existing tokens and is the owner of underlying VisionBaseToken
     */
    constructor(
        uint256 initialSupply,
        address defaultAdmin,
        address criticalOps,
        address minter,
        address pauser
    ) VisionBaseToken(_NAME, _SYMBOL, _DECIMALS, criticalOps) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(CRITICAL_OPS_ROLE, criticalOps);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, pauser);
        ERC20._mint(super.getOwner(), initialSupply);
    }

    /**
     * @notice Mints tokens to a specified address.
     * @dev Only callable by accounts with the `MINTER_ROLE`.
     * Emits a {Mint} event with `minter` set to the address that initiated the minting,
     * `to` set to the recipient's address, and `amount` set to the amount of tokens minted.
     * Reverts with "VisionToken: Mint amount is zero" if `amount` is zero.
     * Requirement: the contract must not be paused. {ERC20Pausable-_update} enforces it.
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(amount != 0, "VisionToken: Mint amount is zero");
        _mint(to, amount);
        emit Mint(msg.sender, to, amount);
    }

    /**
     * @notice Pauses the Token contract.
     * @dev Only callable by accounts with the `PAUSER_ROLE`
     * Requirements: the contract must not be paused.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the Token contract.
     * @dev Only callable by accounts with the `CRITICAL_OPS_ROLE`
     * Requirement: the contract must be paused.
     */
    function unpause() external onlyRole(CRITICAL_OPS_ROLE) {
        _unpause();
    }

    /**
     *  @dev See {VisionBaseToken-_setVisionForwarder}
     */
    function setVisionForwarder(
        address visionForwarder
    ) external whenPaused onlyRole(CRITICAL_OPS_ROLE) {
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
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(VisionBaseToken, AccessControl)
        returns (bool)
    {
        return
            VisionBaseToken.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
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
}
