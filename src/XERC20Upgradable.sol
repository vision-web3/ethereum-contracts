// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IXERC20} from "./interfaces/IXERC20.sol";

contract XERC20Upgradable is
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    IXERC20
{
    /**
     * @notice The duration it takes for the limits to fully replenish
     */
    uint256 private constant _DURATION = 1 days; // FIXME

    /**
     * @custom:storage-location erc7201:xerc20.contract.storage
     * @dev Defines the storage layout for the XERC20Upgradable contract.
     *
     * Variables:
     *  `lockbox`: Address ....
     *  `bridges`: A mapping ...
     */
    struct XERC20Storage {
        address lockbox;
        mapping(address => Bridge) bridges;
    }

    // keccak256(abi.encode(uint256(keccak256("xerc20.contract.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant XERC20_STORAGE_LOCATION =
        0x1ddf1b777dd3ac246383a253e57fb514e8e41e0e1523eb0079abe371d331ff00; // FIXME calc actual val

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes config of the XERC20
     *
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param owner The owner/factory which deployed this contract
     */
    function __XERC20_init(
        string memory name,
        string memory symbol,
        address owner
    ) internal onlyInitializing {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init(owner);
    }

    /**
     * @dev Returns a pointer to the XERC20Storage using inline assembly for optimized access.
     * This usage is safe and necessary for accessing namespaced storage in upgradeable contracts.
     */
    // slither-disable-next-line assembly
    function _getXERC20Storage()
        private
        pure
        returns (XERC20Storage storage xs)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            xs.slot := XERC20_STORAGE_LOCATION
        }
    }

    /**
     * @notice Mints tokens for a user
     * @dev Can only be called by a bridge
     * @param _user The address of the user who needs tokens minted
     * @param _amount The amount of tokens being minted
     */
    function mint(address _user, uint256 _amount) public {
        _mintWithCaller(msg.sender, _user, _amount);
    }

    /**
     * @notice Burns tokens for a user
     * @dev Can only be called by a bridge
     * @param _user The address of the user who needs tokens burned
     * @param _amount The amount of tokens being burned
     */
    function burn(address _user, uint256 _amount) public {
        if (msg.sender != _user) {
            _spendAllowance(_user, msg.sender, _amount);
        }

        _burnWithCaller(msg.sender, _user, _amount);
    }

    /**
     * @notice Sets the lockbox address
     *
     * @param lockbox The address of the lockbox
     */
    // FIXME need to decide how to handle this, as we don't want factory logic tied to the standard impl
    function setLockbox(address lockbox) public {
        if (msg.sender != owner()) revert IXERC20_NotFactory();
        XERC20Storage storage xs = _getXERC20Storage();
        xs.lockbox = lockbox;

        emit LockboxSet(lockbox);
    }

    /**
     * @notice Updates the limits of any bridge
     * @dev Can only be called by the owner
     * @param mintingLimit The updated minting limit we are setting to the bridge
     * @param burningLimit The updated burning limit we are setting to the bridge
     * @param bridge The address of the bridge we are setting the limits too
     */
    function setLimits(
        // FIXME new version is using type(uint256).max as limit
        address bridge,
        uint256 mintingLimit,
        uint256 burningLimit
    ) external onlyOwner {
        if (
            mintingLimit > (type(uint256).max / 2) ||
            burningLimit > (type(uint256).max / 2)
        ) {
            revert IXERC20_LimitsTooHigh();
        }

        _changeMinterLimit(bridge, mintingLimit);
        _changeBurnerLimit(bridge, burningLimit);
        emit BridgeLimitsSet(mintingLimit, burningLimit, bridge);
    }

    /**
     * @notice Returns the max limit of a bridge
     *
     * @param bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function mintingMaxLimitOf(
        address bridge
    ) public view returns (uint256 limit) {
        XERC20Storage storage xs = _getXERC20Storage();
        limit = xs.bridges[bridge].minterParams.maxLimit;
    }

    /**
     * @notice Returns the max limit of a bridge
     *
     * @param bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function burningMaxLimitOf(
        address bridge
    ) public view returns (uint256 limit) {
        XERC20Storage storage xs = _getXERC20Storage();
        limit = xs.bridges[bridge].burnerParams.maxLimit;
    }

    /**
     * @notice Returns the current limit of a bridge
     *
     * @param _bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function mintingCurrentLimitOf(
        address _bridge
    ) public view returns (uint256 limit) {
        XERC20Storage storage xs = _getXERC20Storage();
        limit = _getCurrentLimit(
            xs.bridges[_bridge].minterParams.currentLimit,
            xs.bridges[_bridge].minterParams.maxLimit,
            xs.bridges[_bridge].minterParams.timestamp,
            xs.bridges[_bridge].minterParams.ratePerSecond
        );
    }

    /**
     * @notice Returns the current limit of a bridge
     *
     * @param _bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function burningCurrentLimitOf(
        address _bridge
    ) public view returns (uint256 limit) {
        XERC20Storage storage xs = _getXERC20Storage();
        limit = _getCurrentLimit(
            xs.bridges[_bridge].burnerParams.currentLimit,
            xs.bridges[_bridge].burnerParams.maxLimit,
            xs.bridges[_bridge].burnerParams.timestamp,
            xs.bridges[_bridge].burnerParams.ratePerSecond
        );
    }

    /**
     * @notice Uses the limit of any bridge
     * @param bridge The address of the bridge who is being changed
     * @param change The change in the limit
     */
    function _useMinterLimits(address bridge, uint256 change) internal {
        uint256 _currentLimit = mintingCurrentLimitOf(bridge);
        XERC20Storage storage xs = _getXERC20Storage();
        xs.bridges[bridge].minterParams.timestamp = block.timestamp;
        xs.bridges[bridge].minterParams.currentLimit = _currentLimit - change;
    }

    /**
     * @notice Uses the limit of any bridge
     * @param bridge The address of the bridge who is being changed
     * @param change The change in the limit
     */
    function _useBurnerLimits(address bridge, uint256 change) internal {
        uint256 _currentLimit = burningCurrentLimitOf(bridge);
        XERC20Storage storage xs = _getXERC20Storage();
        xs.bridges[bridge].burnerParams.timestamp = block.timestamp;
        xs.bridges[bridge].burnerParams.currentLimit = _currentLimit - change;
    }

    /**
     * @notice Updates the limit of any bridge
     * @dev Can only be called by the owner
     * @param bridge The address of the bridge we are setting the limit too
     * @param limit The updated limit we are setting to the bridge
     */
    function _changeMinterLimit(address bridge, uint256 limit) internal {
        XERC20Storage storage xs = _getXERC20Storage();
        uint256 oldLimit = xs.bridges[bridge].minterParams.maxLimit;
        uint256 currentLimit = mintingCurrentLimitOf(bridge);
        xs.bridges[bridge].minterParams.maxLimit = limit;

        xs
            .bridges[bridge]
            .minterParams
            .currentLimit = _calculateNewCurrentLimit(
            limit,
            oldLimit,
            currentLimit
        );

        xs.bridges[bridge].minterParams.ratePerSecond = limit / _DURATION;
        xs.bridges[bridge].minterParams.timestamp = block.timestamp;
    }

    /**
     * @notice Updates the limit of any bridge
     * @dev Can only be called by the owner
     * @param _bridge The address of the bridge we are setting the limit too
     * @param limit The updated limit we are setting to the bridge
     */
    function _changeBurnerLimit(address _bridge, uint256 limit) internal {
        XERC20Storage storage xs = _getXERC20Storage();
        uint256 _oldLimit = xs.bridges[_bridge].burnerParams.maxLimit;
        uint256 _currentLimit = burningCurrentLimitOf(_bridge);
        xs.bridges[_bridge].burnerParams.maxLimit = limit;

        xs
            .bridges[_bridge]
            .burnerParams
            .currentLimit = _calculateNewCurrentLimit(
            limit,
            _oldLimit,
            _currentLimit
        );

        xs.bridges[_bridge].burnerParams.ratePerSecond = limit / _DURATION;
        xs.bridges[_bridge].burnerParams.timestamp = block.timestamp;
    }

    /**
     * @notice Updates the current limit
     *
     * @param limit The new limit
     * @param _oldLimit The old limit
     * @param _currentLimit The current limit
     * @return _newCurrentLimit The new current limit
     */
    function _calculateNewCurrentLimit(
        uint256 limit,
        uint256 _oldLimit,
        uint256 _currentLimit
    ) internal pure returns (uint256 _newCurrentLimit) {
        uint256 _difference;

        if (_oldLimit > limit) {
            _difference = _oldLimit - limit;
            _newCurrentLimit = _currentLimit > _difference
                ? _currentLimit - _difference
                : 0;
        } else {
            _difference = limit - _oldLimit;
            _newCurrentLimit = _currentLimit + _difference;
        }
    }

    /**
     * @notice Gets the current limit
     *
     * @param _currentLimit The current limit
     * @param _maxLimit The max limit
     * @param _timestamp The timestamp of the last update
     * @param _ratePerSecond The rate per second
     * @return limit The current limit
     */
    function _getCurrentLimit(
        uint256 _currentLimit,
        uint256 _maxLimit,
        uint256 _timestamp,
        uint256 _ratePerSecond
    ) internal view returns (uint256 limit) {
        limit = _currentLimit;
        if (limit == _maxLimit) {
            return limit;
        } else if (_timestamp + _DURATION <= block.timestamp) {
            limit = _maxLimit;
        } else if (_timestamp + _DURATION > block.timestamp) {
            uint256 _timePassed = block.timestamp - _timestamp;
            uint256 _calculatedLimit = limit + (_timePassed * _ratePerSecond);
            limit = _calculatedLimit > _maxLimit
                ? _maxLimit
                : _calculatedLimit;
        }
    }

    /**
     * @notice Internal function for burning tokens
     *
     * @param _caller The caller address
     * @param _user The user address
     * @param _amount The amount to burn
     */
    function _burnWithCaller(
        address _caller,
        address _user,
        uint256 _amount
    ) internal {
        XERC20Storage storage xs = _getXERC20Storage();
        if (_caller != xs.lockbox) {
            uint256 _currentLimit = burningCurrentLimitOf(_caller);
            if (_currentLimit < _amount) revert IXERC20_NotHighEnoughLimits();
            _useBurnerLimits(_caller, _amount);
        }
        _burn(_user, _amount);
    }

    /**
     * @notice Internal function for minting tokens
     *
     * @param _caller The caller address
     * @param _user The user address
     * @param _amount The amount to mint
     */
    function _mintWithCaller(
        address _caller,
        address _user,
        uint256 _amount
    ) internal {
        XERC20Storage storage xs = _getXERC20Storage();
        if (_caller != xs.lockbox) {
            uint256 _currentLimit = mintingCurrentLimitOf(_caller);
            if (_currentLimit < _amount) revert IXERC20_NotHighEnoughLimits();
            _useMinterLimits(_caller, _amount);
        }
        _mint(_user, _amount);
    }

    // /**
    //  * @dev See {ERC20-_update}.
    //  */
    // function _update(
    //     address sender,
    //     address recipient,
    //     uint256 amount
    // ) internal virtual override(ERC20Upgradeable) {
    //     super._update(sender, recipient, amount);
    // }
}
