// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
// solhint-disable-next-line max-line-length

import {VisionToken} from "../../src/VisionToken.sol";

contract VisionTokenV2 is VisionToken {
    // keccak256(abi.encode(uint256(keccak256("vision-token-v2.contract.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant VISION_TOKEN_STORAGE_LOCATION_V2 =
        0x151e8425fe91f95d7f0d71695e37df648e575a2bb0a4e92293185ea91f428700;

    /// @notice Extra role for managing the new elements in V2.
    bytes32 public constant EXTRA_ROLE = keccak256("EXTRA_ROLE");

    struct VisionTokenV2Storage {
        string _extraStr;
        uint256 _extraUint;
        bool _extraBool;
        address _extraAddress;
        address[] _extraArray;
    }

    /**
     * @dev Returns a pointer to the PaymentTokenStorageV2 using inline assembly for optimized access.
     * This usage is safe and necessary for accessing namespaced storage in upgradeable contracts.
     */
    // slither-disable-next-line assembly
    function getVisionTokenV2Storage()
        private
        pure
        returns (VisionTokenV2Storage storage vts)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            vts.slot := VISION_TOKEN_STORAGE_LOCATION_V2
        }
    }

    /**
     * @dev Initializes the new storage fields in the upgrade.
     * Can only be called once for this version (reinitializer).
     */
    function initializeV2(
        string memory extraStr,
        uint256 extraUint,
        bool extraBool,
        address extraAddress,
        address[] calldata extraArray
    ) public reinitializer(2) {
        __VisionTokenV2_init_unchained(
            extraStr,
            extraUint,
            extraBool,
            extraAddress,
            extraArray
        );
    }

    function __VisionTokenV2_init_unchained(
        string memory extraStr,
        uint256 extraUint,
        bool extraBool,
        address extraAddress,
        address[] calldata extraArray
    ) internal onlyInitializing {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        vts._extraStr = extraStr;
        vts._extraUint = extraUint;
        vts._extraBool = extraBool;
        vts._extraAddress = extraAddress;

        // Initialize the array
        for (uint256 i = 0; i < extraArray.length; i++) {
            vts._extraArray.push(extraArray[i]);
        }
    }

    // --- Setters ---
    function setExtraStr(
        string memory newExtraStr
    ) external onlyRole(EXTRA_ROLE) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        vts._extraStr = newExtraStr;
    }

    function setExtraUint(uint256 newExtraUint) external onlyRole(EXTRA_ROLE) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        vts._extraUint = newExtraUint;
    }

    function setExtraBool(bool newExtraBool) external onlyRole(EXTRA_ROLE) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        vts._extraBool = newExtraBool;
    }

    function setExtraAddress(
        address newExtraAddress
    ) external onlyRole(EXTRA_ROLE) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        vts._extraAddress = newExtraAddress;
    }

    function setExtraArray(
        address[] calldata extraArray
    ) external onlyRole(EXTRA_ROLE) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        vts._extraArray = extraArray;
    }

    // --- Getters ---

    function getExtraStr() external view returns (string memory) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        return vts._extraStr;
    }

    function getExtraUint() external view returns (uint256) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        return vts._extraUint;
    }

    function getExtraBool() external view returns (bool) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        return vts._extraBool;
    }

    function getExtraAddress() external view returns (address) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        return vts._extraAddress;
    }

    function getExtraArray() external view returns (address[] memory) {
        VisionTokenV2Storage storage vts = getVisionTokenV2Storage();
        return vts._extraArray;
    }
}
