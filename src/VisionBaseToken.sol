// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {IBEP20} from "./interfaces/IBEP20.sol";
import {IVisionToken} from "./interfaces/IVisionToken.sol";

/**
 * @title Vision base token
 *
 * @notice The VisionBaseToken contract is an abstract contract which implements
 * the IVisionToken interface. It is meant to be used as a base contract for
 * all Vision-compatible token contracts.
 */
abstract contract VisionBaseToken is
    IVisionToken,
    ERC20Permit,
    Ownable,
    ERC165
{
    uint8 private immutable _decimals;

    address private _visionForwarder;

    /**
     * @notice Modifier to make a function callable only by the Vision Forwarder
     */
    modifier onlyVisionForwarder() virtual {
        require(
            _visionForwarder != address(0),
            "VisionBaseToken: VisionForwarder has not been set"
        );
        require(
            msg.sender == _visionForwarder,
            "VisionBaseToken: caller is not the VisionForwarder"
        );
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(owner_) {
        _decimals = decimals_;
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
        override(IERC20Metadata, ERC20)
        returns (uint8)
    {
        return _decimals;
    }

    /**
     * @dev See {ERC20-symbol}
     */
    function symbol()
        public
        view
        virtual
        override(IERC20Metadata, ERC20)
        returns (string memory)
    {
        return ERC20.symbol();
    }

    /**
     * @dev See {ERC20-name}
     */
    function name()
        public
        view
        virtual
        override(IERC20Metadata, ERC20)
        returns (string memory)
    {
        return ERC20.name();
    }

    /**
     * See {IERC20Permit}
     */
    function nonces(
        address owner
    )
        public
        view
        virtual
        override(IERC20Permit, ERC20Permit)
        returns (uint256)
    {
        return ERC20Permit.nonces(owner);
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
        return _visionForwarder;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IVisionToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _setVisionForwarder(address visionForwarder) internal virtual {
        require(
            visionForwarder != address(0),
            "VisionBaseToken: VisionForwarder must not be the zero account"
        );
        _visionForwarder = visionForwarder;
        emit VisionForwarderSet(visionForwarder);
    }

    // slither-disable-next-line dead-code
    function _unsetVisionForwarder() internal virtual {
        _visionForwarder = address(0);
        emit VisionForwarderUnset();
    }
}
