// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
// solhint-disable-next-line max-line-length
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IVisionToken} from "./interfaces/IVisionToken.sol";

/**
 * @title Vision base token
 *
 * @notice The VisionBaseToken contract is an abstract contract which implements
 * the IVisionToken interface. It is meant to be used as a base contract for
 * all Vision-compatible upgradeable token contracts.
 */
abstract contract VisionBaseTokenUpgradeable is
    ERC165Upgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    IVisionToken
{
    /**
     * @custom:storage-location erc7201:vision-base-token.contract.storage
     * @dev Defines the storage layout for the VisionBaseToken contract.
     *
     * Variables:
     *  `_decimals`: Address ....
     *  `_visionForwarder`: Address ....
     */
    struct VisionBaseTokenStorage {
        uint8 _decimals;
        address _visionForwarder;
    }

    // keccak256(abi.encode(uint256(keccak256("vision-base-token.contract.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant VISION_BASE_TOKEN_STORAGE_LOCATION =
        0x8a83655261740f09e968720dd5982e8d17ec12a50d4d2f5e59ec427b5095b700;

    /**
     * @notice Modifier to make a function callable only by the Vision Forwarder
     */
    modifier onlyVisionForwarder() virtual {
        VisionBaseTokenStorage storage vs = _getVisionBaseTokenStorage();
        require(
            vs._visionForwarder != address(0),
            "VisionBaseToken: VisionForwarder has not been set"
        );
        require(
            msg.sender == vs._visionForwarder,
            "VisionBaseToken: caller is not the VisionForwarder"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    // slither-disable-next-line naming-convention
    function __VisionBaseToken_init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_
    ) internal onlyInitializing {
        __ERC165_init();
        __Ownable_init(owner_);
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __VisionBaseToken_init_unchained(decimals_);
    }

    // slither-disable-next-line naming-convention
    function __VisionBaseToken_init_unchained(
        uint8 decimals_
    ) internal onlyInitializing {
        VisionBaseTokenStorage storage vs = _getVisionBaseTokenStorage();
        vs._decimals = decimals_;
    }

    /**
     * @dev Returns a pointer to the VisionBaseTokenStorage using inline assembly for optimized access.
     * This usage is safe and necessary for accessing namespaced storage in upgradeable contracts.
     */
    // slither-disable-next-line assembly
    function _getVisionBaseTokenStorage()
        private
        pure
        returns (VisionBaseTokenStorage storage vs)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            vs.slot := VISION_BASE_TOKEN_STORAGE_LOCATION
        }
    }

    /**
     * @dev See {IVisionToken-visionTransfer}
     */
    function visionTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override onlyVisionForwarder {
        _transfer(sender, recipient, amount);
    }

    /**
     * @dev See {IVisionToken-visionTransferFrom}
     */
    function visionTransferFrom(
        address sender,
        uint256 amount
    ) public virtual override onlyVisionForwarder {
        _burn(sender, amount);
    }

    /**
     * @dev See {IVisionToken-visionTransferTo}
     */
    function visionTransferTo(
        address recipient,
        uint256 amount
    ) public virtual override onlyVisionForwarder {
        _mint(recipient, amount);
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals()
        public
        view
        virtual
        override(IERC20Metadata, ERC20Upgradeable)
        returns (uint8)
    {
        VisionBaseTokenStorage storage vs = _getVisionBaseTokenStorage();
        return vs._decimals;
    }

    /**
     * @dev See {ERC20Upgradeable-symbol}
     */
    function symbol()
        public
        view
        virtual
        override(IERC20Metadata, ERC20Upgradeable)
        returns (string memory)
    {
        return ERC20Upgradeable.symbol();
    }

    /**
     * @dev See {ERC20Upgradeable-name}
     */
    function name()
        public
        view
        virtual
        override(IERC20Metadata, ERC20Upgradeable)
        returns (string memory)
    {
        return ERC20Upgradeable.name();
    }

    /**
     * See {IERC20Permit-nonces}
     */
    function nonces(
        address owner
    )
        public
        view
        virtual
        override(IERC20Permit, ERC20PermitUpgradeable)
        returns (uint256)
    {
        return ERC20PermitUpgradeable.nonces(owner);
    }

    /**
     * @dev See {IVisionToken-getOwner}
     */
    function getOwner() public view virtual override returns (address) {
        return owner();
    }

    /**
     * @dev See {IVisionToken-getVisionForwarder}
     */
    function getVisionForwarder()
        public
        view
        virtual
        override
        returns (address)
    {
        VisionBaseTokenStorage storage vs = _getVisionBaseTokenStorage();
        return vs._visionForwarder;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IVisionToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _setVisionForwarder(address visionForwarder) internal virtual {
        VisionBaseTokenStorage storage vs = _getVisionBaseTokenStorage();
        require(
            visionForwarder != address(0),
            "VisionBaseToken: VisionForwarder must not be the zero account"
        );
        vs._visionForwarder = visionForwarder;
        emit VisionForwarderSet(visionForwarder);
    }

    // slither-disable-next-line dead-code
    function _unsetVisionForwarder() internal virtual {
        VisionBaseTokenStorage storage vs = _getVisionBaseTokenStorage();
        vs._visionForwarder = address(0);
        emit VisionForwarderUnset();
    }
}
