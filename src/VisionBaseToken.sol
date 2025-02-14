// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
abstract contract VisionBaseToken is IVisionToken, ERC20, Ownable, ERC165 {
    uint8 private immutable _decimals;

    address private _visionForwarder;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        _decimals = decimals_;
    }

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
     * @dev See {IBEP20-decimals} and {ERC20-decimals}
     */
    function decimals()
        public
        view
        virtual
        override(IBEP20, ERC20)
        returns (uint8)
    {
        return _decimals;
    }

    /**
     * @dev See {IBEP20-symbol} and {ERC20-symbol}
     */
    function symbol()
        public
        view
        virtual
        override(IBEP20, ERC20)
        returns (string memory)
    {
        return ERC20.symbol();
    }

    /**
     * @dev See {IBEP20-name} and {ERC20-name}
     */
    function name()
        public
        view
        virtual
        override(IBEP20, ERC20)
        returns (string memory)
    {
        return ERC20.name();
    }

    /**
     * @dev See {IBEP20-getOwner} and {Ownable-owner}
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
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IVisionToken).interfaceId ||
            interfaceId == type(ERC20).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _setVisionForwarder(
        address visionForwarder
    ) internal virtual onlyOwner {
        require(
            visionForwarder != address(0),
            "VisionBaseToken: VisionForwarder must not be the zero account"
        );
        _visionForwarder = visionForwarder;
        emit VisionForwarderSet(visionForwarder);
    }

    // slither-disable-next-line dead-code
    function _unsetVisionForwarder() internal virtual onlyOwner {
        _visionForwarder = address(0);
        emit VisionForwarderUnset();
    }
}
