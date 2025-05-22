// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {VisionRBAC} from "./access/VisionRBAC.sol";
import {VisionRoles} from "./access/VisionRoles.sol";
import {AccessController} from "./access/AccessController.sol";
import {IBEP20} from "./interfaces/IBEP20.sol";
import {IVisionWrapper} from "./interfaces/IVisionWrapper.sol";
import {VisionBaseToken} from "./VisionBaseToken.sol";

/**
 * @title Base implementation for Vision-compatible token contracts that
 * wrap either a blockchain network's native coin or another token
 *
 * @dev This token contract properly supports wrapping and unwrapping of
 * coins on exactly one blockchain network.
 */
abstract contract VisionWrapper is
    ERC165,
    IVisionWrapper,
    VisionBaseToken,
    ERC20Pausable,
    VisionRBAC
{
    bool private immutable _native;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        bool native,
        address accessControllerAddress
    )
        VisionBaseToken(
            name_,
            symbol_,
            decimals_,
            AccessController(accessControllerAddress).superCriticalOps()
        )
        VisionRBAC(accessControllerAddress)
    {
        _native = native;
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @dev See {VisionBaseToken-onlyVisionForwarder}.
     */
    modifier onlyVisionForwarder() override {
        require(
            msg.sender == getVisionForwarder(),
            "VisionWrapper: caller is not the VisionForwarder"
        );
        _;
    }

    /**
     * @dev Makes sure that the function can only be called on the native
     * blockchain.
     */
    modifier onlyNative() {
        require(
            _native,
            "VisionWrapper: only possible on the native blockchain"
        );
        _;
    }

    /**
     * @dev See {Pausable-_pause).
     */
    function pause() external whenNotPaused onlyRole(VisionRoles.PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause).
     */
    function unpause()
        external
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        require(
            getVisionForwarder() != address(0),
            "VisionWrapper: VisionForwarder has not been set"
        );
        _unpause();
    }

    /**
     * @dev See {VisionBaseToken-_setVisionForwarder}.
     */
    function setVisionForwarder(
        address visionForwarder
    ) external whenPaused onlyOwner {
        _setVisionForwarder(visionForwarder);
    }

    /**
     * @dev See {IVisionWrapper-wrap}.
     */
    function wrap() public payable virtual override;

    /**
     * @dev See {IVisionWrapper-unwrap}.
     */
    function unwrap(uint256 amount) public virtual override;

    /**
     * @dev See {IVisionWrapper-isNative}.
     */
    function isNative() public view override returns (bool) {
        return _native;
    }

    /**
     * @dev See {VisionBaseToken-decimals} and {ERC20-decimals}.
     */
    function decimals()
        public
        view
        override(VisionBaseToken, IBEP20, ERC20)
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
        override(VisionBaseToken, IBEP20, ERC20)
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
        override(VisionBaseToken, IBEP20, ERC20)
        returns (string memory)
    {
        return VisionBaseToken.name();
    }

    /**
     * @dev Disable the transfer of ownership.
     */
    function transferOwnership(address) public view override onlyOwner {
        require(false, "VisionWrapper: ownership cannot be transferred");
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
        override(ERC165, IERC165, VisionBaseToken)
        returns (bool)
    {
        return
            interfaceId == type(IVisionWrapper).interfaceId ||
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
    ) internal override(ERC20, ERC20Pausable) {
        super._update(sender, recipient, amount);
    }
}
