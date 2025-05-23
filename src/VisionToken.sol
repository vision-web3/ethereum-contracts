// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// solhint-disable-next-line max-line-length
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {VisionBaseTokenUpgradeable} from "./VisionBaseTokenUpgradeable.sol";

/**
 * @title VisionToken
 * @notice Upgradeable ERC20 token with role-based access control, pausing, and permit support.
 * @dev
 * - Inherits core upgradable variant of ERC20 logic and `Ownable` from VisionBaseTokenUpgradeable.
 * - Uses AccessControlUpgradeable for role-based permissions (e.g., pausing, upgrading, minting).
 * - The `CRITICAL_OPS_ROLE` role is managed using AccessControl, which allows multiple accounts to hold this role.
 * - However, the implementation assumes only one account will hold the `CRITICAL_OPS_ROLE` role at a time,
 *   in alignment with the `Ownable` nature of the base contract.
 * - The account with the `CRITICAL_OPS_ROLE` role must also be the contract owner, as enforced by the `Ownable`
 *   contract.
 * - Changing the `CRITICAL_OPS_ROLE` address requires both `grantRole`/`revokeRole` and `transferOwnership`.
 */
contract VisionToken is
    VisionBaseTokenUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
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
    /// @notice Role for upgrading the contract.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     * @dev Emitted when `amount` tokens are minted by `MINTER_ROLE` and assigned to `to`.
     */
    event Mint(address indexed minter, address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev criticalOps receives all existing tokens and is the owner of underlying VisionBaseTokenUpgradeable
     */
    function initialize(
        uint256 initialSupply,
        address defaultAdmin,
        address criticalOps,
        address minter,
        address pauser,
        address upgrader
    ) public initializer {
        // initializeVisionBaseToken() also initializes Upgradeable variants of ERC165, Ownable, ERC20, ERC20Permit
        __VisionBaseToken_init(_NAME, _SYMBOL, _DECIMALS, criticalOps);
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(CRITICAL_OPS_ROLE, criticalOps);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UPGRADER_ROLE, upgrader);

        ERC20Upgradeable._mint(super.getOwner(), initialSupply);
    }

    /**
     * @notice Mints tokens to a specified address.
     * @dev Only callable by accounts with the `MINTER_ROLE`.
     * Emits a {Mint} event with `minter` set to the address that initiated the minting,
     * `to` set to the recipient's address, and `amount` set to the amount of tokens minted.
     * Reverts if `amount` is zero.
     * Requirement: the contract must not be paused. {ERC20PausableUpgradeable-_update} enforces it.
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
     *  @dev See {VisionBaseTokenUpgradeable-_setVisionForwarder}
     */
    function setVisionForwarder(
        address visionForwarder
    ) external whenPaused onlyRole(CRITICAL_OPS_ROLE) {
        _setVisionForwarder(visionForwarder);
    }

    /**
     * @dev See {VisionBaseTokenUpgradeable-decimals}.
     */
    function decimals()
        public
        view
        override(VisionBaseTokenUpgradeable, ERC20Upgradeable)
        returns (uint8)
    {
        return VisionBaseTokenUpgradeable.decimals();
    }

    /**
     * @dev See {VisionBaseTokenUpgradeable-symbol} and {ERC20-symbol}.
     */
    function symbol()
        public
        view
        override(VisionBaseTokenUpgradeable, ERC20Upgradeable)
        returns (string memory)
    {
        return VisionBaseTokenUpgradeable.symbol();
    }

    /**
     * @dev See {VisionBaseTokenUpgradeable-name} and {ERC20-name}.
     */
    function name()
        public
        view
        override(VisionBaseTokenUpgradeable, ERC20Upgradeable)
        returns (string memory)
    {
        return VisionBaseTokenUpgradeable.name();
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
        override(VisionBaseTokenUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            VisionBaseTokenUpgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC20Upgradeable-_update}.
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(sender, recipient, amount);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
