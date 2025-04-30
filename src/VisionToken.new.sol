// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20CappedUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import {VisionRBACUpgradeable} from "./access/VisionRBACUpgradeable.sol";
import {VisionRoles} from "./access/VisionRoles.sol";
import {AccessController} from "./access/AccessController.sol";
import {VisionBaseTokenUpgradeable} from "./VisionBaseTokenUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Vision token
 */
contract VisionToken is
    VisionBaseTokenUpgradeable,
    ERC20CappedUpgradeable,
    ERC20PausableUpgradeable,
    VisionRBACUpgradeable,
    UUPSUpgradeable
{
    string private constant _NAME = "Vision";

    string private constant _SYMBOL = "VSN";

    uint8 private constant _DECIMALS = 8;

    uint256 private constant _MAX_SUPPLY =
        (10 ** 9) * (10 ** uint256(_DECIMALS));

    // /**
    //  * @dev superCriticalOps receives all existing tokens
    //  */
    // constructor(
    //     uint256 initialSupply,
    //     address accessControllerAddress
    // )
    //     VisionBaseTokenUpgradeable(
    //         _NAME,
    //         _SYMBOL,
    //         AccessController(accessControllerAddress).superCriticalOps()
    //     )
    //     ERC20CappedUpgradeable(_MAX_SUPPLY)
    //     VisionRBAC(accessControllerAddress)
    // {
    //     require(
    //         initialSupply <= _MAX_SUPPLY,
    //         "VisionToken: maximum supply exceeded"
    //     );
    //     ERC20Upgradeable._mint(super.getOwner(), initialSupply);
    //     // Contract is paused until it is fully initialized
    //     _pause();
    // }

    // /**
    //  * @dev See {VisionBaseToken-onlyVisionForwarder}
    //  */
    // modifier onlyVisionForwarder() override {
    //     require(
    //         msg.sender == getVisionForwarder(),
    //         "VisionToken: caller is not the VisionForwarder"
    //     );
    //     _;
    // }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 initialSupply,
        address accessControllerAddress
    ) public initializer {
        require(
            initialSupply <= _MAX_SUPPLY,
            "VisionToken: maximum supply exceeded"
        );
        __ERC20_init(_NAME, _SYMBOL);
        __ERC20Pausable_init();
        __ERC20Permit_init(_NAME);
        __ERC20Capped_init(_MAX_SUPPLY);
        __VisionBaseToken_init(
            _NAME,
            _SYMBOL,
            AccessController(accessControllerAddress).superCriticalOps()
        );
        __VisionRBAC_init(accessControllerAddress);
        // Contract is paused until it is fully initialized
        _pause();
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
        // require(
        //     getVisionForwarder() != address(0),
        //     "VisionToken: VisionForwarder has not been set"
        // );
        _unpause();
    }

    /**
     * @dev See {VisionBaseToken-decimals} and {ERC20-decimals}.
     */
    function decimals()
        public
        pure
        override(ERC20Upgradeable, VisionBaseTokenUpgradeable)
        returns (uint8)
    {
        return _DECIMALS;
    }

    /**
     * @dev See {VisionBaseToken-symbol} and {ERC20-symbol}.
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
     * @dev See {VisionBaseToken-name} and {ERC20-name}.
     */
    function name()
        public
        view
        override(VisionBaseTokenUpgradeable, ERC20Upgradeable)
        returns (string memory)
    {
        return super.name();
    }

    /**
     * @dev Disable the transfer of ownership.
     */
    function transferOwnership(address) public view override onlyOwner {
        require(false, "VisionToken: ownership cannot be transferred");
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // FIXME
    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC165Upgradeable) returns (bool) {
        return
            // interfaceId == type(IERC20Capped).interfaceId ||
            // interfaceId == type(IERC20Pausable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC20-_update}.
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    )
        internal
        override(
            ERC20Upgradeable,
            ERC20CappedUpgradeable,
            ERC20PausableUpgradeable
        )
    {
        super._update(sender, recipient, amount);
    }
}
