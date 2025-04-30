// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import {IBEP20} from "./interfaces/IBEP20.sol";
import {IVisionToken} from "./interfaces/IVisionToken.sol";
import {XERC20Upgradable} from "./XERC20Upgradable.sol";
/**
 * @title Vision base token
 *
 * @notice The VisionBaseToken contract is an abstract contract which implements
 * the IVisionToken interface. It is meant to be used as a base contract for
 * all Vision-compatible token contracts.
 */
abstract contract VisionBaseTokenUpgradeable is
    ERC165Upgradeable,
    XERC20Upgradable, // ERC20Upgradable
    IVisionToken
{
    function __VisionBaseToken_init(
        string memory _name,
        string memory _symbol,
        address _owner
    ) internal onlyInitializing {
        __ERC165_init();
        __XERC20_init(_name, _symbol, _owner);
    }

    function __VisionBaseToken_init_unchained() internal onlyInitializing {
    }

    function crosschainMint(
        address _to,
        uint256 _amount
    ) public virtual override {
        _mintWithCaller(msg.sender, _to, _amount);
        emit CrosschainMint(_to, _amount, msg.sender);
    }

    function crosschainBurn(address _from, uint256 _amount) external {
        if (msg.sender != _from) {
            _spendAllowance(_from, msg.sender, _amount);
        }

        _burnWithCaller(msg.sender, _from, _amount);
        emit CrosschainBurn(_from, _amount, msg.sender);
    }

    // function supportsInterface(
    //     bytes4 interfaceId
    // ) public view virtual override(ERC165Upgradeable) returns (bool) {
    //     return
    //         interfaceId == type(IVisionToken).interfaceId ||
    //         interfaceId == type(ERC20).interfaceId ||
    //         interfaceId == type(Ownable).interfaceId ||
    //         super.supportsInterface(interfaceId);
    // }

    /**
     * @dev See {IBEP20-decimals} and {ERC20-decimals}
     */
    function decimals()
        public
        view
        virtual
        override(IBEP20, ERC20Upgradeable)
        returns (uint8)
    {
        return ERC20Upgradeable.decimals();
    }

    /**
     * @dev See {IBEP20-symbol} and {ERC20-symbol}
     */
    function symbol()
        public
        view
        virtual
        override(IBEP20, ERC20Upgradeable)
        returns (string memory)
    {
        return ERC20Upgradeable.symbol();
    }

    /**
     * @dev See {IBEP20-name} and {ERC20-name}
     */
    function name()
        public
        view
        virtual
        override(IBEP20, ERC20Upgradeable)
        returns (string memory)
    {
        return ERC20Upgradeable.name();
    }

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
     * @dev See {IBEP20-getOwner} and {Ownable-owner}
     */
    function getOwner() public view virtual override returns (address) {
        return owner();
    }
}
