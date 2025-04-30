// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title Vision RBAC
 */
abstract contract VisionRBACUpgradeable is Initializable {
    // IAccessControl private immutable _accessController;
    /// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
    struct VisionRBACStorage {
        IAccessControl accessController;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VisionRBACStorageLocation =
        0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800; //fixme

    function _getVisionRBACStorage()
        private
        pure
        returns (VisionRBACStorage storage $)
    {
        assembly {
            $.slot := VisionRBACStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    // /**
    //  * @notice Initialize Vision RBAC with roles.
    //  *
    //  * @param accessControllerAddress Address of the access controller.
    //  */
    // constructor(address accessControllerAddress) {
    //     _accessController = IAccessControl(accessControllerAddress);
    // }

    function __VisionRBAC_init(
        address accessControllerAddress
    ) internal onlyInitializing {
        VisionRBACStorage storage $ = _getVisionRBACStorage();
        $.accessController = IAccessControl(accessControllerAddress);
    }

    /**
     * @notice Modifier making sure that the function can only be called by the
     * authorized role.
     */
    modifier onlyRole(bytes32 _role) {
        VisionRBACStorage storage $ = _getVisionRBACStorage();
        require(
            $.accessController.hasRole(_role, msg.sender),
            "VisionRBAC: caller doesn't have role"
        );
        _;
    }
}
